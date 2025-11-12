@isTest
public class ARAgingControllerTest {
    
    @TestSetup
    static void makeData() {
        // Create test accounts
        Account testAccount1 = new Account(Name = 'Test Account 1');
        Account testAccount2 = new Account(Name = 'Test Account 2');
        insert new List<Account>{testAccount1, testAccount2};
        
        // Create test matters with team assignments
        Matter__c testMatter1 = new Matter__c(Name = 'Test Matter 1', Account__c = testAccount1.Id, Team__c = 'Team Carl', Status__c = 'Open');
        Matter__c testMatter2 = new Matter__c(Name = 'Test Matter 2', Account__c = testAccount2.Id, Team__c = 'Team Dillon', Status__c = 'Open');
        insert new List<Matter__c>{testMatter1, testMatter2};
        
        // Calculate test dates relative to today
        Date testAsOfDate = Date.today();
        
        // Create test invoices with various aging scenarios
        List<Invoice__c> testInvoices = new List<Invoice__c>();
        
        // 0-30 days invoices (2 invoices)
        testInvoices.add(new Invoice__c(
            Name = 'Test Invoice 1',
            Invoice_Number__c = 'TEST-001',
            Date__c = testAsOfDate.addDays(-15),
            Balance__c = 1000.00,
            Account__c = testAccount1.Id,
            Matter__c = testMatter1.Id,
            Status__c = 'awaiting_payment',
            KindOfBill__c = 'standard'
        ));
        
        testInvoices.add(new Invoice__c(
            Name = 'Test Invoice 2',
            Invoice_Number__c = 'TEST-002',
            Date__c = testAsOfDate.addDays(-25),
            Balance__c = 1500.00,
            Account__c = testAccount2.Id,
            Matter__c = testMatter2.Id,
            Status__c = 'Paid',
            KindOfBill__c = 'standard'
        ));
        
        // 31-60 days invoices (2 invoices)
        testInvoices.add(new Invoice__c(
            Name = 'Test Invoice 3',
            Invoice_Number__c = 'TEST-003',
            Date__c = testAsOfDate.addDays(-45),
            Balance__c = 2000.00,
            Account__c = testAccount1.Id,
            Matter__c = testMatter1.Id,
            Status__c = 'awaiting_approval',
            KindOfBill__c = 'standard'
        ));
        
        testInvoices.add(new Invoice__c(
            Name = 'Test Invoice 4',
            Invoice_Number__c = 'TEST-004',
            Date__c = testAsOfDate.addDays(-50),
            Balance__c = 2500.00,
            Account__c = testAccount2.Id,
            Matter__c = testMatter2.Id,
            Status__c = 'awaiting_payment',
            KindOfBill__c = 'standard'
        ));
        
        // 61-90 days invoices (2 invoices)
        testInvoices.add(new Invoice__c(
            Name = 'Test Invoice 5',
            Invoice_Number__c = 'TEST-005',
            Date__c = testAsOfDate.addDays(-75),
            Balance__c = 3000.00,
            Account__c = testAccount1.Id,
            Matter__c = testMatter1.Id,
            Status__c = 'Paid',
            KindOfBill__c = 'standard'
        ));
        
        testInvoices.add(new Invoice__c(
            Name = 'Test Invoice 6',
            Invoice_Number__c = 'TEST-006',
            Date__c = testAsOfDate.addDays(-85),
            Balance__c = 3500.00,
            Account__c = testAccount2.Id,
            Matter__c = testMatter2.Id,
            Status__c = 'awaiting_payment',
            KindOfBill__c = 'standard'
        ));
        
        // 91+ days invoices (2 invoices)
        testInvoices.add(new Invoice__c(
            Name = 'Test Invoice 7',
            Invoice_Number__c = 'TEST-007',
            Date__c = testAsOfDate.addDays(-100),
            Balance__c = 4000.00,
            Account__c = testAccount1.Id,
            Matter__c = testMatter1.Id,
            Status__c = 'awaiting_approval',
            KindOfBill__c = 'standard'
        ));
        
        testInvoices.add(new Invoice__c(
            Name = 'Test Invoice 8',
            Invoice_Number__c = 'TEST-008',
            Date__c = testAsOfDate.addDays(-120),
            Balance__c = 4500.00,
            Account__c = testAccount2.Id,
            Matter__c = testMatter2.Id,
            Status__c = 'Paid',
            KindOfBill__c = 'standard'
        ));
        
        // Invoices that should be filtered out
        testInvoices.add(new Invoice__c(
            Name = 'Trust Invoice',
            Invoice_Number__c = 'TRUST-001',
            Date__c = testAsOfDate.addDays(-30),
            Balance__c = 5000.00,
            Account__c = testAccount1.Id,
            Matter__c = testMatter1.Id,
            Status__c = 'awaiting_payment',
            KindOfBill__c = 'trust account'
        ));
        
        testInvoices.add(new Invoice__c(
            Name = 'Zero Balance Invoice',
            Invoice_Number__c = 'ZERO-001',
            Date__c = testAsOfDate.addDays(-15),
            Balance__c = 0.00,
            Account__c = testAccount1.Id,
            Matter__c = testMatter1.Id,
            Status__c = 'awaiting_payment',
            KindOfBill__c = 'standard'
        ));
        
        testInvoices.add(new Invoice__c(
            Name = 'No Matter Invoice',
            Invoice_Number__c = 'NOMATTER-001',
            Date__c = testAsOfDate.addDays(-15),
            Balance__c = 1000.00,
            Account__c = testAccount1.Id,
            Status__c = 'awaiting_payment',
            KindOfBill__c = 'standard'
        ));
        
        testInvoices.add(new Invoice__c(
            Name = 'Invalid Status Invoice',
            Invoice_Number__c = 'INVALID-001',
            Date__c = testAsOfDate.addDays(-15),
            Balance__c = 1000.00,
            Account__c = testAccount1.Id,
            Matter__c = testMatter1.Id,
            Status__c = 'cancelled',
            KindOfBill__c = 'standard'
        ));
        
        insert testInvoices;
    }
    
