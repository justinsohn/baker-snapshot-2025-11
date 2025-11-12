public with sharing class ClioSyncService {
    
    public static void syncUsers(String lastSyncTime) {
        try {
            Map<String, String> params = new Map<String, String>();
            if (String.isNotBlank(lastSyncTime)) {
                params.put('updated_since', lastSyncTime);
            }
            params.put('fields', 'id,name,first_name,last_name,email,enabled,updated_at');
            
            List<Object> clioUsers = ClioIntegrationService.getAllRecords('/users', params);
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
            
            Set<String> existingUserEmails = new Set<String>();
            for(User u : existingUsers) {
                // CHANGED: Remove the '.invalid' suffix before adding the email to the set.
                // This normalizes the email for a direct comparison with Clio data.
                existingUserEmails.add(u.Email.removeEnd('.invalid').toLowerCase());
            }

            for (Object obj : clioUsers) {
                Map<String, Object> userData = (Map<String, Object>) obj;
                String email = (String) userData.get('email');
                // This check for new users now works correctly against the normalized email set.
                if (String.isNotBlank(email) && !existingUserEmails.contains(email.toLowerCase())) {
                    usersToCreate.add(new User(
                        FirstName = (String)userData.get('first_name'),
                        LastName = (String)userData.get('last_name'),
                        Email = email,
                        Username = email,
                        Alias = ((String)userData.get('first_name')).substring(0,1) + ((String)userData.get('last_name')).substring(0,4),
                        CommunityNickname = (String)userData.get('name'),
                        TimeZoneSidKey = 'America/Los_Angeles',
                        LocaleSidKey = 'en_US',
                        EmailEncodingKey = 'UTF-8',
                        ProfileId = '00e5f000001gYziAAE', // Standard User Profile ID - may need to be adjusted
                        LanguageLocaleKey = 'en_US',
                        Clio_Id__c = String.valueOf(userData.get('id'))
                    ));
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
            
            if (!usersToCreate.isEmpty()) {
                // insert usersToCreate;
            }

            if (!usersToUpdate.isEmpty()) {
                update usersToUpdate;
            }
            
            // Update sync timestamp
            ClioSyncTimestampManager.updateLastSyncTime('User', DateTime.now());
        } catch (Exception e) {
            System.debug('Error syncing users: ' + e.getMessage());
            throw e;
        }
    }
    
    public static void syncContacts(String lastSyncTime) {
        try {
            Map<String, String> params = new Map<String, String>();
            if (String.isNotBlank(lastSyncTime)) {
                params.put('updated_since', lastSyncTime);
            }
            params.put('fields', 'id,name,type,first_name,last_name,title,company,primary_email_address,primary_phone_number,created_at,updated_at');
            
            List<Object> clioContacts = ClioIntegrationService.getAllRecords('/contacts', params);
            List<Contact> contactsToUpsert = new List<Contact>();
            
            for (Object obj : clioContacts) {
                Map<String, Object> contactData = (Map<String, Object>) obj;
                Contact sfContact = mapClioContactToSalesforce(contactData);
                contactsToUpsert.add(sfContact);
            }
            
            if (!contactsToUpsert.isEmpty()) {
                List<Database.UpsertResult> urList = Database.upsert(contactsToUpsert, Contact.Clio_Id__c, false);
                for (Database.UpsertResult ur : urList) {
                    if (!ur.isSuccess()) {               
                        for(Database.Error err : ur.getErrors()) {
                            System.debug('The following Contact failed to upsert: '+ ur.getId());
                            System.debug('The following error has occurred: '+err.getStatusCode() + ': ' + err.getMessage());
                            System.debug('Contact fields that affected this error: ' + err.getFields());
                        }
                    }
                }
            }
            
            // Update sync timestamp
            ClioSyncTimestampManager.updateLastSyncTime('Contact', DateTime.now());
        } catch (Exception e) {
            System.debug('Error syncing contacts: ' + e.getMessage());
            throw e;
        }
    }
    
    public static void syncMatters(String lastSyncTime) {
        try {
            Map<String, String> params = new Map<String, String>();
            if (String.isNotBlank(lastSyncTime)) {
                params.put('updated_since', lastSyncTime);
            }
            params.put('fields', 'id,display_number,description,status,location,client{id,name},client_reference,responsible_attorney{id,name},open_date,close_date,pending_date,practice_area{name},billable,updated_at');
            
            List<Object> clioMatters = ClioIntegrationService.getAllRecords('/matters', params);
            List<Matter__c> mattersToUpsert = new List<Matter__c>();
            
            // Collect all client and attorney Clio IDs for bulk queries
            Set<String> clientClioIds = new Set<String>();
            Set<String> attorneyClioIds = new Set<String>();
            
            for (Object obj : clioMatters) {
                Map<String, Object> matterData = (Map<String, Object>) obj;
                Map<String, Object> client = (Map<String, Object>) matterData.get('client');
                Map<String, Object> responsibleAttorney = (Map<String, Object>) matterData.get('responsible_attorney');
                
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
            
            if (!mattersToUpsert.isEmpty()) {
                try {
                    List<Database.UpsertResult> urList = Database.upsert(mattersToUpsert, Matter__c.Clio_Id__c, false);
                    for (Database.UpsertResult ur : urList) {
                        if (!ur.isSuccess()) {               
                            for(Database.Error err : ur.getErrors()) {
                                System.debug('The following matter failed to upsert: '+ ur.getId());
                                System.debug('The following error has occurred: '+err.getStatusCode() + ': ' + err.getMessage());
                                System.debug('Matter fields that affected this error: ' + err.getFields());
                            }
                        }
                    }
                } catch (Exception upsertEx) {
                    System.debug('Custom fields not deployed yet for upsert: ' + upsertEx.getMessage());
                    insert mattersToUpsert; // Use regular insert if external ID field not available
                }
            }
            
            // Update sync timestamp
            ClioSyncTimestampManager.updateLastSyncTime('Matter', DateTime.now());
        } catch (Exception e) {
            System.debug('Error syncing matters: ' + e.getMessage());
            throw e;
        }
    }
    
    public static void syncTimeEntries(String lastSyncTime) {
        try {
            Map<String, String> params = new Map<String, String>();
            if (String.isNotBlank(lastSyncTime)) {
                params.put('updated_since', lastSyncTime);
            }
            params.put('type', 'TimeEntry');
            params.put('fields', 'id,quantity,price,total,note,date,matter{id,display_number},user{id,name},non_billable,type,created_at,updated_at');
            
            List<Object> clioTimeEntries = ClioIntegrationService.getAllRecords('/activities', params);
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
            
            if (!timeEntriesToUpsert.isEmpty()) {
                try {
                    List<Database.UpsertResult> urList = Database.upsert(timeEntriesToUpsert, Time_Entry__c.Clio_Id__c, false);
                    for (Database.UpsertResult ur : urList) {
                        if (!ur.isSuccess()) {               
                            for(Database.Error err : ur.getErrors()) {
                                System.debug('The following timeEntry failed to upsert: '+ ur.getId());
                                System.debug('The following error has occurred: '+err.getStatusCode() + ': ' + err.getMessage());
                                System.debug('TimeEntry fields that affected this error: ' + err.getFields());
                            }
                        }
                    }
                } catch (Exception upsertEx) {
                    System.debug('Custom fields not deployed yet for upsert: ' + upsertEx.getMessage());
                    insert timeEntriesToUpsert; // Use regular insert if external ID field not available
                }
            }
            
            // Update sync timestamp
            ClioSyncTimestampManager.updateLastSyncTime('TimeEntry', DateTime.now());
        } catch (Exception e) {
            System.debug('Error syncing time entries: ' + e.getMessage());
            throw e;
        }
    }
    
    public static void syncBills(String lastSyncTime) {
        try {
            Map<String, String> params = new Map<String, String>();
            if (String.isNotBlank(lastSyncTime)) {
                params.put('updated_since', lastSyncTime);
            }
            params.put('fields', 'id,number,issued_at,due_at,sub_total,total,balance,state,client{id,name},matters{id,display_number},updated_at');
            
            List<Object> clioBills = ClioIntegrationService.getAllRecords('/bills', params);
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
            
            if (!invoicesToUpsert.isEmpty()) {
                try {
                    List<Database.UpsertResult> urList = Database.upsert(invoicesToUpsert, Invoice__c.Clio_Id__c, false);
                    for (Database.UpsertResult ur : urList) {
                        if (!ur.isSuccess()) {               
                            for(Database.Error err : ur.getErrors()) {
                                System.debug('The following Invoice failed to upsert: '+ ur.getId());
                                System.debug('The following error has occurred: '+err.getStatusCode() + ': ' + err.getMessage());
                                System.debug('Invoice fields that affected this error: ' + err.getFields());
                            }
                        }
                    }
                } catch (Exception upsertEx) {
                    System.debug('Custom fields not deployed yet for upsert: ' + upsertEx.getMessage());
                    insert invoicesToUpsert; // Use regular insert if external ID field not available
                }
            }
            
            // Update sync timestamp
            ClioSyncTimestampManager.updateLastSyncTime('Bill', DateTime.now());
        } catch (Exception e) {
            System.debug('Error syncing bills: ' + e.getMessage());
            throw e;
        }
    }
    
    public static void syncCalendarEntries(String lastSyncTime) {
        try {
            Map<String, String> params = new Map<String, String>();
            if (String.isNotBlank(lastSyncTime)) {
                params.put('updated_since', lastSyncTime);
            }
            params.put('fields', 'id,summary,description,start_at,end_at,location,matter{id,display_number},calendar_owner{id},attendees,updated_at');
            
            List<Object> clioCalendarEntries = ClioIntegrationService.getAllRecords('/calendar_entries', params);
            List<Calendar_Event__c> eventsToUpsert = new List<Calendar_Event__c>();
            
            // Collect all matter and calendar owner Clio IDs for bulk queries
            Set<String> matterClioIds = new Set<String>();
            Set<String> calOwnerClioIds = new Set<String>();
            
            for (Object obj : clioCalendarEntries) {
                Map<String, Object> eventData = (Map<String, Object>) obj;
                Map<String, Object> matter = (Map<String, Object>) eventData.get('matter');
                Map<String, Object> calOwner = (Map<String, Object>) eventData.get('calendar_owner');
                
                if (matter != null) {
                    matterClioIds.add(String.valueOf(matter.get('id')));
                }
                if (calOwner != null) {
                    calOwnerClioIds.add(String.valueOf(calOwner.get('id')));
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
                Calendar_Event__c sfEvent = mapClioCalendarToSalesforce(eventData, calOwnerIdMap, matterIdMap);
                eventsToUpsert.add(sfEvent);
            }
            
            if (!eventsToUpsert.isEmpty()) {
                try {
                    List<Database.UpsertResult> urList = Database.upsert(eventsToUpsert, Calendar_Event__c.Clio_Event_ID__c, false);
                    for (Database.UpsertResult ur : urList) {
                        if (!ur.isSuccess()) {               
                            for(Database.Error err : ur.getErrors()) {
                                System.debug('The following Event failed to upsert: '+ ur.getId());
                                System.debug('The following error has occurred: '+err.getStatusCode() + ': ' + err.getMessage());
                                System.debug('Event fields that affected this error: ' + err.getFields());
                            }
                        }
                    }
                } catch (Exception upsertEx) {
                    System.debug('Custom fields not deployed yet for upsert: ' + upsertEx.getMessage());
                    insert eventsToUpsert; // Use regular insert if external ID field not available
                }
            }
            
            // Update sync timestamp
            ClioSyncTimestampManager.updateLastSyncTime('Calendar', DateTime.now());
        } catch (Exception e) {
            System.debug('Error syncing calendar entries: ' + e.getMessage());
            throw e;
        }
    }
    
    public static void syncPayments(String lastSyncTime) {
        try {
            Map<String, String> params = new Map<String, String>();
            if (String.isNotBlank(lastSyncTime)) {
                params.put('updated_since', lastSyncTime);
            }
            params.put('fields', 'id,type,date,amount,description,client{id,name},matter{id,display_number},bill{id,number},allocation,updated_at');
            
            List<Object> clioPayments = ClioIntegrationService.getAllRecords('/bank_transactions', params);
            List<Payment__c> paymentsToUpsert = new List<Payment__c>();
            
            // Collect all matter and bill Clio IDs for bulk queries from payments only
            Set<String> matterClioIds = new Set<String>();
            Set<String> billClioIds = new Set<String>();
            
            for (Object obj : clioPayments) {
                Map<String, Object> paymentData = (Map<String, Object>) obj;                
                Map<String, Object> matter = (Map<String, Object>) paymentData.get('matter');
                Map<String, Object> bill = (Map<String, Object>) paymentData.get('bill');
                if (matter != null) {
                    matterClioIds.add(String.valueOf(matter.get('id')));
                }
                if (bill != null) {
                    billClioIds.add(String.valueOf(bill.get('id')));
                }
            }
            
            // Bulk query for matters and bills
            Map<String, Id> matterIdMap = new Map<String, Id>();
            Map<String, Id> billIdMap = new Map<String, Id>();
            
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
            } catch (Exception queryEx) {
                System.debug('Custom fields not deployed yet: ' + queryEx.getMessage());
            }
            
            for (Object obj : clioPayments) {
                Map<String, Object> paymentData = (Map<String, Object>) obj;
                //if (paymentData.get('type') == 'Payment') {
                    Payment__c sfPayment = mapClioPaymentToSalesforce(paymentData, matterIdMap, billIdMap);
                    paymentsToUpsert.add(sfPayment);
                //}
            }
            
            if (!paymentsToUpsert.isEmpty()) {
                try {
                    List<Database.UpsertResult> urList = Database.upsert(paymentsToUpsert, Payment__c.Clio_Id__c, false);
                    for (Database.UpsertResult ur : urList) {
                        if (!ur.isSuccess()) {               
                            for(Database.Error err : ur.getErrors()) {
                                System.debug('The following Payment failed to upsert: '+ ur.getId());
                                System.debug('The following error has occurred: '+err.getStatusCode() + ': ' + err.getMessage());
                                System.debug('Payment fields that affected this error: ' + err.getFields());
                            }
                        }
                    }
                } catch (Exception upsertEx) {
                    System.debug('Custom fields not deployed yet for upsert: ' + upsertEx.getMessage());
                    insert paymentsToUpsert; // Use regular insert if external ID field not available
                }
            }
            
            // Update sync timestamp
            ClioSyncTimestampManager.updateLastSyncTime('Payment', DateTime.now());
        } catch (Exception e) {
            System.debug('Error syncing payments: ' + e.getMessage());
            throw e;
        }
    }
    
    private static Contact mapClioContactToSalesforce(Map<String, Object> clioContact) {
        Contact sfContact = new Contact();
        sfContact.Clio_Id__c = String.valueOf(clioContact.get('id'));
        
        String firstName = (String) clioContact.get('first_name');
        String lastName = (String) clioContact.get('last_name');
        
        if (String.isNotBlank(firstName)) {
            sfContact.FirstName = firstName;
        }
        
        if (String.isNotBlank(lastName)) {
            sfContact.LastName = lastName;
        } else {
            sfContact.LastName = (String) clioContact.get('name');
        }
        
        sfContact.Title = (String) clioContact.get('title');
        sfContact.Primary_Email__c = (String) clioContact.get('primary_email_address');
        sfContact.Primary_Phone__c = (String) clioContact.get('primary_phone_number');
        Map<String, Object> company = (Map<String, Object>) clioContact.get('company'); 
        sfContact.Company__c = company != null ? String.valueOf(company.get('id')) : null;
        sfContact.Company_Name__c = company != null ? String.valueOf(company.get('name')) : null;
        
        // Map Clio-specific fields
        sfContact.Clio_Type__c = (String) clioContact.get('type');
        
        // Note: Address fields are ignored as they are not useful for this integration
        
        return sfContact;
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
        
        // Note: Financial data fetching is optional and rate-limited to avoid API quota issues
        // Only fetch financial data if we haven't made too many callouts already
        if (Limits.getCallouts() < (Limits.getLimitCallouts() * 0.8)) { // Use max 80% of callout limit
            try {
                Map<String, Decimal> financialData = getMatterFinancialData(String.valueOf(clioMatter.get('id')));
                if (financialData != null) {
                    sfMatter.Work_In_Progress__c = financialData.get('work_in_progress');
                    sfMatter.Outstanding_Balance__c = financialData.get('outstanding_balance');
                    sfMatter.Trust_Balance__c = financialData.get('trust_balance');
                }
            } catch (Exception financialEx) {
                System.debug('Failed to fetch financial data for matter ' + clioMatter.get('id') + ': ' + financialEx.getMessage());
                // Continue without financial data rather than failing the entire sync
            }
        }
        
        return sfMatter;
    }
    
    // Helper method to fetch financial data for a specific matter from bills and bank transactions
    private static Map<String, Decimal> getMatterFinancialData(String matterId) {
        if (String.isBlank(matterId)) {
            return null;
        }
        
        Map<String, Decimal> financialData = new Map<String, Decimal>{
            'work_in_progress' => 0.0,
            'outstanding_balance' => 0.0,
            'trust_balance' => 0.0
        };
        
        try {
            // Fetch bills for this matter
            Map<String, String> billParams = new Map<String, String>{
                'matter_id' => matterId,
                'fields' => 'id,total,balance,state'
            };
            
            List<Object> bills = ClioIntegrationService.getAllRecords('/bills', billParams);
            
            // Aggregate outstanding balance from unpaid bills
            for (Object billObj : bills) {
                Map<String, Object> bill = (Map<String, Object>) billObj;
                String state = (String) bill.get('state');
                if (state == 'sent' || state == 'overdue') { // Unpaid bills
                    Decimal balance = (Decimal) bill.get('balance');
                    if (balance != null) {
                        financialData.put('outstanding_balance', financialData.get('outstanding_balance') + balance);
                    }
                }
            }
            
            // Fetch bank transactions for this matter to get trust balance and WIP
            Map<String, String> transactionParams = new Map<String, String>{
                'matter_id' => matterId,
                'fields' => 'id,type,amount'
            };
            
            List<Object> transactions = ClioIntegrationService.getAllRecords('/bank_transactions', transactionParams);
            
            // Process transactions to calculate trust balance and work in progress
            for (Object transObj : transactions) {
                Map<String, Object> transactionData = (Map<String, Object>) transObj;
                String type = (String) transactionData.get('type');
                Decimal amount = (Decimal) transactionData.get('amount');
                
                if (amount != null) {
                    if (type == 'TrustDeposit' || type == 'TrustTransfer') {
                        financialData.put('trust_balance', financialData.get('trust_balance') + amount);
                    } else if (type == 'TrustWithdrawal') {
                        financialData.put('trust_balance', financialData.get('trust_balance') - amount);
                    } else if (type == 'TimeEntry' || type == 'ExpenseEntry') {
                        // Work in progress - unbilled time and expenses
                        financialData.put('work_in_progress', financialData.get('work_in_progress') + amount);
                    }
                }
            }
            
            return financialData;
            
        } catch (Exception e) {
            System.debug('Error fetching financial data for matter ' + matterId + ': ' + e.getMessage());
            return null;
        }
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
        System.debug(clioBill.get('updated_at'));
        
        if (clioBill.get('issued_at') != null) {
            sfInvoice.Date__c = Date.valueOf(((String) clioBill.get('issued_at')).substring(0, 10));
        }
        
        if (clioBill.get('due_at') != null) {
            sfInvoice.Due_Date__c = Date.valueOf(((String) clioBill.get('due_at')).substring(0, 10));
        }
        
        Map<String, Object> matter = (Map<String, Object>) clioBill.get('matter');
        if (matter != null) {
            String matterClioId = String.valueOf(matter.get('id'));
            if (matterIdMap.containsKey(matterClioId)) {
                sfInvoice.Matter__c = matterIdMap.get(matterClioId);
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
    
    private static Calendar_Event__c mapClioCalendarToSalesforce(Map<String, Object> clioCalendar, Map<String, Id> calOwnerIdMap, Map<String, Id> matterIdMap) {
        Calendar_Event__c sfEvent = new Calendar_Event__c();
        sfEvent.Clio_Event_ID__c = String.valueOf(clioCalendar.get('id'));
        sfEvent.Name = (String) clioCalendar.get('summary');
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

        Map<String, Object> calOwner = (Map<String, Object>) clioCalendar.get('calendar_owner');
        if (calOwner != null) {
            String calOwnerClioId = String.valueOf(calOwner.get('id'));
            if (calOwnerIdMap.containsKey(calOwnerClioId)) {
                sfEvent.Assigned_To__c = calOwnerIdMap.get(calOwnerClioId);
            }
        }
        
        return sfEvent;
    }
    
    private static Payment__c mapClioPaymentToSalesforce(Map<String, Object> clioPayment, Map<String, Id> matterIdMap, Map<String, Id> billIdMap) {
        Payment__c sfPayment = new Payment__c();
        sfPayment.Clio_Id__c = String.valueOf(clioPayment.get('id'));
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
        return sfPayment;
    }
}