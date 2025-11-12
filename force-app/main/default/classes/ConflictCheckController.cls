/**
 * @description Apex controller for the conflictCheck Lightning Web Component.
 * This class provides methods to search for potential conflicts
 * across Lead, Contact, and Account objects.
 */
public with sharing class ConflictCheckController {

    /**
     * @description Searches for records that match the given name, email, phone, or business name.
     * Includes deep content search across Time Entries, Notes, and Matter descriptions.
     * Returns results with risk scoring.
     * @param name The name to search for.
     * @param email The email to search for.
     * @param phone The phone number to search for.
     * @param businessName The business/company name to search for.
     * @return A list of ConflictMatch records with risk scores.
     */
    @AuraEnabled
    public static List<ConflictRiskScoringService.ConflictMatch> findConflicts(String name, String email, String phone, String businessName) {
        try {
            // First try with user permissions
            if (Schema.sObjectType.Lead.isAccessible() && 
                Schema.sObjectType.Contact.isAccessible() &&
                Schema.sObjectType.Account.isAccessible()) {
                
                // Initialize lists and maps for processing
                List<ConflictRiskScoringService.ConflictMatch> conflictMatches = new List<ConflictRiskScoringService.ConflictMatch>();
                List<SObject> searchResults = new List<SObject>();
                List<String> searchTerms = new List<String>();
                Map<String, String> matchReasons = new Map<String, String>();

                // Ensure at least one search parameter is provided to avoid an empty search.
                if (String.isBlank(name) && String.isBlank(email) && String.isBlank(phone) && String.isBlank(businessName)) {
                    return conflictMatches;
                }

                // Build the list of terms for the SOSL FIND clause.
                // Using escapeSingleQuotes for compatibility. This prevents errors from apostrophes.
                if (String.isNotBlank(name)) {
                    // Add wildcards for partial matching on the name.
                    searchTerms.add('*' + String.escapeSingleQuotes(name) + '*');
                }
                if (String.isNotBlank(email)) {
                    searchTerms.add(String.escapeSingleQuotes(email));
                }
                if (String.isNotBlank(phone)) {
                    searchTerms.add(String.escapeSingleQuotes(phone));
                }
                if (String.isNotBlank(businessName)) {
                    // Add wildcards for partial matching on business name.
                    searchTerms.add('*' + String.escapeSingleQuotes(businessName) + '*');
                }

                // Join the terms with ' OR ' to create the final search query string.
                // This creates a single string like '*John Doe* OR test@example.com'
                String soslQueryTerm = String.join(searchTerms, ' OR ');

                // Construct the full SOSL query with deep content fields
                String searchQuery = 'FIND :soslQueryTerm IN ALL FIELDS RETURNING ' +
                                     'Lead(Id, Name, Email, Phone, Status, Company, Owner.FirstName, Owner.LastName WHERE IsConverted = TRUE OR IsConverted = FALSE), ' +
                                     'Contact(Id, Name, Email, Phone, Account.Name, Owner.FirstName, Owner.LastName), ' +
                                     'Account(Id, Name, Phone, Owner.FirstName, Owner.LastName), ' +
                                     'Client_Intake__c(Id, Name, Owner.FirstName, Owner.LastName), ' +
                                     'Clio_Note__c(Id, Name, Detail__c, Matter__c, Contact__c, Owner.FirstName, Owner.LastName), ' +
                                     'Matter__c(Id, Name, Description__c, Status__c, Practice_Area__c, Account__c, Owner.FirstName, Owner.LastName), ' +
                                     'Time_Entry__c(Id, Name, Note__c, Activity_Description__c, Matter__c, Owner.FirstName, Owner.LastName)';

                // Execute the SOSL query with user mode
                List<List<SObject>> searchList = Search.query(searchQuery);

                // Add all found records to the results list.
                if (searchList != null && !searchList.isEmpty()) {
                    searchResults.addAll(searchList[0]); // Leads
                    searchResults.addAll(searchList[1]); // Contacts
                    searchResults.addAll(searchList[2]); // Accounts
                    searchResults.addAll(searchList[3]); // Intakes
                    searchResults.addAll(searchList[4]); // Clio Notes
                    searchResults.addAll(searchList[5]); // Matters
                    searchResults.addAll(searchList[6]); // Time Entries
                }

                // Process results and convert to ConflictMatch objects with risk scoring
                Map<String, Integer> matchCounts = new Map<String, Integer>();

                for (SObject record : searchResults) {
                    ConflictRiskScoringService.ConflictMatch match = convertToConflictMatch(
                        record, name, email, phone, businessName
                    );

                    // Track multiple matches for the same entity
                    String recordId = (String)record.get('Id');
                    if (!matchCounts.containsKey(recordId)) {
                        matchCounts.put(recordId, 0);
                    }
                    matchCounts.put(recordId, matchCounts.get(recordId) + 1);

                    conflictMatches.add(match);
                }

                // Update risk scores for multiple matches
                for (ConflictRiskScoringService.ConflictMatch match : conflictMatches) {
                    Boolean isMultipleMatch = matchCounts.get(match.id) > 1;
                    match.riskScore = ConflictRiskScoringService.calculateScore(
                        match.matchType,
                        match.recordType,
                        match.matterStatus,
                        isMultipleMatch
                    );
                    match.riskLevel = ConflictRiskScoringService.getRiskLevel(match.riskScore);
                }

                return conflictMatches;
            } else {
                // For platform license users without Lead/Contact/Account access, use without sharing
                return ConflictCheckWithoutSharing.findConflicts(name, email, phone, businessName);
            }
        } catch (System.QueryException e) {
            // In case of a query error, throw an AuraHandledException to be caught by the LWC.
            System.debug('Conflict Check SOSL Query failed: ' + e.getMessage());
            throw new AuraHandledException('The search could not be completed. Please check your input and try again.');
        } catch (Exception e) {
            throw new AuraHandledException('Error performing conflict check: ' + e.getMessage());
        }
    }
    
    /**
     * @description Saves conflict check results to Conflict_Check_Log__c and related Conflict_Match__c records.
     * @param leadId The ID of the Lead record.
     * @param name The name that was searched for.
     * @param email The email that was searched for.
     * @param phone The phone number that was searched for.
     * @param businessName The business name that was searched for.
     * @param matches The list of conflict matches found.
     * @return The ID of the created Conflict_Check_Log__c record.
     */
    @AuraEnabled
    public static String saveConflictCheck(Id leadId, String name, String email, String phone, String businessName, List<ConflictRiskScoringService.ConflictMatch> matches) {
        if (leadId == null) {
            throw new AuraHandledException('Lead ID is required to save conflict check.');
        }

        try {
            // Check if user has access permissions
            if (Schema.sObjectType.Conflict_Check_Log__c.isCreateable() &&
                Schema.sObjectType.Conflict_Match__c.isCreateable()) {

                // Calculate highest risk score
                Integer highestRiskScore = 0;
                if (matches != null && !matches.isEmpty()) {
                    for (ConflictRiskScoringService.ConflictMatch match : matches) {
                        if (match.riskScore != null && match.riskScore > highestRiskScore) {
                            highestRiskScore = match.riskScore;
                        }
                    }
                }

                // Create Conflict Check Log
                Conflict_Check_Log__c logRecord = new Conflict_Check_Log__c(
                    Lead__c = leadId,
                    Performed_By__c = UserInfo.getUserId(),
                    Performed_Date__c = DateTime.now(),
                    Search_Name__c = name,
                    Search_Email__c = email,
                    Search_Phone__c = phone,
                    Search_Business_Name__c = businessName,
                    Total_Matches__c = matches != null ? matches.size() : 0,
                    Highest_Risk_Score__c = highestRiskScore,
                    Status__c = 'Pending Review'
                );

                insert as user logRecord;

                // Create Conflict Match records
                if (matches != null && !matches.isEmpty()) {
                    List<Conflict_Match__c> matchRecords = new List<Conflict_Match__c>();

                    for (ConflictRiskScoringService.ConflictMatch match : matches) {
                        matchRecords.add(new Conflict_Match__c(
                            Conflict_Check_Log__c = logRecord.Id,
                            Matched_Record_Id__c = match.id,
                            Matched_Record_Type__c = match.recordType,
                            Matched_Record_Name__c = match.name,
                            Match_Type__c = match.matchType,
                            Risk_Score__c = match.riskScore,
                            Match_Reason__c = match.matchReason,
                            Matter_Status__c = match.matterStatus,
                            Reviewed__c = false
                        ));
                    }

                    insert as user matchRecords;
                }

                return logRecord.Id;
            } else {
                // For platform license users without access, use without sharing
                return ConflictCheckWithoutSharing.saveConflictCheck(leadId, name, email, phone, businessName, matches);
            }

        } catch (Exception e) {
            System.debug('Error saving conflict check: ' + e.getMessage());
            throw new AuraHandledException('Failed to save conflict check: ' + e.getMessage());
        }
    }
    
    /**
     * @description Retrieves the conflict check history for a Lead record from Conflict_Check_Log__c.
     * @param leadId The ID of the Lead record.
     * @return List of ConflictCheckLog wrapper objects containing log and match details.
     */
    @AuraEnabled
    public static List<ConflictCheckLog> getConflictCheckHistory(Id leadId) {
        if (leadId == null) {
            return new List<ConflictCheckLog>();
        }

        try {
            // Check if user has access permissions
            if (Schema.sObjectType.Conflict_Check_Log__c.isAccessible()) {
                List<Conflict_Check_Log__c> logs = [
                    SELECT Id, Name, Performed_Date__c, Performed_By__r.Name,
                           Search_Name__c, Search_Email__c, Search_Phone__c, Search_Business_Name__c,
                           Total_Matches__c, Highest_Risk_Score__c, Status__c,
                           (SELECT Id, Matched_Record_Id__c, Matched_Record_Type__c,
                                   Matched_Record_Name__c, Match_Type__c, Risk_Score__c,
                                   Risk_Level__c, Match_Reason__c, Matter_Status__c, Reviewed__c
                            FROM Conflict_Matches__r
                            ORDER BY Risk_Score__c DESC)
                    FROM Conflict_Check_Log__c
                    WHERE Lead__c = :leadId
                    WITH USER_MODE
                    ORDER BY Performed_Date__c DESC
                    LIMIT 50
                ];

                List<ConflictCheckLog> result = new List<ConflictCheckLog>();
                for (Conflict_Check_Log__c log : logs) {
                    result.add(new ConflictCheckLog(log));
                }
                return result;
            } else {
                // For platform license users without access, use without sharing
                return ConflictCheckWithoutSharing.getConflictCheckHistory(leadId);
            }
        } catch (Exception e) {
            System.debug('Error retrieving conflict check history: ' + e.getMessage());
            return new List<ConflictCheckLog>();
        }
    }

    /**
     * @description Updates the status of a conflict check log
     * @param logId The ID of the Conflict_Check_Log__c record to update
     * @param newStatus The new status value
     * @return String Success message or error
     */
    @AuraEnabled
    public static String updateConflictCheckStatus(Id logId, String newStatus) {
        if (logId == null || String.isBlank(newStatus)) {
            throw new AuraHandledException('Log ID and Status are required');
        }

        try {
            Conflict_Check_Log__c log = new Conflict_Check_Log__c(
                Id = logId,
                Status__c = newStatus
            );

            update as user log;
            return 'Status updated successfully';
        } catch (Exception e) {
            System.debug('Error updating conflict check status: ' + e.getMessage());
            throw new AuraHandledException('Failed to update status: ' + e.getMessage());
        }
    }

    /**
     * @description Wrapper class for conflict check log with matches
     */
    public class ConflictCheckLog {
        @AuraEnabled public String id;
        @AuraEnabled public String logNumber;
        @AuraEnabled public DateTime performedDate;
        @AuraEnabled public String performedBy;
        @AuraEnabled public String searchName;
        @AuraEnabled public String searchEmail;
        @AuraEnabled public String searchPhone;
        @AuraEnabled public String searchBusinessName;
        @AuraEnabled public Integer totalMatches;
        @AuraEnabled public Integer highestRiskScore;
        @AuraEnabled public String status;
        @AuraEnabled public List<ConflictMatchDetail> matches;

        public ConflictCheckLog(Conflict_Check_Log__c log) {
            this.id = log.Id;
            this.logNumber = log.Name;
            this.performedDate = log.Performed_Date__c;
            this.performedBy = log.Performed_By__r != null ? log.Performed_By__r.Name : '';
            this.searchName = log.Search_Name__c;
            this.searchEmail = log.Search_Email__c;
            this.searchPhone = log.Search_Phone__c;
            this.searchBusinessName = log.Search_Business_Name__c;
            this.totalMatches = log.Total_Matches__c != null ? Integer.valueOf(log.Total_Matches__c) : 0;
            this.highestRiskScore = log.Highest_Risk_Score__c != null ? Integer.valueOf(log.Highest_Risk_Score__c) : 0;
            this.status = log.Status__c;

            this.matches = new List<ConflictMatchDetail>();
            if (log.Conflict_Matches__r != null) {
                for (Conflict_Match__c match : log.Conflict_Matches__r) {
                    this.matches.add(new ConflictMatchDetail(match));
                }
            }
        }
    }

    /**
     * @description Wrapper class for individual conflict match details
     */
    public class ConflictMatchDetail {
        @AuraEnabled public String id;
        @AuraEnabled public String recordId;
        @AuraEnabled public String recordType;
        @AuraEnabled public String recordName;
        @AuraEnabled public String recordUrl;
        @AuraEnabled public String matchType;
        @AuraEnabled public Integer riskScore;
        @AuraEnabled public String riskLevel;
        @AuraEnabled public String matchReason;
        @AuraEnabled public String matterStatus;
        @AuraEnabled public Boolean reviewed;

        public ConflictMatchDetail(Conflict_Match__c match) {
            this.id = match.Id;
            this.recordId = match.Matched_Record_Id__c;
            this.recordType = match.Matched_Record_Type__c;
            this.recordName = match.Matched_Record_Name__c;
            this.recordUrl = '/' + match.Matched_Record_Id__c;
            this.matchType = match.Match_Type__c;
            this.riskScore = match.Risk_Score__c != null ? Integer.valueOf(match.Risk_Score__c) : 0;
            this.riskLevel = match.Risk_Level__c;
            this.matchReason = match.Match_Reason__c;
            this.matterStatus = match.Matter_Status__c;
            this.reviewed = match.Reviewed__c;
        }
    }
    
    /**
     * @description Searches for leads based on various criteria for users without full licenses.
     * @param searchTerm The search term to look for in lead fields.
     * @return List<Lead> A list of matching leads with basic information.
     */
    @AuraEnabled(cacheable=true)
    public static List<Lead> searchLeads(String searchTerm) {
        if (String.isBlank(searchTerm) || searchTerm.length() < 2) {
            return new List<Lead>();
        }
        
        try {
            // First try with user permissions
            if (Schema.sObjectType.Lead.isAccessible() && 
                Schema.sObjectType.Lead.fields.FirstName.isAccessible() &&
                Schema.sObjectType.Lead.fields.LastName.isAccessible() &&
                Schema.sObjectType.Lead.fields.Email.isAccessible() &&
                Schema.sObjectType.Lead.fields.Phone.isAccessible()) {
                
                String searchPattern = '%' + searchTerm + '%';
                
                return [
                    SELECT Id, FirstName, LastName, Email, Phone, Company, CreatedDate
                    FROM Lead
                    WHERE (FirstName LIKE :searchPattern
                        OR LastName LIKE :searchPattern
                        OR Email LIKE :searchPattern
                        OR Phone LIKE :searchPattern)
                    WITH USER_MODE
                    ORDER BY CreatedDate DESC
                    LIMIT 50
                ];
            } else {
                // For platform license users without Lead access, use without sharing
                return ConflictCheckWithoutSharing.searchLeads(searchTerm);
            }
        } catch (Exception e) {
            throw new AuraHandledException('Error searching for leads: ' + e.getMessage());
        }
    }

    /**
     * @description Converts an SObject search result to a ConflictMatch wrapper
     * @param record The SObject record from search results
     * @param searchName The name that was searched
     * @param searchEmail The email that was searched
     * @param searchPhone The phone that was searched
     * @param searchBusinessName The business name that was searched
     * @return ConflictMatch wrapper object
     */
    public static ConflictRiskScoringService.ConflictMatch convertToConflictMatch(
        SObject record,
        String searchName,
        String searchEmail,
        String searchPhone,
        String searchBusinessName
    ) {
        ConflictRiskScoringService.ConflictMatch match = new ConflictRiskScoringService.ConflictMatch();

        // Extract basic info
        String recordId = (String)record.get('Id');
        String recordType = String.valueOf(record.getSObjectType());
        String recordLabel = record.getSObjectType().getDescribe().getLabel();

        match.id = recordId;
        match.recordType = recordLabel;
        match.name = (String)record.get('Name');
        match.nameUrl = '/' + recordId;

        // Extract owner info
        try {
            SObject owner = record.getSObject('Owner');
            if (owner != null) {
                String firstName = (String)owner.get('FirstName');
                String lastName = (String)owner.get('LastName');
                match.ownerName = (firstName != null ? firstName + ' ' : '') + (lastName != null ? lastName : '');
                match.ownerName = match.ownerName.trim();
            }
        } catch (Exception e) {
            match.ownerName = '';
        }

        // Extract email and phone (for Contact and Lead)
        try {
            match.email = (String)record.get('Email');
        } catch (Exception e) {
            match.email = '';
        }

        try {
            match.phone = (String)record.get('Phone');
        } catch (Exception e) {
            match.phone = '';
        }

        // Extract Account name (for Contact)
        if (recordType == 'Contact') {
            try {
                SObject account = record.getSObject('Account');
                if (account != null) {
                    match.accountName = (String)account.get('Name');
                }
            } catch (Exception e) {
                match.accountName = '';
            }
        }

        // Extract Matter info (for Matter__c, Clio_Note__c, Time_Entry__c)
        if (recordType == 'Matter__c') {
            try {
                match.matterStatus = (String)record.get('Status__c');
                match.matterId = recordId;
            } catch (Exception e) {
                // Ignore
            }
        } else if (recordType == 'Clio_Note__c' || recordType == 'Time_Entry__c') {
            try {
                match.matterId = (String)record.get('Matter__c');
            } catch (Exception e) {
                // Ignore
            }
        }

        // Determine match type and reason
        List<String> matchReasons = new List<String>();
        String primaryMatchType = 'Name'; // Default

        // Check for exact email match
        if (String.isNotBlank(searchEmail) && String.isNotBlank(match.email) &&
            match.email.equalsIgnoreCase(searchEmail)) {
            primaryMatchType = 'Email';
            matchReasons.add('Exact email match: ' + match.email);
        }

        // Check for phone match
        if (String.isNotBlank(searchPhone) && String.isNotBlank(match.phone) &&
            match.phone.contains(searchPhone)) {
            primaryMatchType = 'Phone';
            matchReasons.add('Exact phone match: ' + match.phone);
        }

        // Check for name match
        if (String.isNotBlank(searchName) && String.isNotBlank(match.name) &&
            match.name.containsIgnoreCase(searchName)) {
            if (matchReasons.isEmpty()) {
                primaryMatchType = 'Name';
            }
            matchReasons.add('Name match: ' + match.name);
        }

        // Check for business name matches
        if (String.isNotBlank(searchBusinessName)) {
            if (recordType == 'Account' && String.isNotBlank(match.name) &&
                match.name.containsIgnoreCase(searchBusinessName)) {
                primaryMatchType = 'Business';
                matchReasons.add('Business name: ' + match.name);
            } else if (String.isNotBlank(match.accountName) &&
                       match.accountName.containsIgnoreCase(searchBusinessName)) {
                primaryMatchType = 'Business';
                matchReasons.add('Related business: ' + match.accountName);
            }
            // Check Lead Company field
            else if (recordType == 'Lead') {
                try {
                    String company = (String)record.get('Company');
                    if (String.isNotBlank(company) && company.containsIgnoreCase(searchBusinessName)) {
                        primaryMatchType = 'Business';
                        matchReasons.add('Company: ' + company);
                    }
                } catch (Exception e) {
                    // Field not available
                }
            }
        }

        // Check for content matches in Matter description
        if (recordType == 'Matter__c') {
            try {
                String description = (String)record.get('Description__c');
                if (String.isNotBlank(description)) {
                    Boolean foundInDescription = false;
                    if (String.isNotBlank(searchName) && description.containsIgnoreCase(searchName)) {
                        matchReasons.add('Name mentioned in matter description');
                        foundInDescription = true;
                    }
                    if (String.isNotBlank(searchEmail) && description.containsIgnoreCase(searchEmail)) {
                        matchReasons.add('Email mentioned in matter description');
                        foundInDescription = true;
                    }
                    if (String.isNotBlank(searchPhone) && description.contains(searchPhone)) {
                        matchReasons.add('Phone mentioned in matter description');
                        foundInDescription = true;
                    }
                    if (String.isNotBlank(searchBusinessName) && description.containsIgnoreCase(searchBusinessName)) {
                        matchReasons.add('Business mentioned in matter description');
                        foundInDescription = true;
                    }
                    if (foundInDescription && matchReasons.isEmpty()) {
                        primaryMatchType = 'Matter Relationship';
                    }
                }
            } catch (Exception e) {
                // Field not available
            }
        }

        // Check for content matches in Clio Note detail
        if (recordType == 'Clio_Note__c') {
            try {
                String detail = (String)record.get('Detail__c');
                if (String.isNotBlank(detail)) {
                    Boolean foundInDetail = false;
                    if (String.isNotBlank(searchName) && detail.containsIgnoreCase(searchName)) {
                        matchReasons.add('Name mentioned in note');
                        foundInDetail = true;
                    }
                    if (String.isNotBlank(searchEmail) && detail.containsIgnoreCase(searchEmail)) {
                        matchReasons.add('Email mentioned in note');
                        foundInDetail = true;
                    }
                    if (String.isNotBlank(searchPhone) && detail.contains(searchPhone)) {
                        matchReasons.add('Phone mentioned in note');
                        foundInDetail = true;
                    }
                    if (String.isNotBlank(searchBusinessName) && detail.containsIgnoreCase(searchBusinessName)) {
                        matchReasons.add('Business mentioned in note');
                        foundInDetail = true;
                    }
                    if (foundInDetail) {
                        primaryMatchType = 'Matter Relationship';
                    }
                }
            } catch (Exception e) {
                // Field not available
            }
        }

        // Check for content matches in Time Entry notes
        if (recordType == 'Time_Entry__c') {
            try {
                String note = (String)record.get('Note__c');
                String activityDesc = (String)record.get('Activity_Description__c');
                String combinedText = (String.isNotBlank(note) ? note : '') + ' ' +
                                     (String.isNotBlank(activityDesc) ? activityDesc : '');

                if (String.isNotBlank(combinedText)) {
                    Boolean foundInTimeEntry = false;
                    if (String.isNotBlank(searchName) && combinedText.containsIgnoreCase(searchName)) {
                        matchReasons.add('Name mentioned in time entry');
                        foundInTimeEntry = true;
                    }
                    if (String.isNotBlank(searchEmail) && combinedText.containsIgnoreCase(searchEmail)) {
                        matchReasons.add('Email mentioned in time entry');
                        foundInTimeEntry = true;
                    }
                    if (String.isNotBlank(searchPhone) && combinedText.contains(searchPhone)) {
                        matchReasons.add('Phone mentioned in time entry');
                        foundInTimeEntry = true;
                    }
                    if (String.isNotBlank(searchBusinessName) && combinedText.containsIgnoreCase(searchBusinessName)) {
                        matchReasons.add('Business mentioned in time entry');
                        foundInTimeEntry = true;
                    }
                    if (foundInTimeEntry) {
                        primaryMatchType = 'Matter Relationship';
                    }
                }
            } catch (Exception e) {
                // Field not available
            }
        }

        // Fallback if no specific match reason was found but SOSL returned it
        if (matchReasons.isEmpty()) {
            matchReasons.add('Found via search - check record details');
        }

        match.matchType = primaryMatchType;
        match.matchReason = String.join(matchReasons, '; ');

        return match;
    }
}