    @isTest
    static void testGetARAgingDataAllTeams() {
        Test.startTest();
        
        // Test with all teams
        ARAgingController.ARAgingData result = ARAgingController.getARAgingData(Date.today(), 'All');
        
        Test.stopTest();
        
        // Verify cumulative aging buckets
        System.assertNotEquals(null, result, 'Result should not be null');
        
        // 0-30 days should have 2 invoices totaling $2500
        System.assertEquals(2500.00, result.aging30Days, '0-30 days amount should be $2500');
        System.assertEquals(2, result.count30Days, '0-30 days should have 2 invoices');
        
        // 0-60 days should have 4 invoices totaling $7000 (cumulative)
        System.assertEquals(7000.00, result.aging60Days, '0-60 days amount should be $7000');
        System.assertEquals(4, result.count60Days, '0-60 days should have 4 invoices');
        
        // 0-90 days should have 6 invoices totaling $13500 (cumulative)
        System.assertEquals(13500.00, result.aging90Days, '0-90 days amount should be $13500');
        System.assertEquals(6, result.count90Days, '0-90 days should have 6 invoices');
        
        // 0-91+ days should have all 8 invoices totaling $22000 (all outstanding)
        System.assertEquals(22000.00, result.aging91PlusDays, '0-91+ days amount should be $22000');
        System.assertEquals(8, result.count91PlusDays, '0-91+ days should have 8 invoices');
        
        // Verify cumulative nature
        System.assert(result.aging30Days <= result.aging60Days, '30-day amount should be <= 60-day amount');
        System.assert(result.aging60Days <= result.aging90Days, '60-day amount should be <= 90-day amount');
        System.assert(result.count30Days <= result.count60Days, '30-day count should be <= 60-day count');
        System.assert(result.count60Days <= result.count90Days, '60-day count should be <= 90-day count');
    }
    
