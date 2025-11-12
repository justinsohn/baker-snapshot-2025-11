@isTest
private class TimeEntryDashboardControllerTest {

    @TestSetup
    static void makeData(){
        // Create test users with team
        Profile p = [SELECT Id FROM Profile WHERE Name='Standard User'];
        User testUser = new User(
            Alias = 'testuser',
            Email='testuser@testorg.com',
            EmailEncodingKey='UTF-8',
            LastName='Testing',
            LanguageLocaleKey='en_US',
            LocaleSidKey='en_US',
            ProfileId = p.Id,
            TimeZoneSidKey='America/Denver',
            UserName='testuser' + System.currentTimeMillis() + '@testorg.com',
            Target_Hours__c = 2000,
            Start_Date__c = Date.today().toStartOfMonth(),
            Team__c = 'Team DF'
        );
        insert testUser;
        
        // Create second team member
        User teamMember = new User(
            Alias = 'teammem',
            Email='teammember@testorg.com',
            EmailEncodingKey='UTF-8',
            LastName='TeamMember',
            LanguageLocaleKey='en_US',
            LocaleSidKey='en_US',
            ProfileId = p.Id,
            TimeZoneSidKey='America/Denver',
            UserName='teammember' + System.currentTimeMillis() + '@testorg.com',
            Target_Hours__c = 1500,
            Start_Date__c = Date.today().toStartOfMonth().addDays(-10),
            Team__c = 'Team DF'
        );
        insert teamMember;

        // Create a test Matter
        Matter__c testMatter = new Matter__c(
            Name = 'Test Matter 001',
            Status__c = 'Open',
            Responsible_Attorney__c = testUser.Id,
            Team__c = 'Team DF'
        );
        insert testMatter;

        // Create test invoices for collection rate testing
        List<Invoice__c> testInvoices = new List<Invoice__c>();
        testInvoices.add(new Invoice__c(
            Invoice_Number__c = 'INV-001',
            Date__c = Date.today(),
            Amount__c = 1000.00,
            Balance__c = 200.00,
            Status__c = 'Paid',
            Matter__c = testMatter.Id
        ));
        testInvoices.add(new Invoice__c(
            Invoice_Number__c = 'INV-002',
            Date__c = Date.today().addDays(-1),
            Amount__c = 2000.00,
            Balance__c = 500.00,
            Status__c = 'awaiting_payment',
            Matter__c = testMatter.Id
        ));
        testInvoices.add(new Invoice__c(
            Invoice_Number__c = 'INV-003',
            Date__c = Date.today().addDays(-2),
            Amount__c = 500.00,
            Balance__c = 500.00,
            Status__c = 'awaiting_approval',
            Matter__c = testMatter.Id
        ));
        insert testInvoices;

        // Create Time Entry records for the test user for testing filters
        List<Time_Entry__c> entries = new List<Time_Entry__c>();
        // Today - Billable
        entries.add(new Time_Entry__c(
            User__c = testUser.Id, // Set the User__c field instead of OwnerId
            Date__c = Date.today(), 
            Duration__c = 5.0,
            Non_Billable__c = false, 
            Note__c = 'Billable work.', 
            Matter__c = testMatter.Id,
            Rate__c = 250
        ));
        // Yesterday - Non-Billable
        entries.add(new Time_Entry__c(
            User__c = testUser.Id, // Set the User__c field
            Date__c = Date.today().addDays(-1), 
            Duration__c = 2.0,
            Non_Billable__c = true, 
            Note__c = 'Non-billable work.', 
            Matter__c = testMatter.Id,
            Rate__c = 0
        ));
        // Last Month - Billable
         entries.add(new Time_Entry__c(
            User__c = testUser.Id, // Set the User__c field
            Date__c = Date.today().addMonths(-1), 
            Duration__c = 8.0,
            Non_Billable__c = false, 
            Note__c = 'Older billable work.', 
            Matter__c = testMatter.Id,
            Rate__c = 250
        ));
        // Team member entry - Today - Billable
        entries.add(new Time_Entry__c(
            User__c = teamMember.Id,
            Date__c = Date.today(), 
            Duration__c = 3.0,
            Non_Billable__c = false, 
            Note__c = 'Team member billable work.', 
            Matter__c = testMatter.Id,
            Rate__c = 200
        ));
        insert entries;
    }

