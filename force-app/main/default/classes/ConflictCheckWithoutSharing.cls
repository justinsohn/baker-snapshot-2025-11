/**
 * @description Helper class to perform conflict checks without sharing restrictions for platform license users.
 * This class bypasses sharing rules to allow platform license users to search for conflicts
 * and update Lead conflict check history even when they don't have standard Lead object access.
 */
public without sharing class ConflictCheckWithoutSharing {
    
    /**
     * @description Searches for records that match the given name, email, phone, or business name without sharing restrictions.
     * @param name The name to search for.
     * @param email The email to search for.
     * @param phone The phone number to search for.
     * @param businessName The business/company name to search for.
     * @return A list of ConflictMatch records with risk scores.
     */
    public static List<ConflictRiskScoringService.ConflictMatch> findConflicts(String name, String email, String phone, String businessName) {
        // Initialize lists and maps for processing
        List<ConflictRiskScoringService.ConflictMatch> conflictMatches = new List<ConflictRiskScoringService.ConflictMatch>();
        List<SObject> searchResults = new List<SObject>();
        List<String> searchTerms = new List<String>();

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

        // Execute the SOSL query
        try {
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
                ConflictRiskScoringService.ConflictMatch match = ConflictCheckController.convertToConflictMatch(
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

        } catch (System.QueryException e) {
            // In case of a query error, throw an AuraHandledException to be caught by the LWC.
            System.debug('Conflict Check SOSL Query failed: ' + e.getMessage());
            throw new AuraHandledException('The search could not be completed. Please check your input and try again.');
        }

        return conflictMatches;
    }
    
    /**
     * @description Saves conflict check results to Conflict_Check_Log__c and related Conflict_Match__c records without sharing restrictions.
     * @param leadId The ID of the Lead record.
     * @param name The name that was searched for.
     * @param email The email that was searched for.
     * @param phone The phone number that was searched for.
     * @param businessName The business name that was searched for.
     * @param matches The list of conflict matches found.
     * @return The ID of the created Conflict_Check_Log__c record.
     */
    public static String saveConflictCheck(Id leadId, String name, String email, String phone, String businessName, List<ConflictRiskScoringService.ConflictMatch> matches) {
        if (leadId == null) {
            throw new AuraHandledException('Lead ID is required to save conflict check.');
        }

        try {
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

            insert logRecord;

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

                insert matchRecords;
            }

            return logRecord.Id;

        } catch (Exception e) {
            System.debug('Error saving conflict check: ' + e.getMessage());
            throw new AuraHandledException('Failed to save conflict check: ' + e.getMessage());
        }
    }

    /**
     * @description Retrieves the conflict check history for a Lead record from Conflict_Check_Log__c without sharing restrictions.
     * @param leadId The ID of the Lead record.
     * @return List of ConflictCheckLog wrapper objects containing log and match details.
     */
    public static List<ConflictCheckController.ConflictCheckLog> getConflictCheckHistory(Id leadId) {
        if (leadId == null) {
            return new List<ConflictCheckController.ConflictCheckLog>();
        }

        try {
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
                ORDER BY Performed_Date__c DESC
                LIMIT 50
            ];

            List<ConflictCheckController.ConflictCheckLog> result = new List<ConflictCheckController.ConflictCheckLog>();
            for (Conflict_Check_Log__c log : logs) {
                result.add(new ConflictCheckController.ConflictCheckLog(log));
            }
            return result;
        } catch (Exception e) {
            System.debug('Error retrieving conflict check history: ' + e.getMessage());
            return new List<ConflictCheckController.ConflictCheckLog>();
        }
    }
    
    /**
     * @description Validates that a Lead record exists with the given ID.
     * @param leadId The Lead ID to validate.
     * @return List<Lead> A list containing the Lead if it exists, empty if not.
     */
    public static List<Lead> validateLeadExists(Id leadId) {
        if (leadId == null) {
            return new List<Lead>();
        }
        
        return [
            SELECT Id
            FROM Lead
            WHERE Id = :leadId
            LIMIT 1
        ];
    }
    
    /**
     * @description Searches for leads based on various criteria without sharing restrictions.
     * @param searchTerm The search term to look for in lead fields.
     * @return List<Lead> A list of matching leads with basic information.
     */
    public static List<Lead> searchLeads(String searchTerm) {
        if (String.isBlank(searchTerm) || searchTerm.length() < 2) {
            return new List<Lead>();
        }
        
        String searchPattern = '%' + searchTerm + '%';
        
        return [
            SELECT Id, FirstName, LastName, Email, Phone, Company, CreatedDate
            FROM Lead
            WHERE (FirstName LIKE :searchPattern
                OR LastName LIKE :searchPattern
                OR Email LIKE :searchPattern
                OR Phone LIKE :searchPattern)
            ORDER BY CreatedDate DESC
            LIMIT 50
        ];
    }
}