    @isTest
    static void testGetARAgingDataWithTeamFilter() {
        Test.startTest();
        
        // Test with Team Carl filter
        ARAgingController.ARAgingData result = ARAgingController.getARAgingData(Date.today(), 'Team Carl');
        
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        
        // Team Carl has one invoice in each aging bucket
        // 0-30: $1000, 0-60: $3000, 0-90: $6000, 91+: $4000
        System.assertEquals(1000.00, result.aging30Days, 'Team Carl 0-30 days should be $1000');
        System.assertEquals(1, result.count30Days, 'Team Carl 0-30 days should have 1 invoice');
        
        System.assertEquals(3000.00, result.aging60Days, 'Team Carl 0-60 days should be $3000');
        System.assertEquals(2, result.count60Days, 'Team Carl 0-60 days should have 2 invoices');
        
        System.assertEquals(6000.00, result.aging90Days, 'Team Carl 0-90 days should be $6000');
        System.assertEquals(3, result.count90Days, 'Team Carl 0-90 days should have 3 invoices');
        
        System.assertEquals(10000.00, result.aging91PlusDays, 'Team Carl 0-91+ days should be $10000');
        System.assertEquals(4, result.count91PlusDays, 'Team Carl 0-91+ days should have 4 invoices');
    }
    
    @isTest
    static void testGetARAgingDataWithNullDate() {
        Test.startTest();
        
        // Test with null date (should default to today)
        ARAgingController.ARAgingData result = ARAgingController.getARAgingData(null, 'All');
        
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null even with null date');
        // Should have same results as testGetARAgingDataAllTeams since it defaults to today
    }
    
    @isTest
    static void testGetInvoiceDetails30Days() {
        Test.startTest();
        
        List<ARAgingController.InvoiceDetailData> result = 
            ARAgingController.getInvoiceDetails(Date.today(), '30', 'All');
        
        Test.stopTest();
        
        System.assertEquals(2, result.size(), 'Should return 2 invoices for 30-day bucket');
        
        // Verify invoice details structure
        ARAgingController.InvoiceDetailData firstInvoice = result[0];
        System.assertNotEquals(null, firstInvoice.invoiceId, 'Invoice ID should not be null');
        System.assertNotEquals(null, firstInvoice.invoiceName, 'Invoice name should not be null');
        System.assertNotEquals(null, firstInvoice.invoiceNumber, 'Invoice number should not be null');
        System.assertNotEquals(null, firstInvoice.invoiceDate, 'Invoice date should not be null');
        System.assertNotEquals(null, firstInvoice.balance, 'Balance should not be null');
        System.assertNotEquals(null, firstInvoice.daysOutstanding, 'Days outstanding should not be null');
        System.assertNotEquals(null, firstInvoice.accountName, 'Account name should not be null');
        System.assertNotEquals(null, firstInvoice.teamMatter, 'Team matter should not be null');
        
        // Verify balance amounts
        Decimal totalBalance = 0;
        for (ARAgingController.InvoiceDetailData invoice : result) {
            totalBalance += invoice.balance;
        }
        System.assertEquals(2500.00, totalBalance, 'Total balance should be $2500');
    }
    
    @isTest
    static void testGetInvoiceDetails60Days() {
        Test.startTest();
        
        List<ARAgingController.InvoiceDetailData> result = 
            ARAgingController.getInvoiceDetails(Date.today(), '60', 'All');
        
        Test.stopTest();
        
        // Should return 4 invoices (0-60 days cumulative)
        System.assertEquals(4, result.size(), 'Should return 4 invoices for 60-day bucket');
        
        Decimal totalBalance = 0;
        for (ARAgingController.InvoiceDetailData invoice : result) {
            totalBalance += invoice.balance;
        }
        System.assertEquals(7000.00, totalBalance, 'Total balance should be $7000');
    }
    