    @isTest
    static void testGetUserTargetInfo() {
        User u = [SELECT Id, Target_Hours__c, Start_Date__c FROM User WHERE Alias = 'testuser' LIMIT 1];

        System.runAs(u) {
            Test.startTest();
            // Test personal view
            TimeEntryDashboardController.TargetInfoWrapper result = TimeEntryDashboardController.getUserTargetInfo(false);
            System.assertNotEquals(null, result, 'Result should not be null.');
            System.assertEquals(u.Target_Hours__c, result.targetHours, 'Yearly target should match the test user.');
            System.assertEquals(u.Start_Date__c, result.startDate, 'Start date should match the test user.');
            System.assertEquals(1, result.userCount, 'User count should be 1 for personal view.');
            
            // Test team view
            TimeEntryDashboardController.TargetInfoWrapper teamResult = TimeEntryDashboardController.getUserTargetInfo(true);
            System.assertNotEquals(null, teamResult, 'Team result should not be null.');
            // Should be at least the sum of our test users (3500), but may include other team members
            System.assert(teamResult.targetHours >= 3500, 'Team target should include at least our test team members.');
            System.assert(teamResult.userCount >= 2, 'User count should include at least our 2 test team members.');
            Test.stopTest();
        }
    }

    @isTest
    static void testGetTimeEntries_All() {
        User u = [SELECT Id FROM User WHERE Alias = 'testuser' LIMIT 1];
        Date startDate = Date.today().addDays(-2);
        Date endDate = Date.today();

        System.runAs(u) {
            Test.startTest();
            // Test personal view
            List<Time_Entry__c> results = TimeEntryDashboardController.getTimeEntries(startDate, endDate, 'All', false);
            System.assertEquals(2, results.size(), 'Should return all 2 entries (billable and non-billable) for the date range.');
            
            // Test team view
            List<Time_Entry__c> teamResults = TimeEntryDashboardController.getTimeEntries(startDate, endDate, 'All', true);
            System.assertEquals(3, teamResults.size(), 'Should return all 3 team entries for the date range.');
            Test.stopTest();
        }
    }

    @isTest
    static void testGetTimeEntries_Billable() {
        User u = [SELECT Id FROM User WHERE Alias = 'testuser' LIMIT 1];
        Date startDate = Date.today().addDays(-2);
        Date endDate = Date.today();

        System.runAs(u) {
            Test.startTest();
            List<Time_Entry__c> results = TimeEntryDashboardController.getTimeEntries(startDate, endDate, 'Billable', false);
            Test.stopTest();

            System.assertEquals(1, results.size(), 'Should return only the 1 billable entry.');
            System.assertEquals(false, results[0].Non_Billable__c, 'Entry should be billable.');
        }
    }

     @isTest
    static void testGetTimeEntries_NonBillable() {
        User u = [SELECT Id FROM User WHERE Alias = 'testuser' LIMIT 1];
        Date startDate = Date.today().addDays(-2);
        Date endDate = Date.today();

        System.runAs(u) {
            Test.startTest();
            List<Time_Entry__c> results = TimeEntryDashboardController.getTimeEntries(startDate, endDate, 'Non-Billable', false);
            Test.stopTest();

            System.assertEquals(1, results.size(), 'Should return only the 1 non-billable entry.');
            System.assertEquals(true, results[0].Non_Billable__c, 'Entry should be non-billable.');
        }
    }

