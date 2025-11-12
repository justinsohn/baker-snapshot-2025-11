@isTest
public with sharing class ClioIntServiceQueueableTest {
    @isTest
    static void testNextLink() {
        // Create mock data and callouts
        Test.setMock(HttpCalloutMock.class, new ClioIntServiceQueueableMock());
        // Call the method to test
        Map<String, String> params = new Map<String, String>();
        params.put('fields', 'id,name,first_name,last_name,email,enabled,updated_at');             
        Test.startTest();
        System.enqueueJob(new ClioIntegrationServiceQueueable('/final', params, null));
        Test.stopTest();

        // Assertions
        // This class doesn't return any values, if the test doesn't fail, then the test succeeds;
    }

    @isTest
    static void testSyncUsers() {
        
        // Create a user to update
        List<User> users = new List<User>();
        users.add(new User(
            FirstName = 'Test',
            LastName = 'User1',
            Email = 'testUser1@testUser.com',
            Username = 'testUser1@testUser.com' + System.currentTimeMillis(),
            Alias = 'tuser1',
            CommunityNickname = 'Test User1',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1].Id,
            LanguageLocaleKey = 'en_US'
        ));
        users.add(new User(
            FirstName = 'Test',
            LastName = 'User2',
            Email = 'testUser2@testUser.com',
            Username = 'testUser2@testUser.com' + System.currentTimeMillis(),
            Alias = 'tuser2',
            CommunityNickname = 'Test User2',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1].Id,
            LanguageLocaleKey = 'en_US'
        ));
        insert users;

        List<User> adminUsr = [Select Id from User where profile.Name = 'System Administrator' and isActive = True];
        
        System.runAs(adminUsr[0]) {
            // Create callouts mock response
            Test.setMock(HttpCalloutMock.class, new ClioIntServiceQueueableMock());
            // Call the method to test
            Map<String, String> params = new Map<String, String>();
            params.put('fields', 'id,name,first_name,last_name,email,enabled,updated_at');             
            Test.startTest();
            // Enqueue job
            System.enqueueJob(new ClioIntegrationServiceQueueable('/users', params, null));
            Test.stopTest();

            // Assertions
            users = [SELECT Id, FirstName, LastName, Email, Clio_Id__c FROM User where email in ('testUser1@testUser.com', 'testUser2@testUser.com')];
            for(User usr : users){
                if(usr.Email == 'testUser1@testUser.com'){
                    System.AssertEquals('111111111',usr.Clio_Id__c);
                } else if(usr.Email == 'testUser2@testUser.com'){
                    System.AssertEquals('222222222',usr.Clio_Id__c);
                }
            }
        }
    }

    @isTest
    static void testSyncContacts() {
        // Create mock data and callouts
        Test.setMock(HttpCalloutMock.class, new ClioIntServiceQueueableMock());
        List<Contact> contacts = new List<Contact>();
        contacts.add(new Contact(
            Clio_Id__c = '123456',
            FirstName = 'Test',
            LastName = 'Contact1',
            Title = null,
            Primary_Email__c = 'contact1@testemail.com',
            Primary_Phone__c = '305-111111',
            Company__c = null,
            Company_Name__c = null,
            Clio_Type__c = 'Person'
        ));
        contacts.add(new Contact(
            Clio_Id__c = '234567',
            FirstName = 'Test',
            LastName = 'Contact2',
            Title = null,
            Primary_Email__c = 'contact2@testemail.com',
            Primary_Phone__c = '305-222222',
            Company__c = null,
            Company_Name__c = null,
            Clio_Type__c = 'Person'
        ));
        insert contacts;


        // Call the method to test
        Map<String, String> params = new Map<String, String>();
        params.put('fields', 'id,name,type,first_name,last_name,title,company,primary_email_address,primary_phone_number,created_at,updated_at');           
        Test.startTest();
        System.enqueueJob(new ClioIntegrationServiceQueueable('/contacts', params, null));
        Test.stopTest();

        // Assertions
        List<Contact> finalContacts = [Select Id, Clio_Id__c, FirstName, LastName, Primary_Email__c, Primary_Phone__c, Clio_Type__c from Contact];
        System.AssertEquals(3, finalContacts.size());
        for(Contact contct : finalContacts){
            if(contct.Clio_Id__c == '123456'){
                System.AssertEquals('Finster', contct.LastName);
            } else if(contct.Clio_Id__c == '012345'){
                System.AssertEquals('Clio Migration', contct.LastName);
                System.AssertEquals('Company', contct.Clio_Type__c);
            }
        }
    }

    @isTest
    static void testSyncMatters() {
        // Create mock data and callouts
        Test.setMock(HttpCalloutMock.class, new ClioIntServiceQueueableMock());
        Contact contact = new Contact(
            Clio_Id__c = '2233682903',
            FirstName = 'Test',
            LastName = 'Contact2',
            Title = null,
            Primary_Email__c = 'contact2@testemail.com',
            Primary_Phone__c = '305-222222',
            Company__c = null,
            Company_Name__c = null,
            Clio_Type__c = 'Person'
        );
        insert contact;
        List<Matter__c> matters = new List<Matter__c>();
        /*matters.add( new Matter__c(
            Clio_Id__c = '1699370198',
            Name = '00001- Chuckie  Finster',
            Description__c = 'Probate dispute',
            Status__c = 'Open',
            Location__c = null,
            Client_Reference__c = null,
            Open_Date__c = Date.valueOf('2025-04-30'),
            Close_Date__c = null,
            Pending_Date__c = null,
            Practice_Area__c = 'Wills Estates',
            Client__c = '2223324743',
            Responsible_Attorney__c = null
        ));*/

        matters.add( new Matter__c(
            Clio_Id__c = '1710586898',
            Name = '02199-   Clio Migration',
            Description__c = 'TEAM TYLER. Dummy matters are temporary placeholders used to track time, tasks, and events for all work performed on cases that originated before June 26. These will later be matched to real matters once the data import is complete July 7th.',
            Status__c = 'Open',
            Location__c = null,
            Client_Reference__c = null,
            Open_Date__c = Date.valueOf('2025-06-26'),
            Close_Date__c = null,
            Pending_Date__c = null,
            Practice_Area__c = null,
            Client__c = null,
            Responsible_Attorney__c = null //358277663
        ));

        // Call the method to test
        Map<String, String> params = new Map<String, String>();
        params.put('fields', 'id,display_number,description,status,location,client{id,name},client_reference,responsible_attorney{id,name},open_date,close_date,pending_date,practice_area{name},billable,updated_at');          
        Test.startTest();
        System.enqueueJob(new ClioIntegrationServiceQueueable('/matters', params, null));
        Test.stopTest();

        // Assertions
        List<User> reponsibleAttorney = [Select Id from User Where Clio_Id__c = '358277663' LIMIT 1];
        if(!reponsibleAttorney.isEmpty()){
            List<Matter__c> matter1 = [Select Id, Responsible_Attorney__c, Client__c from Matter__c Where Clio_Id__c = '1710586898' LIMIT 1];
            if(!matter1.isEmpty()){
                System.assertEquals(reponsibleAttorney[0].Id, matter1[0].Responsible_Attorney__c);
                System.assertEquals(contact.Id, matter1[0].Client__c);
            }
        }
        List<Matter__c> finalMatters = [Select Id, Clio_Id__c, Name, Description__c, Status__c, Location__c, Client_Reference__c, Open_Date__c, Close_Date__c, Pending_Date__c, Practice_Area__c, Client__c, Responsible_Attorney__c FROM Matter__c];

        System.AssertEquals(2, finalMatters.size());
        for(Matter__c matter : finalMatters){
            if(matter.Clio_Id__c == '1699370198'){
                System.AssertEquals('00001- Chuckie  Finster', matter.Name);
                System.AssertEquals('Probate dispute', matter.Description__c);
            }
        }
    }

    @isTest
    static void testSyncActivities() {
        // Create mock data and callouts
        Test.setMock(HttpCalloutMock.class, new ClioIntServiceQueueableMock());
        // Call the method to test
        Map<String, String> params = new Map<String, String>();
        params.put('type', 'TimeEntry');
        params.put('fields', 'id,quantity,price,total,note,date,matter{id,display_number},user{id,name},non_billable,type,created_at,updated_at');           
        Test.startTest();
        System.enqueueJob(new ClioIntegrationServiceQueueable('/activities', params, null));
        Test.stopTest();

        // Assertions
        List<Time_Entry__c> timeEntries = [SELECT Id, Clio_Id__c from Time_Entry__c];
        System.AssertEquals(2, timeEntries.size());
    }

    @isTest
    static void testSyncBills() {
        // Create mock data and callouts
        Test.setMock(HttpCalloutMock.class, new ClioIntServiceQueueableMock());
        // Call the method to test
        Map<String, String> params = new Map<String, String>();
        params.put('fields', 'id,number,issued_at,due_at,sub_total,total,balance,state,client{id,name},matters{id,display_number},updated_at');           
        Test.startTest();
        System.enqueueJob(new ClioIntegrationServiceQueueable('/bills', params, null));
        Test.stopTest();

        // Assertions
        List<Invoice__c> invoices = [Select Id from Invoice__c];
        System.assertEquals(3, invoices.size());
    }

    @isTest
    static void testSyncCalendarEntries() {
        // Create mock data and callouts
        Test.setMock(HttpCalloutMock.class, new ClioIntServiceQueueableMock());
        // Call the method to test
        Map<String, String> params = new Map<String, String>();
        params.put('fields', 'id,summary,description,start_at,end_at,location,matter{id,display_number},calendar_owner_id,attendees,updated_at');           
        Test.startTest();
        System.enqueueJob(new ClioIntegrationServiceQueueable('/calendar_entries', params, null));
        Test.stopTest();

        // Assertions
        List<Calendar_Event__c> calendarEventsToUpsert = [Select Id from Calendar_Event__c];
        System.AssertEquals(1, calendarEventsToUpsert.size());
    }

    @isTest
    static void testSyncBankTransactions() {
        // Create mock data and callouts
        Test.setMock(HttpCalloutMock.class, new ClioIntServiceQueueableMock());
        // Call the method to test
        Map<String, String> params = new Map<String, String>();
        params.put('fields', 'id,type,date,amount,description,client{id,name},matter{id,display_number},bill{id,number},allocation,updated_at');          
        Test.startTest();
        System.enqueueJob(new ClioIntegrationServiceQueueable('/bank_transactions', params, null));
        Test.stopTest();

        // Assertions
        List<Payment__c> payments = [Select Id from Payment__c];
        System.AssertEquals(3, payments.size());
    }
}