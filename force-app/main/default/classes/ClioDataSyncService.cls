public with sharing class ClioDataSyncService implements Database.Batchable<Object>, Database.Stateful, Database.AllowsCallouts{

    private static final Integer DEFAULT_PAGE_SIZE = 200;
    private static final Integer BATCH_SIZE = 2000;
    public List<List<Object>> objectsLists;
    public String objectTypeToProcess;

    Set<Id> successRecords = new Set<Id>();
    Map<String,String> failedRecords = new Map<String,String>();

    public ClioDataSyncService(List<List<Object>> objectsLists, String objectTypeToProcess){
        this.objectTypeToProcess = objectTypeToProcess;
        this.objectsLists = objectsLists;
    }

    public List<Object> start(Database.BatchableContext BC){
        system.debug('Records to process in this batchable job: '+this.objectsLists[0].size());
        return this.objectsLists[0];
    }

    public void execute(Database.BatchableContext BC, List<Object> scope){
        system.debug('Scope size: '+ scope.size());
        switch on this.objectTypeToProcess{
            when 'users'{
                syncUsers(scope,failedRecords);
            }
            when 'contacts'{
                syncContacts(scope,failedRecords);
            }
            when 'matters'{
                syncMatters(scope,failedRecords);
            }
            when 'relationships'{
                syncRelationships(scope,failedRecords);
            }
            when 'matterNotes'{
                syncNotes(scope,failedRecords,'matter');
            }
            when 'contactNotes'{
                syncNotes(scope,failedRecords,'contact');
            }
            when 'activities'{
                syncTimeEntries(scope,failedRecords);
            }
            when 'bills'{
                syncBills(scope,failedRecords);
            }
            when 'calendar_entries'{
                syncCalendarEntries(scope,failedRecords);
            }
            when 'bank_transactions'{
                syncPayments(scope,failedRecords);
            }
        }
        system.debug('failedRecords size at the end of the batch execution: '+failedRecords.keySet().size());
    }

    public void finish(Database.BatchableContext BC){
        this.objectsLists.remove(0);
        if(!this.objectsLists.isEmpty()){
            Database.executeBatch(new ClioDataSyncService(this.objectsLists, this.objectTypeToProcess),BATCH_SIZE);
        }
        AsyncApexJob jobSummary = [SELECT Id, Status, NumberOfErrors, JobItemsProcessed, TotalJobItems, CreatedBy.Email 
            FROM AsyncApexJob WHERE Id =:BC.getJobId()];
        system.debug('Email address: '+jobSummary.CreatedBy.Email);
        if(!failedRecords.isEmpty()){
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            List<String> toAddresses = new List<String>{jobSummary.CreatedBy.Email};
            mail.setToAddresses(toAddresses);
            mail.setSubject('Failed records details for BulkDMLBatch on '+this.objectTypeToProcess+'.');
            String emailBody = 'The batch Apex job processed ' + jobSummary.TotalJobItems + ' batches with '+ failedRecords.keySet().size() + ' failures.\n\n' +
                'Failed records and reasons:\n' + generateFailedRecordDetails();
            mail.setPlainTextBody(emailBody);
            try {
                Messaging.sendEmail(new Messaging.SingleEmailMessage[] {mail});
                System.debug('Email sent successfully to ' + jobSummary.CreatedBy.Email);
            } catch (Exception ex){
                System.debug('Error sending email: '+ex.getMessage()+'; Email sent to '+jobSummary.CreatedBy.Email);
            }
        }
        if(this.objectsLists.isEmpty()){ // all the records were processed
            switch on this.objectTypeToProcess{
                when 'users'{
                    ClioDataRetrieveService.syncContacts(null);
                }
                when 'contacts'{
                    ClioDataRetrieveService.syncMatters(null);
                }
                when 'matters'{
                    ClioDataRetrieveService.syncRelationships(null);
                }
                when 'relationships'{
                    ClioDataRetrieveService.syncNotes(null,'contact');
                }
                when 'contactNotes'{
                    ClioDataRetrieveService.syncNotes(null,'matter');
                }
                when 'matterNotes'{
                    ClioDataRetrieveService.syncTimeEntries(null);
                }
                when 'activities'{
                    ClioDataRetrieveService.syncBills(null);
                }
                when 'bills'{
                    ClioDataRetrieveService.syncCalendarEntries(null);
                }
                when 'calendar_entries'{
                    ClioDataRetrieveService.syncPayments(null);
                }
                when 'bank_transactions'{
                    if(!Test.isRunningTest()) ClioAsyncIntegrationScheduler.scheduleSync(10);
                }
            }
        }
    }



    public static void syncUsers(List<Object> clioUsers,Map<String,String> failedRecords) {
        try {
            Map<String, String> clioUserEmailMap = new Map<String, String>();
            List<User> usersToCreate = new List<User>();
            
            for (Object obj : clioUsers) {
                Map<String, Object> userData = (Map<String, Object>) obj;
                String email = (String) userData.get('email');
                String clioId = String.valueOf(userData.get('id'));
                
                if (String.isNotBlank(email)) {
                    clioUserEmailMap.put(email.toLowerCase(), clioId);
                }
            }
            
            // CHANGED: Create a list of emails with the .invalid suffix for the SOQL query.
            // This is more efficient than manipulating strings inside the query.
            List<String> sandboxEmailsToQuery = new List<String>();
            for(String clioEmail : clioUserEmailMap.keySet()){
                sandboxEmailsToQuery.add(clioEmail + '.invalid');
            }

            // CHANGED: Query using the modified email list and the original emails,
            // just in case some are not appended with .invalid.
            List<User> existingUsers = [
                SELECT Id, Email, Clio_Id__c 
                FROM User 
                WHERE Email IN :clioUserEmailMap.keySet() OR Email IN :sandboxEmailsToQuery
            ];
            system.debug('Number of existing users: '+existingUsers.size());
            
            Set<String> existingUserEmails = new Set<String>();
            for(User u : existingUsers) {
                // CHANGED: Remove the '.invalid' suffix before adding the email to the set.
                // This normalizes the email for a direct comparison with Clio data.
                existingUserEmails.add(u.Email.removeEnd('.invalid').toLowerCase());
                system.debug('Existing user email: '+u.Email.removeEnd('.invalid').toLowerCase());
            }
            
            for (Object obj : clioUsers) {
                Map<String, Object> userData = (Map<String, Object>) obj;
                String email = (String) userData.get('email');
                // This check for new users now works correctly against the normalized email set.
                if (String.isNotBlank(email) && !existingUserEmails.contains(email.toLowerCase())) {
                    String useralias = String.isNotBlank((String)userData.get('first_name'))? ((String)userData.get('last_name')).length() > 3 ? ((String)userData.get('first_name')).substring(0,1) + ((String)userData.get('last_name')).substring(0,4) : ((String)userData.get('first_name')).substring(0,1) + (String)userData.get('last_name') : ((String)userData.get('last_name')).length() > 3 ? ((String)userData.get('last_name')).substring(0,4) : (String)userData.get('last_name');
                    usersToCreate.add(new User(
                        FirstName = (String)userData.get('first_name'),
                        LastName = (String)userData.get('last_name'),
                        Email = email,
                        Username = email,
                        Alias = useralias,
                        CommunityNickname = (String)userData.get('name'),
                        TimeZoneSidKey = 'America/Los_Angeles',
                        LocaleSidKey = 'en_US',
                        EmailEncodingKey = 'UTF-8',
                        ProfileId = '00e5f000001gYziAAE', // Standard User Profile ID - may need to be adjusted
                        LanguageLocaleKey = 'en_US',
                        Clio_Id__c = String.valueOf(userData.get('id'))
                        )
                    );
                }
            }

            List<User> usersToUpdate = new List<User>();
            

            for (User u : existingUsers) {
                // CHANGED: Remove the '.invalid' suffix from the user's email before using it
                // as a key to get the Clio ID from the map.
                String normalizedEmail = u.Email.removeEnd('.invalid').toLowerCase();
                String clioId = clioUserEmailMap.get(normalizedEmail);
                if (u.Clio_Id__c != clioId) {
                    u.Clio_Id__c = clioId;
                    usersToUpdate.add(u);
                }
            }
            system.debug('Number of users to create: '+usersToCreate.size());
            if (!usersToCreate.isEmpty()) {
                // insert usersToCreate;
            }
            system.debug('Number of users to update: '+usersToUpdate.size());
            if (!usersToUpdate.isEmpty()) {   
                processDMLsync(usersToUpdate, null, 'update',failedRecords);
            }
            
            // Update sync timestamp
            ClioSyncTimestampManager.updateLastSyncTime('User', DateTime.now());
        } catch (Exception e) {
            System.debug('Error syncing users: ' + e.getMessage());
            throw e;
        }
    }
    
    public static void syncContacts(List<Object> clioContacts,Map<String,String> failedRecords) {
        try {
            List<Contact> contactsToUpsert = new List<Contact>();

            for (Object obj : clioContacts) {
                Map<String, Object> contactData = (Map<String, Object>) obj;
                Contact sfContact = mapClioContactToSalesforce(contactData);
                contactsToUpsert.add(sfContact);
            }
            system.debug('Number of contacts to upsert: '+contactsToUpsert.size());
            if (!contactsToUpsert.isEmpty()) {
                system.debug('failedRecords size before dml: '+failedRecords.keySet().size());
                processDMLsync(contactsToUpsert, Contact.Clio_Id__c, 'upsert',failedRecords);
                system.debug('failedRecords size after dml: '+failedRecords.keySet().size());
            }
                     // Update sync timestamp
            ClioSyncTimestampManager.updateLastSyncTime('Contact', DateTime.now());
        } catch (Exception e) {
            System.debug('Error syncing contacts: ' + e.getMessage());
            throw e;
        }
    }
    
    public static void syncMatters(List<Object> clioMatters,Map<String,String> failedRecords) {
        try {
            List<Matter__c> mattersToUpsert = new List<Matter__c>();
            // Collect all client and attorney Clio IDs for bulk queries
            Set<String> clientClioIds = new Set<String>();
            Set<String> attorneyClioIds = new Set<String>();
            //Map<String,Date> dateFASignedByMatterId = new Map<String,Date>();
            
            for (Object obj : clioMatters) {
                Map<String, Object> matterData = (Map<String, Object>) obj;
                Map<String, Object> client = (Map<String, Object>) matterData.get('client');
                Map<String, Object> responsibleAttorney = (Map<String, Object>) matterData.get('responsible_attorney');
                /*List<Object> custom_field_values = (List<Object>) matterData.get('custom_field_values') != null? (List<Object>) matterData.get('custom_field_values') : new List<Object>();
                if(!custom_field_values.isEmpty()){
                    Map<String,Object> dateFAwasSignedObject = (Map<String, Object>) custom_field_values[0];
                    if(dateFAwasSignedObject.get('value') != null){
                        dateFASignedByMatterId.put(String.valueOf(matterData.get('id')),Date.valueOf((String) dateFAwasSignedObject.get('value')));
                    }
                }*/
                
                if (client != null) {
                    clientClioIds.add(String.valueOf(client.get('id')));
                }
                if (responsibleAttorney != null) {
                    attorneyClioIds.add(String.valueOf(responsibleAttorney.get('id')));
                }
            }
            
            // Bulk query for contacts and users
            Map<String, Id> clientIdMap = new Map<String, Id>();
            Map<String, Id> attorneyIdMap = new Map<String, Id>();
            
            // Skip queries if fields aren't deployed yet
            try {
                if (!clientClioIds.isEmpty()) {
                    for (Contact c : [SELECT Id, Clio_Id__c FROM Contact WHERE Clio_Id__c IN :clientClioIds]) {
                        clientIdMap.put(c.Clio_Id__c, c.Id);
                    }
                }
                if (!attorneyClioIds.isEmpty()) {
                    for (User u : [SELECT Id, Clio_Id__c FROM User WHERE Clio_Id__c IN :attorneyClioIds]) {
                        attorneyIdMap.put(u.Clio_Id__c, u.Id);
                    }
                }
            } catch (Exception queryEx) {
                System.debug('Custom fields not deployed yet: ' + queryEx.getMessage());
            }
            
            for (Object obj : clioMatters) {
                Map<String, Object> matterData = (Map<String, Object>) obj;             
                Matter__c sfMatter = mapClioMatterToSalesforce(matterData, clientIdMap, attorneyIdMap);
                mattersToUpsert.add(sfMatter);
            }
            system.debug('Number of matters to upsert: '+mattersToUpsert.size());
            if (!mattersToUpsert.isEmpty()) {
                try {
                    system.debug('failedRecords size before dml: '+failedRecords.keySet().size());
                    processDMLsync(mattersToUpsert, Matter__c.Clio_Id__c, 'upsert',failedRecords);
                    system.debug('failedRecords size after dml: '+failedRecords.keySet().size());  
                } catch (Exception upsertEx) {
                    System.debug('Custom fields not deployed yet for upsert: ' + upsertEx.getMessage());
                    //insert mattersToUpsert; // Use regular insert if external ID field not available
                }
            }

            /*if(!dateFASignedByMatterId.keySet().isEmpty()){
                List<Lead> leadsToUpdate = [Select id, Clio_Matter_ID__c, Lead_Completion_Date__c from Lead Where Clio_Matter_ID__c IN :dateFASignedByMatterId.keySet()];
                if(!leadsToUpdate.isEmpty()){
                    for(Lead ld : leadsToUpdate){
                        ld.Lead_Completion_Date__c = dateFASignedByMatterId.get(ld.Clio_Matter_ID__c);
                    }
                    processDMLsync(leadsToUpdate, Lead.Clio_Matter_ID__c, 'upsert',failedRecords);
                }
            }*/
            
            // Update sync timestamp
            ClioSyncTimestampManager.updateLastSyncTime('Matter', DateTime.now());
        } catch (Exception e) {
            System.debug('Error syncing matters: ' + e.getMessage());
            throw e;
        }
    }

    public static void syncRelationships(List<Object> clioRelationships,Map<String,String> failedRecords) {
        try {
            List<MatterContact__c> matterContactsToUpsert = new List<MatterContact__c>();
            Map<String,String> sfContactIdsByClioIds = new Map<String,String>();
            Map<String,String> sfMatterIdsByClioIds = new Map<String,String>();
            Set<String> contactIds = new Set<String>();
            Set<String> matterIds = new Set<String>();
            for (Object obj : clioRelationships) {
                Map<String, Object> matterContactData = (Map<String, Object>) obj;
                Map<String, Object> contact = (Map<String, Object>) matterContactData.get('contact');
                Map<String, Object> matter = (Map<String, Object>) matterContactData.get('matter');
                if(contact != null){
                    contactIds.add(String.valueOf(contact.get('id')));
                }
                if(matter != null){
                    matterIds.add(String.valueOf(matter.get('id')));
                }
            }
            List<Contact> contacts = [SELECT Id, Clio_Id__c FROM Contact WHERE Clio_Id__c IN :contactIds];
            for(Contact con : contacts){
                sfContactIdsByClioIds.put(con.Clio_Id__c,con.Id);
            }
            List<Matter__c> matters = [SELECT Id, Clio_Id__c FROM Matter__c WHERE Clio_Id__c IN :matterIds];
            for(Matter__c mat : matters){
                sfMatterIdsByClioIds.put(mat.Clio_Id__c,mat.Id);
            }

            for (Object obj : clioRelationships) {
                Map<String, Object> matterContactData = (Map<String, Object>) obj;
                MatterContact__c sfMatterContact = mapClioRelationshipToSalesforce(matterContactData,sfContactIdsByClioIds,sfMatterIdsByClioIds);
                matterContactsToUpsert.add(sfMatterContact);
            }
            system.debug('Number of matterContacts to upsert: '+matterContactsToUpsert.size());
            if (!matterContactsToUpsert.isEmpty()) {
                system.debug('failedRecords size before dml: '+failedRecords.keySet().size());
                processDMLsync(matterContactsToUpsert, MatterContact__c.Clio_Id__c, 'upsert',failedRecords);
                system.debug('failedRecords size after dml: '+failedRecords.keySet().size());
            }
                     // Update sync timestamp
            ClioSyncTimestampManager.updateLastSyncTime('MatterContact', DateTime.now());
        } catch (Exception e) {
            System.debug('Error syncing matterContacts: ' + e.getMessage());
            throw e;
        }
    }
    
    public static void syncTimeEntries(List<Object> clioTimeEntries,Map<String,String> failedRecords) {
        try {
            List<Time_Entry__c> timeEntriesToUpsert = new List<Time_Entry__c>();
            
            // Collect all matter and user Clio IDs for bulk queries
            Set<String> matterClioIds = new Set<String>();
            Set<String> userClioIds = new Set<String>();
            
            for (Object obj : clioTimeEntries) {
                Map<String, Object> timeData = (Map<String, Object>) obj;
                Map<String, Object> matter = (Map<String, Object>) timeData.get('matter');
                Map<String, Object> user = (Map<String, Object>) timeData.get('user');
                
                if (matter != null) {
                    matterClioIds.add(String.valueOf(matter.get('id')));
                }
                if (user != null) {
                    userClioIds.add(String.valueOf(user.get('id')));
                }
            }
            
            // Bulk query for matters and users
            Map<String, Id> matterIdMap = new Map<String, Id>();
            Map<String, Id> userIdMap = new Map<String, Id>();
            
            // Skip queries if fields aren't deployed yet
            try {
                if (!matterClioIds.isEmpty()) {
                    for (Matter__c m : [SELECT Id, Clio_Id__c FROM Matter__c WHERE Clio_Id__c IN :matterClioIds]) {
                        matterIdMap.put(m.Clio_Id__c, m.Id);
                    }
                }
                if (!userClioIds.isEmpty()) {
                    for (User u : [SELECT Id, Clio_Id__c FROM User WHERE Clio_Id__c IN :userClioIds]) {
                        userIdMap.put(u.Clio_Id__c, u.Id);
                    }
                }
            } catch (Exception queryEx) {
                System.debug('Custom fields not deployed yet: ' + queryEx.getMessage());
            }
            
            for (Object obj : clioTimeEntries) {
                Map<String, Object> timeData = (Map<String, Object>) obj;
                Time_Entry__c sfTimeEntry = mapClioTimeEntryToSalesforce(timeData, matterIdMap, userIdMap);
                timeEntriesToUpsert.add(sfTimeEntry);
            }
            system.debug('Number of Time Entries to upsert: '+timeEntriesToUpsert.size());
            if (!timeEntriesToUpsert.isEmpty()) {
                try {
                    system.debug('failedRecords size before dml: '+failedRecords.keySet().size());
                    processDMLsync(timeEntriesToUpsert, Time_Entry__c.Clio_Id__c, 'upsert',failedRecords);
                    system.debug('failedRecords size after dml: '+failedRecords.keySet().size());
                } catch (Exception upsertEx) {
                    System.debug('Custom fields not deployed yet for upsert: ' + upsertEx.getMessage());
                    //insert timeEntriesToUpsert; // Use regular insert if external ID field not available
                }
            }
            
            // Update sync timestamp
            ClioSyncTimestampManager.updateLastSyncTime('TimeEntry', DateTime.now());
        } catch (Exception e) {
            System.debug('Error syncing time entries: ' + e.getMessage());
            throw e;
        }
    }
    
    public static void syncBills(List<Object> clioBills,Map<String,String> failedRecords) {
        try {
            List<Invoice__c> invoicesToUpsert = new List<Invoice__c>();
            // Collect all client and matter Clio IDs for bulk queries
            Set<String> clientClioIds = new Set<String>();
            Set<String> matterClioIds = new Set<String>();
            
            for (Object obj : clioBills) {
                Map<String, Object> billData = (Map<String, Object>) obj;
                Map<String, Object> client = (Map<String, Object>) billData.get('client');
                List<Object> matters = (List<Object>) billData.get('matters');
                for(Object currentMatter : matters){
                    Map<String, Object> matter = (Map<String, Object>) currentMatter;
                    matterClioIds.add(String.valueOf(matter.get('id')));
                }        
                if (client != null) {
                    clientClioIds.add(String.valueOf(client.get('id')));
                }

            }
            
            // Bulk query for contacts and matters
            Map<String, Id> clientIdMap = new Map<String, Id>();
            Map<String, Id> matterIdMap = new Map<String, Id>();
            
            // Skip queries if fields aren't deployed yet
            try {
                if (!clientClioIds.isEmpty()) {
                    for (Contact c : [SELECT Id, Clio_Id__c FROM Contact WHERE Clio_Id__c IN :clientClioIds]) {
                        clientIdMap.put(c.Clio_Id__c, c.Id);
                    }
                }
                if (!matterClioIds.isEmpty()) {
                    for (Matter__c m : [SELECT Id, Clio_Id__c FROM Matter__c WHERE Clio_Id__c IN :matterClioIds]) {
                        matterIdMap.put(m.Clio_Id__c, m.Id);
                    }
                }
            } catch (Exception queryEx) {
                System.debug('Custom fields not deployed yet: ' + queryEx.getMessage());
            }
            
            for (Object obj : clioBills) {
                Map<String, Object> billData = (Map<String, Object>) obj;
                Invoice__c sfInvoice = mapClioBillToSalesforce(billData, clientIdMap, matterIdMap);
                invoicesToUpsert.add(sfInvoice);
            }
            system.debug('Number of invoices to upsert: '+invoicesToUpsert.size());
            if (!invoicesToUpsert.isEmpty()) {
                try {
                    system.debug('failedRecords size before dml: '+failedRecords.keySet().size());
                    processDMLsync(invoicesToUpsert, Invoice__c.Clio_Id__c, 'upsert',failedRecords);
                    system.debug('failedRecords size after dml: '+failedRecords.keySet().size());
                } catch (Exception upsertEx) {
                    System.debug('Custom fields not deployed yet for upsert: ' + upsertEx.getMessage());
                    //insert invoicesToUpsert; // Use regular insert if external ID field not available
                }
            }
            
            // Update sync timestamp
            ClioSyncTimestampManager.updateLastSyncTime('Bill', DateTime.now());
        } catch (Exception e) {
            System.debug('Error syncing bills: ' + e.getMessage());
            throw e;
        }
    }
    
    public static void syncCalendarEntries(List<Object> clioCalendarEntries,Map<String,String> failedRecords) {
        try {
            List<Calendar_Event__c> eventsToUpsert = new List<Calendar_Event__c>();
            // Collect all matter and calendar owner Clio IDs for bulk queries
            Set<String> matterClioIds = new Set<String>();
            Set<String> calOwnerClioIds = new Set<String>();
            Set<String> calIds = new Set<String>();
            
            for (Object obj : clioCalendarEntries) {
                Map<String, Object> eventData = (Map<String, Object>) obj;
                Map<String, Object> matter = (Map<String, Object>) eventData.get('matter');
                if(eventData.get('calendar_owner_id')!= null){
                    calIds.add(String.valueOf(eventData.get('calendar_owner_id')));
                }
                if (matter != null) {
                    matterClioIds.add(String.valueOf(matter.get('id')));
                }
            }

            Map<String, String> calendarCallparams = new Map<String, String>();
            calendarCallparams.put('fields', 'id,creator{id}');
            for(String calId : calIds){
                calendarCallparams.put('ids[]',calId);
            }
            calendarCallparams.put('order', 'id(asc)');
            calendarCallparams.put('limit', String.valueOf(DEFAULT_PAGE_SIZE));
            String queryString = ClioIntegrationServiceQueueable.buildQueryString(calendarCallparams);
            String fullEndpoint = '/calendars' + (queryString.length() > 0 ? '?' + queryString : '');
            
            System.debug('fullEndpoint: ' + fullEndpoint);
            
            HttpResponse res = ClioIntegrationServiceQueueable.makeCallout(fullEndpoint, 'GET', null);
            ClioIntegrationServiceQueueable.ClioApiResponse apiResponse = ClioIntegrationServiceQueueable.parseResponse(res.getBody());
            Map<String,String> clioUserByClioCalendarId = new Map<String,String>();
            if (apiResponse.data != null) {
                for(Object obj : apiResponse.data){
                    Map<String,Object> calendar = (Map<String,Object>) obj;
                    if(calendar.get('creator') != null){
                        Map<String,Object> creator = (Map<String,Object>) calendar.get('creator');
                        if(creator.get('id') != null){
                            clioUserByClioCalendarId.put(String.valueOf(calendar.get('id')),String.valueOf(creator.get('id')));
                            calOwnerClioIds.add(String.valueOf(creator.get('id')));
                        }
                    }
                }
            }
            // Bulk query for matters and calendar owners
            Map<String, Id> matterIdMap = new Map<String, Id>();
            Map<String, Id> calOwnerIdMap = new Map<String, Id>();
            
            // Skip queries if fields aren't deployed yet
            try {
                if (!matterClioIds.isEmpty()) {
                    for (Matter__c m : [SELECT Id, Clio_Id__c FROM Matter__c WHERE Clio_Id__c IN :matterClioIds]) {
                        matterIdMap.put(m.Clio_Id__c, m.Id);
                    }
                    for (User u : [SELECT Id, Clio_Id__c FROM User WHERE Clio_Id__c IN :calOwnerClioIds]) {
                        calOwnerIdMap.put(u.Clio_Id__c, u.Id);
                    }
                }
            } catch (Exception queryEx) {
                System.debug('Custom fields not deployed yet: ' + queryEx.getMessage());
            }
            
            for (Object obj : clioCalendarEntries) {
                Map<String, Object> eventData = (Map<String, Object>) obj;
                Calendar_Event__c sfEvent = mapClioCalendarToSalesforce(eventData, calOwnerIdMap, matterIdMap,clioUserByClioCalendarId);
                if(sfEvent.Assigned_To__c != null){
                    eventsToUpsert.add(sfEvent);
                }
            }
            system.debug('Number of events to upsert: '+eventsToUpsert.size());
            if (!eventsToUpsert.isEmpty()) {
                try {
                    system.debug('failedRecords size before dml: '+failedRecords.keySet().size());
                    processDMLsync(eventsToUpsert, Calendar_Event__c.Clio_Event_ID__c, 'upsert',failedRecords);
                    system.debug('failedRecords size after dml: '+failedRecords.keySet().size());
                } catch (Exception upsertEx) {
                    System.debug('Custom fields not deployed yet for upsert: ' + upsertEx.getMessage());
                    //insert eventsToUpsert; // Use regular insert if external ID field not available
                }
            }
            
            // Update sync timestamp
            ClioSyncTimestampManager.updateLastSyncTime('Calendar', DateTime.now());
        } catch (Exception e) {
            System.debug('Error syncing calendar entries: ' + e.getMessage());
            throw e;
        }
    }
    
    public static void syncPayments(List<Object> clioPayments,Map<String,String> failedRecords) {
        try {
            List<Payment__c> paymentsToUpsert = new List<Payment__c>();
            // Collect all matter and bill Clio IDs for bulk queries from payments only
            Set<String> matterClioIds = new Set<String>();
            Set<String> billClioIds = new Set<String>();
            Set<String> clientClioIds = new Set<String>();
            
            for (Object obj : clioPayments) {
                Map<String, Object> paymentData = (Map<String, Object>) obj;                
                Map<String, Object> matter = (Map<String, Object>) paymentData.get('matter');
                Map<String, Object> bill = (Map<String, Object>) paymentData.get('bill');
                Map<String, Object> client = (Map<String, Object>) paymentData.get('client');
                if (matter != null) {
                    matterClioIds.add(String.valueOf(matter.get('id')));
                }
                if (bill != null) {
                    billClioIds.add(String.valueOf(bill.get('id')));
                }
                if (client != null) {
                    clientClioIds.add(String.valueOf(client.get('id')));
                }
            }
            
            // Bulk query for matters, bills and clients
            Map<String, Id> matterIdMap = new Map<String, Id>();
            Map<String, Id> billIdMap = new Map<String, Id>();
            Map<String, Id> clientIdMap = new Map<String, Id>();
            
            // Skip queries if fields aren't deployed yet
            try {
                if (!matterClioIds.isEmpty()) {
                    for (Matter__c m : [SELECT Id, Clio_Id__c FROM Matter__c WHERE Clio_Id__c IN :matterClioIds]) {
                        matterIdMap.put(m.Clio_Id__c, m.Id);
                    }
                }
                if (!billClioIds.isEmpty()) {
                    for (Invoice__c i : [SELECT Id, Clio_Id__c FROM Invoice__c WHERE Clio_Id__c IN :billClioIds]) {
                        billIdMap.put(i.Clio_Id__c, i.Id);
                    }
                }
                if (!clientClioIds.isEmpty()) {
                    for (Contact c : [SELECT Id, Clio_Id__c FROM Contact WHERE Clio_Id__c IN :clientClioIds]) {
                        clientIdMap.put(c.Clio_Id__c, c.Id);
                    }
                }
            } catch (Exception queryEx) {
                System.debug('Custom fields not deployed yet: ' + queryEx.getMessage());
            }
            
            for (Object obj : clioPayments) {
                Map<String, Object> paymentData = (Map<String, Object>) obj;
                //if (paymentData.get('type') == 'Payment') {
                Payment__c sfPayment = mapClioPaymentToSalesforce(paymentData, matterIdMap, billIdMap, clientIdMap);
                paymentsToUpsert.add(sfPayment);
                //}
            }
            system.debug('Number of payments to update: '+paymentsToUpsert.size());
            if (!paymentsToUpsert.isEmpty()) {
                try {
                    system.debug('failedRecords size before dml: '+failedRecords.keySet().size());
                    processDMLsync(paymentsToUpsert, Payment__c.Clio_Id__c, 'upsert',failedRecords);
                    system.debug('failedRecords size after dml: '+failedRecords.keySet().size());
                } catch (Exception upsertEx) {
                    System.debug('Custom fields not deployed yet for upsert: ' + upsertEx.getMessage());
                    //insert paymentsToUpsert; // Use regular insert if external ID field not available
                }
            }
            
            // Update sync timestamp
            ClioSyncTimestampManager.updateLastSyncTime('Payment', DateTime.now());
        } catch (Exception e) {
            System.debug('Error syncing payments: ' + e.getMessage());
            throw e;
        }
    }

    public static void syncNotes(List<Object> clioMatterNotes,Map<String,String> failedRecords, String notesType) {
        try {
            List<Clio_Note__c> notesToUpsert = new List<Clio_Note__c>();
            Set<String> contactClioIds = new Set<String>();
            Set<String> matterClioIds = new Set<String>();
            Map<String,Id> contactIdMap = new Map<String,Id>();
            Map<String,Id> matterIdMap = new Map<String,Id>();

            for (Object obj : clioMatterNotes) {
                Map<String, Object> noteData = (Map<String, Object>) obj;
                if(noteData.get('type')=='Contact'){
                    Map<String, Object> contact = (Map<String, Object>) noteData.get('contact');
                    contactClioIds.add(String.valueOf(contact.get('id')));
                } else if(noteData.get('type')=='Matter'){
                    Map<String, Object> matter = (Map<String, Object>) noteData.get('matter');
                    matterClioIds.add(String.valueOf(matter.get('id')));
                } 
            }

            if(!contactClioIds.isEmpty()){
                for(Contact c : [SELECT Id, Clio_Id__c FROM Contact WHERE Clio_Id__c IN :contactClioIds]){
                    contactIdMap.put(c.Clio_Id__c, c.Id);
                }
            } 
            if(!matterClioIds.isEmpty()){
                for(Matter__c m : [SELECT Id, Clio_Id__c FROM Matter__c WHERE Clio_Id__c IN :matterClioIds]){
                    matterIdMap.put(m.Clio_Id__c, m.Id);
                }
            }

            for (Object obj : clioMatterNotes) {
                Map<String, Object> noteData = (Map<String, Object>) obj;
                Clio_Note__c sfNote = mapClioNoteToSalesforce(noteData, contactIdMap, matterIdMap);
                notesToUpsert.add(sfNote);
            }
            system.debug('Number of notes to upsert: '+notesToUpsert.size());
            if (!notesToUpsert.isEmpty()) {
                system.debug('failedRecords size before dml: '+failedRecords.keySet().size());
                processDMLsync(notesToUpsert, Clio_Note__c.Clio_Id__c, 'upsert',failedRecords);
                system.debug('failedRecords size after dml: '+failedRecords.keySet().size());
            }
                     // Update sync timestamp
            String timeStampName = notesType == 'matter'? 'MatterNotes':'ContactNotes';
            ClioSyncTimestampManager.updateLastSyncTime(timeStampName, DateTime.now());
        } catch (Exception e) {
            System.debug('Error syncing Notes: ' + e.getMessage());
            throw e;
        }
    }

    
    private static Contact mapClioContactToSalesforce(Map<String, Object> clioContact) {
        Contact sfContact = new Contact();
        sfContact.Clio_Id__c = String.valueOf(clioContact.get('id'));

        String firstName = (String) clioContact.get('first_name');
        String lastName = (String) clioContact.get('last_name');
        
        if (String.isNotBlank(firstName)) {
            sfContact.FirstName = firstName.length() > 40 ? firstName.substring(0, 39) : firstName;
        }
        
        if (String.isNotBlank(lastName)) {
            sfContact.LastName = lastName.length() > 80 ? lastName.substring(0, 79) : lastName;
        } else {
            String name = (String) clioContact.get('name');
            sfContact.LastName = name.length() > 80 ? name.substring(0, 79) : name;
        }
        
        sfContact.Title = (String) clioContact.get('title');
        String clioContactEmail = (String) clioContact.get('primary_email_address');
        if(isValidEmail(clioContactEmail)) sfContact.Primary_Email__c = (String) clioContact.get('primary_email_address');
        String primaryClioPhone = (String) clioContact.get('primary_phone_number');
        if(primaryClioPhone != null) sfContact.Primary_Phone__c = primaryClioPhone.length() > 40 ? primaryClioPhone.substring(0, 39) : primaryClioPhone;
        Map<String, Object> company = (Map<String, Object>) clioContact.get('company'); 
        sfContact.Company__c = company != null ? String.valueOf(company.get('id')) : null;
        sfContact.Company_Name__c = company != null ? String.valueOf(company.get('name')) : null;
        
        // Map Clio-specific fields
        sfContact.Clio_Type__c = (String) clioContact.get('type');
        
        // Note: Address fields are ignored as they are not useful for this integration
        
        return sfContact;
    }

    private static MatterContact__c mapClioRelationshipToSalesforce(Map<String, Object> clioRelationship, Map<String,String> sfContactIdsByClioIds, Map<String,String> sfMatterIdsByClioIds) {
        MatterContact__c sfMatterContact = new MatterContact__c();
        sfMatterContact.Clio_Id__c = String.valueOf(clioRelationship.get('id'));
        Map<String, Object> contact = (Map<String, Object>) clioRelationship.get('contact'); 
        String contactClioId = contact != null ? String.valueOf(contact.get('id')) : null;
        if(contactClioId != null) sfMatterContact.Contact__c = sfContactIdsByClioIds.get(contactClioId);
        Map<String, Object> matter = (Map<String, Object>) clioRelationship.get('matter'); 
        String matterClioId = matter != null ? String.valueOf(matter.get('id')) : null;
        if(matterClioId != null) sfMatterContact.Matter__c = sfMatterIdsByClioIds.get(matterClioId);
        
        return sfMatterContact;
    }
    
    private static Matter__c mapClioMatterToSalesforce(Map<String, Object> clioMatter, Map<String, Id> clientIdMap, Map<String, Id> attorneyIdMap) {
        Matter__c sfMatter = new Matter__c();
        sfMatter.Clio_Id__c = String.valueOf(clioMatter.get('id'));
        sfMatter.Name = (String) clioMatter.get('display_number');
        sfMatter.Description__c = (String) clioMatter.get('description');
        sfMatter.Status__c = (String) clioMatter.get('status');
        sfMatter.Location__c = (String) clioMatter.get('location');
        sfMatter.Client_Reference__c = (String) clioMatter.get('client_reference');
        
        if (clioMatter.get('open_date') != null) {
            sfMatter.Open_Date__c = Date.valueOf((String) clioMatter.get('open_date'));
        }
        
        if (clioMatter.get('close_date') != null) {
            sfMatter.Close_Date__c = Date.valueOf((String) clioMatter.get('close_date'));
        }
        
        if (clioMatter.get('pending_date') != null) {
            sfMatter.Pending_Date__c = Date.valueOf((String) clioMatter.get('pending_date'));
        }
        
        Map<String, Object> practiceArea = (Map<String, Object>) clioMatter.get('practice_area');
        if (practiceArea != null) {
            sfMatter.Practice_Area__c = (String) practiceArea.get('name');
        }
        
        Map<String, Object> client = (Map<String, Object>) clioMatter.get('client');
        if (client != null) {
            String clientClioId = String.valueOf(client.get('id'));
            if (clientIdMap.containsKey(clientClioId)) {
                sfMatter.Client__c = clientIdMap.get(clientClioId);
            }
        }

        List<Object> custom_field_values = (List<Object>) clioMatter.get('custom_field_values') != null? (List<Object>) clioMatter.get('custom_field_values') : new List<Object>();
        if(!custom_field_values.isEmpty()){
            system.debug('custom_field_values: '+custom_field_values);
            for(Integer i=0; i<custom_field_values.size(); i++){
                Map<String,Object> custObj = (Map<String, Object>) custom_field_values[i];
                String custObjName = (String) custObj.get('field_name');
                system.debug('custObjName: '+custObjName);
                switch on custObjName{
                    when 'Teams' {
                        if(custObj.get('value') != null){
                            system.debug('custObj.get(\'value\'): '+custObj.get('value'));
                            Map<String,Object> teamPicklistOption = (Map<String, Object>) custObj.get('picklist_option');
                            if(teamPicklistOption.get('option') != null)
                            sfMatter.Team__c = (String) teamPicklistOption.get('option');
                        }
                    }
                    when 'Scope of Work' {
                        if(custObj.get('value') != null){
                            system.debug('custObj.get(\'value\'): '+custObj.get('value'));
                            sfMatter.Scope_of_Work__c = (String) custObj.get('value');
                        }
                    }
                    when 'Matter Notes' {
                        if(custObj.get('value') != null){
                            system.debug('custObj.get(\'value\'): '+custObj.get('value'));
                            sfMatter.Matter_Notes__c = (String) custObj.get('value');
                        }
                    }
                    when 'Flat Rate Amount' {
                        if(custObj.get('value') != null){
                            system.debug('custObj.get(\'value\'): '+custObj.get('value'));
                            sfMatter.Flat_Rate_Amount__c = (Decimal) custObj.get('value');
                        }
                    }
                    when 'Retainer' {
                        if(custObj.get('value') != null){
                            system.debug('custObj.get(\'value\'): '+custObj.get('value'));
                            sfMatter.Retainer__c = (Decimal) custObj.get('value');
                        }
                    }
                    when 'Standard Trust Balance' {
                        if(custObj.get('value') != null){
                            system.debug('custObj.get(\'value\'): '+custObj.get('value'));
                            sfMatter.Standard_Trust_Balance__c = (Decimal) custObj.get('value');
                        }
                    }
                    when 'Supervising Attorney' {
                        if(custObj.get('value') != null){
                            system.debug('custObj.get(\'value\'): '+custObj.get('value'));
                            sfMatter.Supervising_Attorney__c = (String) custObj.get('value');
                        }
                    }
                    when 'Matter Rate' {
                        if(custObj.get('value') != null){
                            system.debug('custObj.get(\'value\'): '+custObj.get('value'));
                            sfMatter.Matter_Rate__c = (String) custObj.get('value');
                        }
                    }
                    when 'Date FA was sent' {
                        if(custObj.get('value') != null){
                            system.debug('custObj.get(\'value\'): '+custObj.get('value'));
                            sfMatter.Date_FA_was_sent__c = Date.valueOf((String) custObj.get('value'));
                        }
                    }
                    when 'Date FA was signed' {
                        if(custObj.get('value') != null){
                            system.debug('custObj.get(\'value\'): '+custObj.get('value'));
                            sfMatter.Date_FA_was_signed__c = Date.valueOf((String) custObj.get('value'));
                        }
                    }
                    when 'Initial Retainer Refunded' {
                        if(custObj.get('value') != null){
                            system.debug('custObj.get(\'value\'): '+custObj.get('value'));
                            sfMatter.Initial_Retained_Refunded__c = Boolean.valueOf(custObj.get('value'));
                        }
                    }
                    when else{
                        system.debug('switch on custObjName: '+custObjName+' not found');
                    }
                }
            }
        }
        
        Map<String, Object> responsibleAttorney = (Map<String, Object>) clioMatter.get('responsible_attorney');
        if (responsibleAttorney != null) {
            String attorneyClioId = String.valueOf(responsibleAttorney.get('id'));
            if (attorneyIdMap.containsKey(attorneyClioId)) {
                sfMatter.Responsible_Attorney__c = attorneyIdMap.get(attorneyClioId);
            }
        }

        
        
        // Map financial fields - billable can be Boolean or Map depending on matter type
        Object billableObj = clioMatter.get('billable');
        if (billableObj instanceof Map<String, Object>) {
            Map<String, Object> billable = (Map<String, Object>) billableObj;
            if (billable.get('rate') != null) {
                sfMatter.Billable_Rate__c = (Decimal) billable.get('rate');
            }
            if (billable.get('flat_rate') != null) {
                sfMatter.Flat_Rate_Amount__c = (Decimal) billable.get('flat_rate');
            }
        }
   
        return sfMatter;
    }
    
    private static Time_Entry__c mapClioTimeEntryToSalesforce(Map<String, Object> clioTimeEntry, Map<String, Id> matterIdMap, Map<String, Id> userIdMap) {
        Time_Entry__c sfTimeEntry = new Time_Entry__c();
        sfTimeEntry.Clio_Id__c = String.valueOf(clioTimeEntry.get('id'));
        sfTimeEntry.Duration__c = ((Decimal) clioTimeEntry.get('quantity')) / 3600.0;
        sfTimeEntry.Rate__c = (Decimal) clioTimeEntry.get('price');
        // sfTimeEntry.Total_Amount__c = (Decimal) clioTimeEntry.get('total'); // Read-only field
        sfTimeEntry.Note__c = (String) clioTimeEntry.get('note');
        sfTimeEntry.Non_Billable__c = (Boolean) clioTimeEntry.get('non_billable');
        sfTimeEntry.Activity_Type__c = (String) clioTimeEntry.get('type');
        
        // Map new fields
        sfTimeEntry.Activity_Description__c = (String) clioTimeEntry.get('description');
        
        if (clioTimeEntry.get('date') != null) {
            sfTimeEntry.Date__c = Date.valueOf((String) clioTimeEntry.get('date'));
        }
        
        // Map created and updated dates
        if (clioTimeEntry.get('created_at') != null) {
            sfTimeEntry.Created_Date__c = DateTime.valueOf(((String) clioTimeEntry.get('created_at')).replace('T', ' ').replace('Z', ''));
        }
        
        if (clioTimeEntry.get('updated_at') != null) {
            sfTimeEntry.Updated_Date__c = DateTime.valueOf(((String) clioTimeEntry.get('updated_at')).replace('T', ' ').replace('Z', ''));
        }
        
        Map<String, Object> matter = (Map<String, Object>) clioTimeEntry.get('matter');
        if (matter != null) {
            String matterClioId = String.valueOf(matter.get('id'));
            if (matterIdMap.containsKey(matterClioId)) {
                sfTimeEntry.Matter__c = matterIdMap.get(matterClioId);
            }
        }
        
        Map<String, Object> user = (Map<String, Object>) clioTimeEntry.get('user');
        if (user != null) {
            sfTimeEntry.User_Name__c = (String) user.get('name');
            String userClioId = String.valueOf(user.get('id'));
            if (userIdMap.containsKey(userClioId)) {
                sfTimeEntry.User__c = userIdMap.get(userClioId);
            }
        }
        
        return sfTimeEntry;
    }
    
    private static Invoice__c mapClioBillToSalesforce(Map<String, Object> clioBill, Map<String, Id> clientIdMap, Map<String, Id> matterIdMap) {
        Invoice__c sfInvoice = new Invoice__c();
        sfInvoice.Clio_Id__c = String.valueOf(clioBill.get('id'));
        sfInvoice.Invoice_Number__c = (String) clioBill.get('number');
        sfInvoice.Subtotal__c = (Decimal) clioBill.get('sub_total');
        sfInvoice.Amount__c = (Decimal) clioBill.get('total');
        sfInvoice.Balance__c = (Decimal) clioBill.get('balance');
        sfInvoice.Status__c = (String) clioBill.get('state');
        sfInvoice.KindOfBill__c = (String) clioBill.get('kind');
        
        if (clioBill.get('issued_at') != null) {
            sfInvoice.Date__c = Date.valueOf(((String) clioBill.get('issued_at')).substring(0, 10));
        }
        
        if (clioBill.get('due_at') != null) {
            sfInvoice.Due_Date__c = Date.valueOf(((String) clioBill.get('due_at')).substring(0, 10));
        }
        List<Object> matters = (List<Object>) clioBill.get('matters'); 
        if(matters != null && !matters.isEmpty()) { 
            Map<String, Object> matter = (Map<String, Object>) matters[0];
            if (matter != null) {
                String matterClioId = String.valueOf(matter.get('id'));
                if (matterIdMap.containsKey(matterClioId)) {
                    sfInvoice.Matter__c = matterIdMap.get(matterClioId);
                }
            }
        }
        
        Map<String, Object> client = (Map<String, Object>) clioBill.get('client');
        if (client != null) {
            String clientClioId = String.valueOf(client.get('id'));
            if (clientIdMap.containsKey(clientClioId)) {
                sfInvoice.Client__c = clientIdMap.get(clientClioId);
            }
        }
        
        return sfInvoice;
    }
    
    private static Calendar_Event__c mapClioCalendarToSalesforce(Map<String, Object> clioCalendar, Map<String, Id> calOwnerIdMap, Map<String, Id> matterIdMap, Map<String,String> clioUserByClioCalendarId) {
        Calendar_Event__c sfEvent = new Calendar_Event__c();
        sfEvent.Clio_Event_ID__c = String.valueOf(clioCalendar.get('id'));
        if(clioCalendar.get('summary') != null){
            String summary = (String) clioCalendar.get('summary');
            sfEvent.Name = summary.length() > 80 ? summary.substring(0, 79) : summary;
        } else {
            sfEvent.Name = String.valueOf(clioCalendar.get('id'));
        }
        sfEvent.Description__c = (String) clioCalendar.get('description');
        sfEvent.Location__c = (String) clioCalendar.get('location');
        
        if (clioCalendar.get('start_at') != null) {
            Datetime startDt = Datetime.valueOf(((String) clioCalendar.get('start_at')).replace('T', ' ').replace('Z', ''));
            sfEvent.Start_Date_Time__c = startDt;
            sfEvent.Start_Date__c = startDt.date();
            sfEvent.Start_Time__c = Time.newInstance(startDt.hour(), startDt.minute(), startDt.second(), 0);
        }
        
        if (clioCalendar.get('end_at') != null) {
            Datetime endDt = Datetime.valueOf(((String) clioCalendar.get('end_at')).replace('T', ' ').replace('Z', ''));
            sfEvent.End_Date_Time__c = endDt;
            sfEvent.End_Date__c = endDt.date();
            sfEvent.End_Time__c = Time.newInstance(endDt.hour(), endDt.minute(), endDt.second(), 0);
        }
        
        Map<String, Object> matter = (Map<String, Object>) clioCalendar.get('matter');
        if (matter != null) {
            String matterClioId = String.valueOf(matter.get('id'));
            if (matterIdMap.containsKey(matterClioId)) {
                sfEvent.Matter__c = matterIdMap.get(matterClioId);
            }
        }
        
        String calClioId = String.valueOf(clioCalendar.get('calendar_owner_id'));
        if(clioUserByClioCalendarId.containsKey(calClioId)){
            String clioUserId = clioUserByClioCalendarId.get(calClioId);
            if (calOwnerIdMap.containsKey(clioUserId)) {
                sfEvent.Assigned_To__c = calOwnerIdMap.get(clioUserId);
            }

        }
        
        return sfEvent;
    }
    
    private static Payment__c mapClioPaymentToSalesforce(Map<String, Object> clioPayment, Map<String, Id> matterIdMap, Map<String, Id> billIdMap, Map<String, Id> clientIdMap) {
        Payment__c sfPayment = new Payment__c();
        sfPayment.Clio_Id__c = String.valueOf(clioPayment.get('id'));
        sfPayment.Source__c = String.valueOf(clioPayment.get('source'));
        sfPayment.Amount__c = (Decimal) clioPayment.get('amount');
        sfPayment.Notes__c = (String) clioPayment.get('description');
        
        if (clioPayment.get('date') != null) {
            sfPayment.Date__c = Date.valueOf((String) clioPayment.get('date'));
        }
        
        Map<String, Object> matter = (Map<String, Object>) clioPayment.get('matter');
        if (matter != null) {
            String matterClioId = String.valueOf(matter.get('id'));
            if (matterIdMap.containsKey(matterClioId)) {
                sfPayment.Matter__c = matterIdMap.get(matterClioId);
            }
        }

        Map<String, Object> bill = (Map<String, Object>) clioPayment.get('bill');
        if (bill != null) {
            String billClioId = String.valueOf(bill.get('id'));
            if (billIdMap.containsKey(billClioId)) {
                sfPayment.Invoice__c = billIdMap.get(billClioId);
            }
        }

        Map<String, Object> client = (Map<String, Object>) clioPayment.get('client');
        if (client != null) {
            String clientClioId = String.valueOf(client.get('id'));
            if (clientIdMap.containsKey(clientClioId)) {
                sfPayment.Contact__c = clientIdMap.get(clientClioId);
            }
        }
        return sfPayment;
    }

    private static Clio_Note__c mapClioNoteToSalesforce(Map<String, Object> noteData, Map<String,Id> contactIdMap, Map<String,Id> matterIdMap) {
        Clio_Note__c sfNote = new Clio_Note__c();
        sfNote.Clio_Id__c = String.valueOf(noteData.get('id'));
        sfNote.Subject__c = String.valueOf(noteData.get('subject'));
        sfNote.Detail__c = String.valueOf(noteData.get('detail'));
        if (noteData.get('date') != null) {
            sfNote.Date__c = Date.valueOf((String) noteData.get('date'));
        }
        sfNote.Type__c = String.valueOf(noteData.get('type'));
        sfNote.Name = sfNote.Subject__c == null? sfNote.Clio_Id__c : sfNote.Subject__c.length() < 91 ? sfNote.Subject__c : sfNote.Subject__c.substring(0,90);
        Map<String, Object> matter = (Map<String, Object>) noteData.get('matter');
        if (matter != null) {
            String matterClioId = String.valueOf(matter.get('id'));
            if (matterIdMap.containsKey(matterClioId)) {
                sfNote.Matter__c = matterIdMap.get(matterClioId);
            }
        }
        Map<String, Object> contact = (Map<String, Object>) noteData.get('contact');
        if (contact != null) {
            String contactClioId = String.valueOf(contact.get('id'));
            if (contactIdMap.containsKey(contactClioId)) {
                sfNote.Contact__c = contactIdMap.get(contactClioId);
            }
        }
        
        return sfNote;
    }

    public static void processDMLsync(List<SObject> objectsList, Schema.SObjectField externalId, String dmlOperation,Map<String,String> failedRecords){
        List<Database.SaveResult> srList = new List<Database.SaveResult>();
        List<Database.UpsertResult> urList = new List<Database.UpsertResult>();
        system.debug('Number of records sent to the DML in the batch: '+objectsList.size());
        Integer numOfFailures = 0;
        switch on dmlOperation{
            when 'insert' {
                srList = Database.insert(objectsList, false);
            }
            when 'update' {
                srList = Database.update(objectsList, false);
            }
            when 'upsert' {
                urList = Database.upsert(objectsList, externalId, false);
            } 
        }
        String extIdField = '';
        if(externalId != null) extIdField = externalId.getDescribe().getName();

        if(srList.size() > 0){
            for (Integer i=0;i<srList.size();i++) {
                if (!srList[i].isSuccess()) {
                    numOfFailures++;
                    String recordId = srList[i].getId() == null? String.valueOf(objectsList[i].get(extIdField)): String.valueOf(srList[i].getId());
                    for (Database.Error err : srList[i].getErrors()) {
                        failedRecords.put(recordId, err.getMessage());
                        system.debug('failed record id: '+recordId+' error message: '+err.getMessage());
                    }
                }
            }
        }

        if(urList.size() > 0){
            for (Integer i=0;i<urList.size();i++) {
                if (!urList[i].isSuccess()) {
                    numOfFailures++;
                    String recordId = urList[i].getId() == null? String.valueOf(objectsList[i].get(extIdField)): String.valueOf(urList[i].getId());
                    for (Database.Error err : urList[i].getErrors()) {
                        failedRecords.put(recordId, err.getMessage());
                        system.debug('failed record id: '+recordId+' error message: '+err.getMessage());
                    }
                }
            }
        }

        system.debug('Number of records failed in the batch DML: '+numOfFailures);
    }

    private String generateFailedRecordDetails(){
        String details = '';
        for(String recordId : failedRecords.keySet()){
            details += 'Record ID: ' + recordId + '; Error: ' + failedRecords.get(recordId) + '\n';
        }
        return details;
    }

    public static Boolean isValidEmail(String email) {
        if (String.isBlank(email)) {
            return false; // Handle null or empty strings
        }

        // A common regex pattern for email validation.
        // Regex source: http://www.regular-expressions.info/email.html
        String emailRegex = '^[a-zA-Z0-9._|\\\\%⌗~`=?&/$^*!}{+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,4}$';
        
        Pattern emailPattern = Pattern.compile(emailRegex);
        Matcher emailMatcher = emailPattern.matcher(email);

        return emailMatcher.matches();
    }
}