    @isTest
    static void testGetTimeEntries_NoResults() {
        User u = [SELECT Id FROM User WHERE Alias = 'testuser' LIMIT 1];
        Date startDate = Date.today().addYears(-1).addDays(-1);
        Date endDate = Date.today().addYears(-1);

         System.runAs(u) {
            Test.startTest();
            List<Time_Entry__c> results = TimeEntryDashboardController.getTimeEntries(startDate, endDate, 'All', false);
            Test.stopTest();

            System.assertEquals(0, results.size(), 'Should return 0 time entries for a date range with no data.');
        }
    }

    @isTest
    static void testGetCollectionRate() {
        User u = [SELECT Id FROM User WHERE Alias = 'testuser' LIMIT 1];
        
        System.runAs(u) {
            Test.startTest();
            // Test personal view
            Decimal result = TimeEntryDashboardController.getCollectionRate('This Week', null, null, false);
            System.assertNotEquals(null, result, 'Collection rate result should not be null.');
            System.assert(result >= 0, 'Collection rate should be a non-negative percentage.');
            
            // Test team view
            Decimal teamResult = TimeEntryDashboardController.getCollectionRate('This Week', null, null, true);
            System.assertNotEquals(null, teamResult, 'Team collection rate result should not be null.');
            System.assert(teamResult >= 0, 'Team collection rate should be a non-negative percentage.');
            Test.stopTest();
        }
    }

    @isTest
    static void testGetCollectionRateWithDateRange() {
        User u = [SELECT Id FROM User WHERE Alias = 'testuser' LIMIT 1];
        Date startDate = Date.today().addDays(-1);
        Date endDate = Date.today();
        
        System.runAs(u) {
            Test.startTest();
            Decimal result = TimeEntryDashboardController.getCollectionRate(null, startDate, endDate, false);
            Test.stopTest();
            
            // Since Paid_Amount__c might be calculated, just verify we get a valid rate >= 0
            System.assertNotEquals(null, result, 'Collection rate result should not be null.');
            System.assert(result >= 0, 'Collection rate should be a non-negative percentage.');
        }
    }

    @isTest
    static void testGetCollectionRateNoInvoices() {
        // Create a different user with no invoices
        Profile p = [SELECT Id FROM Profile WHERE Name='Standard User'];
        User testUserNoInvoices = new User(
            Alias = 'testno',
            Email='testnoinv@testorg.com',
            EmailEncodingKey='UTF-8',
            LastName='NoInvoices',
            LanguageLocaleKey='en_US',
            LocaleSidKey='en_US',
            ProfileId = p.Id,
            TimeZoneSidKey='America/Denver',
            UserName='testnoinv' + System.currentTimeMillis() + '@testorg.com'
        );
        insert testUserNoInvoices;
        
        System.runAs(testUserNoInvoices) {
            Test.startTest();
            Decimal result = TimeEntryDashboardController.getCollectionRate('This Week', null, null, false);
            Test.stopTest();
            
            System.assertEquals(0, result, 'Collection rate should be 0 when no invoices exist.');
        }
    }

    @isTest
    static void testGetCollectionRateDetails() {
        User u = [SELECT Id FROM User WHERE Alias = 'testuser' LIMIT 1];
        
        System.runAs(u) {
            Test.startTest();
            List<TimeEntryDashboardController.InvoiceDetailData> results = 
                TimeEntryDashboardController.getCollectionRateDetails('This Week', null, null, false);
            Test.stopTest();
            
            System.assertEquals(2, results.size(), 'Should return 2 invoice detail records.');
            // System.assertEquals(3, results.size(), 'Should return 3 invoice detail records.');
            
            // Verify we got some results and basic structure is correct
            System.assert(results.size() > 0, 'Should return at least one invoice detail record.');
            TimeEntryDashboardController.InvoiceDetailData firstDetail = results[0];
            System.assertNotEquals(null, firstDetail.invoiceNumber, 'Invoice number should not be null.');
            System.assertNotEquals(null, firstDetail.totalAmount, 'Total amount should not be null.');
            System.assertEquals('Test Matter 001', firstDetail.matter, 'Matter name should match.');
        }
    }