    @isTest
    static void testGetInvoiceDetails90Days() {
        Test.startTest();
        
        List<ARAgingController.InvoiceDetailData> result = 
            ARAgingController.getInvoiceDetails(Date.today(), '90', 'All');
        
        Test.stopTest();
        
        // Should return 6 invoices (0-90 days cumulative)
        System.assertEquals(6, result.size(), 'Should return 6 invoices for 90-day bucket');
        
        Decimal totalBalance = 0;
        for (ARAgingController.InvoiceDetailData invoice : result) {
            totalBalance += invoice.balance;
        }
        System.assertEquals(13500.00, totalBalance, 'Total balance should be $13500');
    }
    
    @isTest
    static void testGetInvoiceDetails91PlusDays() {
        Test.startTest();
        
        List<ARAgingController.InvoiceDetailData> result = 
            ARAgingController.getInvoiceDetails(Date.today(), '91+', 'All');
        
        Test.stopTest();
        
        // Should return 8 invoices (0-91+ days - all outstanding)
        System.assertEquals(8, result.size(), 'Should return 8 invoices for 0-91+ day bucket');
        
        Decimal totalBalance = 0;
        for (ARAgingController.InvoiceDetailData invoice : result) {
            totalBalance += invoice.balance;
        }
        System.assertEquals(22000.00, totalBalance, 'Total balance should be $22000');
    }
    
    @isTest
    static void testGetInvoiceDetailsWithTeamFilter() {
        Test.startTest();
        
        List<ARAgingController.InvoiceDetailData> result = 
            ARAgingController.getInvoiceDetails(Date.today(), '60', 'Team Carl');
        
        Test.stopTest();
        
        // Team Carl should have 2 invoices in 0-60 day bucket
        System.assertEquals(2, result.size(), 'Team Carl should have 2 invoices in 60-day bucket');
        
        // Verify all invoices belong to Team Carl
        for (ARAgingController.InvoiceDetailData invoice : result) {
            System.assertEquals('Team Carl', invoice.teamMatter, 'All invoices should be from Team Carl');
        }
        
        Decimal totalBalance = 0;
        for (ARAgingController.InvoiceDetailData invoice : result) {
            totalBalance += invoice.balance;
        }
        System.assertEquals(3000.00, totalBalance, 'Team Carl 60-day total should be $3000');
    }
    
    @isTest
    static void testGetInvoiceDetailsWithNullDate() {
        Test.startTest();
        
        List<ARAgingController.InvoiceDetailData> result = 
            ARAgingController.getInvoiceDetails(null, '30', 'All');
        
        Test.stopTest();
        
        // Should work with null date (defaults to today)
        System.assertEquals(2, result.size(), 'Should return 2 invoices even with null date');
    }
    
    @isTest
    static void testGetAvailableTeams() {
        Test.startTest();
        
        List<String> teams = ARAgingController.getAvailableTeams(Date.today());
        
        Test.stopTest();
        
        System.assertNotEquals(null, teams, 'Teams list should not be null');
        System.assert(teams.size() >= 3, 'Should have at least 3 items (All + 2 teams)');
        
        // First item should always be 'All'
        System.assertEquals('All', teams[0], 'First item should be All');
        
        // Should contain our test teams
        System.assert(teams.contains('Team Carl'), 'Should contain Team Carl');
        System.assert(teams.contains('Team Dillon'), 'Should contain Team Dillon');
        
        // Teams should be sorted (after 'All')
        List<String> sortedTeams = teams.clone();
        String firstItem = sortedTeams.remove(0); // Remove 'All'
        List<String> originalOrder = sortedTeams.clone();
        sortedTeams.sort();
        System.assertEquals(sortedTeams, originalOrder, 'Teams should be sorted alphabetically');
    }
    
    @isTest
    static void testGetAvailableTeamsWithNullDate() {
        Test.startTest();
        
        List<String> teams = ARAgingController.getAvailableTeams(null);
        
        Test.stopTest();
        
        // Should work with null date
        System.assertNotEquals(null, teams, 'Teams list should not be null even with null date');
        System.assert(teams.size() >= 1, 'Should have at least All option');
        System.assertEquals('All', teams[0], 'First item should be All');
    }
    