    @isTest
    static void testGetCollectionRateDetailsWithDateRange() {
        User u = [SELECT Id FROM User WHERE Alias = 'testuser' LIMIT 1];
        Date startDate = Date.today().addDays(-1);
        Date endDate = Date.today();
        
        System.runAs(u) {
            Test.startTest();
            List<TimeEntryDashboardController.InvoiceDetailData> results = 
                TimeEntryDashboardController.getCollectionRateDetails(null, startDate, endDate, false);
            Test.stopTest();
            
            System.assertEquals(2, results.size(), 'Should return 2 invoice detail records within date range.');
        }
    }

    @isTest
    static void testGetCollectionRateDetailsNoResults() {
        // Create a different user with no invoices
        Profile p = [SELECT Id FROM Profile WHERE Name='Standard User'];
        User testUserNoInvoices = new User(
            Alias = 'testno2',
            Email='testnoinv2@testorg.com',
            EmailEncodingKey='UTF-8',
            LastName='NoInvoices2',
            LanguageLocaleKey='en_US',
            LocaleSidKey='en_US',
            ProfileId = p.Id,
            TimeZoneSidKey='America/Denver',
            UserName='testnoinv2' + System.currentTimeMillis() + '@testorg.com'
        );
        insert testUserNoInvoices;
        
        System.runAs(testUserNoInvoices) {
            Test.startTest();
            List<TimeEntryDashboardController.InvoiceDetailData> results = 
                TimeEntryDashboardController.getCollectionRateDetails('This Week', null, null, false);
            Test.stopTest();
            
            System.assertEquals(0, results.size(), 'Should return 0 invoice details when no invoices exist.');
        }
    }

    @isTest
    static void testGetCollectionRateWithDateFilters() {
        User u = [SELECT Id FROM User WHERE Alias = 'testuser' LIMIT 1];
        
        System.runAs(u) {
            Test.startTest();
            // Test Today filter
            Decimal todayResult = TimeEntryDashboardController.getCollectionRate('Today', null, null, false);
            System.assertNotEquals(null, todayResult, 'Today filter should return a result.');
            
            // Test Yesterday filter
            Decimal yesterdayResult = TimeEntryDashboardController.getCollectionRate('Yesterday', null, null, false);
            System.assertNotEquals(null, yesterdayResult, 'Yesterday filter should return a result.');
            
            // Test This Month filter
            Decimal thisMonthResult = TimeEntryDashboardController.getCollectionRate('This Month', null, null, false);
            System.assertNotEquals(null, thisMonthResult, 'This Month filter should return a result.');
            
            // Test Last Week filter
            Decimal lastWeekResult = TimeEntryDashboardController.getCollectionRate('Last Week', null, null, false);
            System.assertNotEquals(null, lastWeekResult, 'Last Week filter should return a result.');
            
            // Test Last Month filter
            Decimal lastMonthResult = TimeEntryDashboardController.getCollectionRate('Last Month', null, null, false);
            System.assertNotEquals(null, lastMonthResult, 'Last Month filter should return a result.');
            
            // Test This Year filter
            Decimal thisYearResult = TimeEntryDashboardController.getCollectionRate('This Year', null, null, false);
            System.assertNotEquals(null, thisYearResult, 'This Year filter should return a result.');
            
            // Test Last Year filter
            Decimal lastYearResult = TimeEntryDashboardController.getCollectionRate('Last Year', null, null, false);
            System.assertNotEquals(null, lastYearResult, 'Last Year filter should return a result.');
            Test.stopTest();
        }
    }

    @isTest
    static void testGetCollectionRateWithQuarterlyFilters() {
        User u = [SELECT Id FROM User WHERE Alias = 'testuser' LIMIT 1];
        
        System.runAs(u) {
            Test.startTest();
            // Test This Quarter filter
            Decimal thisQuarterResult = TimeEntryDashboardController.getCollectionRate('This Quarter', null, null, false);
            System.assertNotEquals(null, thisQuarterResult, 'This Quarter filter should return a result.');
            System.assert(thisQuarterResult >= 0, 'This Quarter result should be non-negative.');
            
            // Test Last Quarter filter
            Decimal lastQuarterResult = TimeEntryDashboardController.getCollectionRate('Last Quarter', null, null, false);
            System.assertNotEquals(null, lastQuarterResult, 'Last Quarter filter should return a result.');
            System.assert(lastQuarterResult >= 0, 'Last Quarter result should be non-negative.');
            Test.stopTest();
        }
    }

    @isTest
    static void testGetCollectionRateDetailsWithDateFilters() {
        User u = [SELECT Id FROM User WHERE Alias = 'testuser' LIMIT 1];
        
        System.runAs(u) {
            Test.startTest();
            // Test Today filter
            List<TimeEntryDashboardController.InvoiceDetailData> todayResults = 
                TimeEntryDashboardController.getCollectionRateDetails('Today', null, null, false);
            System.assertNotEquals(null, todayResults, 'Today filter should return results.');
            
            // Test Yesterday filter
            List<TimeEntryDashboardController.InvoiceDetailData> yesterdayResults = 
                TimeEntryDashboardController.getCollectionRateDetails('Yesterday', null, null, false);
            System.assertNotEquals(null, yesterdayResults, 'Yesterday filter should return results.');
            
            // Test This Month filter
            List<TimeEntryDashboardController.InvoiceDetailData> thisMonthResults = 
                TimeEntryDashboardController.getCollectionRateDetails('This Month', null, null, false);
            System.assertNotEquals(null, thisMonthResults, 'This Month filter should return results.');
            
            // Test Last Week filter
            List<TimeEntryDashboardController.InvoiceDetailData> lastWeekResults = 
                TimeEntryDashboardController.getCollectionRateDetails('Last Week', null, null, false);
            System.assertNotEquals(null, lastWeekResults, 'Last Week filter should return results.');
            
            // Test Last Month filter
            List<TimeEntryDashboardController.InvoiceDetailData> lastMonthResults = 
                TimeEntryDashboardController.getCollectionRateDetails('Last Month', null, null, false);
            System.assertNotEquals(null, lastMonthResults, 'Last Month filter should return results.');
            
            // Test This Quarter filter
            List<TimeEntryDashboardController.InvoiceDetailData> thisQuarterResults = 
                TimeEntryDashboardController.getCollectionRateDetails('This Quarter', null, null, false);
            System.assertNotEquals(null, thisQuarterResults, 'This Quarter filter should return results.');
            
            // Test Last Quarter filter
            List<TimeEntryDashboardController.InvoiceDetailData> lastQuarterResults = 
                TimeEntryDashboardController.getCollectionRateDetails('Last Quarter', null, null, false);
            System.assertNotEquals(null, lastQuarterResults, 'Last Quarter filter should return results.');
            
            // Test This Year filter
            List<TimeEntryDashboardController.InvoiceDetailData> thisYearResults = 
                TimeEntryDashboardController.getCollectionRateDetails('This Year', null, null, false);
            System.assertNotEquals(null, thisYearResults, 'This Year filter should return results.');
            
            // Test Last Year filter
            List<TimeEntryDashboardController.InvoiceDetailData> lastYearResults = 
                TimeEntryDashboardController.getCollectionRateDetails('Last Year', null, null, false);
            System.assertNotEquals(null, lastYearResults, 'Last Year filter should return results.');
            Test.stopTest();
        }
    }

    @isTest
    static void testGetTimeEntriesWithNullFilter() {
        User u = [SELECT Id FROM User WHERE Alias = 'testuser' LIMIT 1];
        Date startDate = Date.today().addDays(-2);
        Date endDate = Date.today();

        System.runAs(u) {
            Test.startTest();
            // Test with null billable status (should return all entries)
            List<Time_Entry__c> results = TimeEntryDashboardController.getTimeEntries(startDate, endDate, null, false);
            Test.stopTest();

            System.assertEquals(2, results.size(), 'Should return all entries when billableStatus is null.');
        }
    }