    @isTest
    static void testFilteringLogic() {
        Test.startTest();
        
        // Test that filtering works correctly
        ARAgingController.ARAgingData result = ARAgingController.getARAgingData(Date.today(), 'All');
        
        Test.stopTest();
        
        // Verify that trust invoices, zero balance invoices, invoices without matters,
        // and invoices with invalid status are filtered out
        
        // We created 8 valid invoices + 4 invalid ones
        // Only the 8 valid ones should be included in aging calculations
        
        // Total valid invoices: 8
        // But 91+ bucket only has 2 invoices, so our total across all buckets checks cumulative properly
        
        Decimal totalExpected = 22000.00; // Sum of all valid invoice balances
        Decimal totalActual = result.aging90Days + result.aging91PlusDays;
        
        // The 0-90 bucket should contain 6 invoices ($13500)
        // The 0-91+ bucket should contain all 8 invoices ($22000)
        // But since 0-90 is cumulative, we need to check differently
        
        System.assertEquals(13500.00, result.aging90Days, '0-90 days should not include filtered invoices');
        System.assertEquals(22000.00, result.aging91PlusDays, '0-91+ days should not include filtered invoices');
    }
    
    @isTest
    static void testEdgeCaseEmptyResults() {
        // Delete all test data to test empty results
        delete [SELECT Id FROM Invoice__c];
        
        Test.startTest();
        
        ARAgingController.ARAgingData result = ARAgingController.getARAgingData(Date.today(), 'All');
        List<ARAgingController.InvoiceDetailData> details = 
            ARAgingController.getInvoiceDetails(Date.today(), '30', 'All');
        List<String> teams = ARAgingController.getAvailableTeams(Date.today());
        
        Test.stopTest();
        
        // Test empty results
        System.assertEquals(0, result.aging30Days, '30-day amount should be 0 with no data');
        System.assertEquals(0, result.count30Days, '30-day count should be 0 with no data');
        System.assertEquals(0, result.aging60Days, '60-day amount should be 0 with no data');
        System.assertEquals(0, result.count60Days, '60-day count should be 0 with no data');
        System.assertEquals(0, result.aging90Days, '90-day amount should be 0 with no data');
        System.assertEquals(0, result.count90Days, '90-day count should be 0 with no data');
        System.assertEquals(0, result.aging91PlusDays, '0-91+ day amount should be 0 with no data');
        System.assertEquals(0, result.count91PlusDays, '0-91+ day count should be 0 with no data');
        
        System.assertEquals(0, details.size(), 'Details should be empty with no data');
        
        System.assertEquals(1, teams.size(), 'Should only have All option with no data');
        System.assertEquals('All', teams[0], 'Should only have All option with no data');
    }
    
    @isTest
    static void testErrorHandling() {
        Test.startTest();
        
        // Test with far future date to ensure no negative logic issues
        Date futureDate = Date.today().addDays(200); // Far enough that all test invoices will be 91+ days old
        ARAgingController.ARAgingData result = ARAgingController.getARAgingData(futureDate, 'All');
        
        Test.stopTest();
        
        // With a far future as-of date, all our test invoices should be in the 91+ bucket
        System.assertNotEquals(null, result, 'Result should not be null even with future date');
        
        // All test invoices should now be older than 91 days relative to the future date
        System.assertEquals(0, result.aging30Days, 'No invoices should be in 30-day bucket with far future date');
        System.assertEquals(0, result.aging60Days, 'No invoices should be in 60-day bucket with far future date');
        System.assertEquals(0, result.aging90Days, 'No invoices should be in 90-day bucket with far future date');
        
        // All valid invoices should be in 0-91+ bucket
        System.assertEquals(22000.00, result.aging91PlusDays, 'All valid invoices should be in 0-91+ bucket');
        System.assertEquals(8, result.count91PlusDays, 'Should have 8 valid invoices in 0-91+ bucket');
    }
}