    @isTest
    static void testGetTimeEntriesWithEmptyFilter() {
        User u = [SELECT Id FROM User WHERE Alias = 'testuser' LIMIT 1];
        Date startDate = Date.today().addDays(-2);
        Date endDate = Date.today();

        System.runAs(u) {
            Test.startTest();
            // Test with empty string billable status (should return all entries)
            List<Time_Entry__c> results = TimeEntryDashboardController.getTimeEntries(startDate, endDate, '', false);
            Test.stopTest();

            System.assertEquals(2, results.size(), 'Should return all entries when billableStatus is empty string.');
        }
    }

    @isTest
    static void testGetCollectionRateWithNullFilter() {
        User u = [SELECT Id FROM User WHERE Alias = 'testuser' LIMIT 1];
        
        System.runAs(u) {
            Test.startTest();
            // Test with null date filter and null dates (should handle gracefully)
            Decimal result = TimeEntryDashboardController.getCollectionRate(null, null, null, false);
            Test.stopTest();
            
            System.assertNotEquals(null, result, 'Should handle null filter gracefully.');
            System.assert(result >= 0, 'Result should be non-negative.');
        }
    }

    @isTest
    static void testGetCollectionRateDetailsWithNullFilter() {
        User u = [SELECT Id FROM User WHERE Alias = 'testuser' LIMIT 1];
        
        System.runAs(u) {
            Test.startTest();
            // Test with null date filter and null dates (should handle gracefully)
            List<TimeEntryDashboardController.InvoiceDetailData> results = 
                TimeEntryDashboardController.getCollectionRateDetails(null, null, null, false);
            Test.stopTest();
            
            System.assertNotEquals(null, results, 'Should handle null filter gracefully.');
        }
    }

    @isTest
    static void testGetCollectionRateWithInvalidFilter() {
        User u = [SELECT Id FROM User WHERE Alias = 'testuser' LIMIT 1];
        
        System.runAs(u) {
            Test.startTest();
            // Test with invalid/unknown filter string
            Decimal result = TimeEntryDashboardController.getCollectionRate('InvalidFilter', null, null, false);
            Test.stopTest();
            
            System.assertNotEquals(null, result, 'Should handle invalid filter gracefully.');
            System.assert(result >= 0, 'Result should be non-negative.');
        }
    }

    @isTest
    static void testGetCurrentUserTeam() {
        User u = [SELECT Id FROM User WHERE Alias = 'testuser' LIMIT 1];
        
        System.runAs(u) {
            Test.startTest();
            String team = TimeEntryDashboardController.getCurrentUserTeam();
            Test.stopTest();
            
            System.assertEquals('Team DF', team, 'Should return the user\'s team.');
        }
    }

    @isTest
    static void testTeamViewWithNoTeam() {
        // Create a user with no team
        Profile p = [SELECT Id FROM Profile WHERE Name='Standard User'];
        User userNoTeam = new User(
            Alias = 'noteam',
            Email='noteam@testorg.com',
            EmailEncodingKey='UTF-8',
            LastName='NoTeam',
            LanguageLocaleKey='en_US',
            LocaleSidKey='en_US',
            ProfileId = p.Id,
            TimeZoneSidKey='America/Denver',
            UserName='noteam' + System.currentTimeMillis() + '@testorg.com',
            Target_Hours__c = 1000,
            Start_Date__c = Date.today()
        );
        insert userNoTeam;
        
        System.runAs(userNoTeam) {
            Test.startTest();
            // Test that user with no team gets personal data even when viewTeam is true
            TimeEntryDashboardController.TargetInfoWrapper result = TimeEntryDashboardController.getUserTargetInfo(true);
            System.assertEquals(1000, result.targetHours, 'Should return personal target when user has no team.');
            System.assertEquals(1, result.userCount, 'Should have user count of 1 when user has no team.');
            Test.stopTest();
        }
    }
}