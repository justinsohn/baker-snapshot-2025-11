@isTest
private class ConflictCheckWithoutSharingTest {

    @testSetup
    static void makeData() {
        // Create test Leads
        List<Lead> testLeads = new List<Lead>();
        for (Integer i = 0; i < 5; i++) {
            testLeads.add(new Lead(
                FirstName = 'WithoutSharing' + i,
                LastName = 'TestLead' + i,
                Company = 'Test Company ' + i,
                Email = 'withoutsharing' + i + '@test.com',
                Phone = '555-100-000' + i,
                Status = 'Open - Not Contacted'
            ));
        }
        insert testLeads;

        // Create test Account
        Account testAccount = new Account(
            Name = 'WithoutSharing Test Account',
            Phone = '555-200-0001'
        );
        insert testAccount;

        // Create test Contact
        Contact testContact = new Contact(
            FirstName = 'WithoutSharing',
            LastName = 'TestContact',
            Email = 'wscontact@test.com',
            Phone = '555-300-0001',
            AccountId = testAccount.Id
        );
        insert testContact;
    }

    @isTest
    static void testFindConflicts() {
        Lead testLead = [SELECT Id, FirstName, LastName, Email, Phone, Company FROM Lead WHERE FirstName LIKE 'WithoutSharing%' LIMIT 1];
        Test.setFixedSearchResults(new List<Id>{testLead.Id});

        Test.startTest();
        List<ConflictRiskScoringService.ConflictMatch> results = ConflictCheckWithoutSharing.findConflicts(
            testLead.FirstName,
            testLead.Email,
            testLead.Phone,
            testLead.Company
        );
        Test.stopTest();

        System.assertNotEquals(null, results, 'Should return results');
    }

    @isTest
    static void testFindConflictsNoParameters() {
        Test.startTest();
        List<ConflictRiskScoringService.ConflictMatch> results = ConflictCheckWithoutSharing.findConflicts('', '', '', '');
        Test.stopTest();

        System.assertEquals(0, results.size(), 'Should return empty list for no parameters');
    }

    @isTest
    static void testSaveConflictCheck() {
        Lead testLead = [SELECT Id FROM Lead WHERE FirstName LIKE 'WithoutSharing%' LIMIT 1];

        List<ConflictRiskScoringService.ConflictMatch> matches = new List<ConflictRiskScoringService.ConflictMatch>();
        ConflictRiskScoringService.ConflictMatch match = new ConflictRiskScoringService.ConflictMatch();
        match.id = testLead.Id;
        match.recordType = 'Lead';
        match.name = 'Test';
        match.matchType = 'Email';
        match.riskScore = 60;
        match.matchReason = 'Test reason';
        matches.add(match);

        Test.startTest();
        String logId = ConflictCheckWithoutSharing.saveConflictCheck(
            testLead.Id,
            'Test Name',
            'test@test.com',
            '555-000-0000',
            'Test Company',
            matches
        );
        Test.stopTest();

        System.assertNotEquals(null, logId, 'Should return log ID');
        Conflict_Check_Log__c log = [SELECT Id, Highest_Risk_Score__c FROM Conflict_Check_Log__c WHERE Id = :logId];
        System.assertEquals(60, log.Highest_Risk_Score__c, 'Should have correct risk score');
    }

    @isTest
    static void testSaveConflictCheckNullLeadId() {
        Test.startTest();
        try {
            ConflictCheckWithoutSharing.saveConflictCheck(
                null,
                'Test',
                'test@test.com',
                '555-000-0000',
                'Test Company',
                new List<ConflictRiskScoringService.ConflictMatch>()
            );
            System.assert(false, 'Should throw exception for null Lead ID');
        } catch (Exception e) {
            // Should throw some kind of exception for null Lead ID
            System.assert(true, 'Exception thrown as expected for null Lead ID: ' + e.getMessage());
        }
        Test.stopTest();
    }

    @isTest
    static void testGetConflictCheckHistory() {
        Lead testLead = [SELECT Id FROM Lead WHERE FirstName LIKE 'WithoutSharing%' LIMIT 1];

        // Create a conflict check log
        String logId = ConflictCheckWithoutSharing.saveConflictCheck(
            testLead.Id,
            'Test',
            'test@test.com',
            '555-000-0000',
            'Test Company',
            new List<ConflictRiskScoringService.ConflictMatch>()
        );

        Test.startTest();
        List<ConflictCheckController.ConflictCheckLog> history = ConflictCheckWithoutSharing.getConflictCheckHistory(testLead.Id);
        Test.stopTest();

        System.assertEquals(1, history.size(), 'Should return one log entry');
    }

    @isTest
    static void testGetConflictCheckHistoryNullLeadId() {
        Test.startTest();
        List<ConflictCheckController.ConflictCheckLog> history = ConflictCheckWithoutSharing.getConflictCheckHistory(null);
        Test.stopTest();

        System.assertEquals(0, history.size(), 'Should return empty list for null Lead ID');
    }

    @isTest
    static void testValidateLeadExists() {
        Lead testLead = [SELECT Id FROM Lead WHERE FirstName LIKE 'WithoutSharing%' LIMIT 1];

        Test.startTest();
        List<Lead> leads = ConflictCheckWithoutSharing.validateLeadExists(testLead.Id);
        Test.stopTest();

        System.assertEquals(1, leads.size(), 'Should find the lead');
        System.assertEquals(testLead.Id, leads[0].Id, 'Should return correct lead');
    }

    @isTest
    static void testValidateLeadExistsNull() {
        Test.startTest();
        List<Lead> leads = ConflictCheckWithoutSharing.validateLeadExists(null);
        Test.stopTest();

        System.assertEquals(0, leads.size(), 'Should return empty list for null ID');
    }

    @isTest
    static void testSearchLeads() {
        Test.startTest();
        List<Lead> results = ConflictCheckWithoutSharing.searchLeads('WithoutSharing');
        Test.stopTest();

        System.assert(results.size() > 0, 'Should find leads');
    }

    @isTest
    static void testSearchLeadsBlankTerm() {
        Test.startTest();
        List<Lead> results = ConflictCheckWithoutSharing.searchLeads('');
        Test.stopTest();

        System.assertEquals(0, results.size(), 'Should return empty list for blank term');
    }

    @isTest
    static void testSearchLeadsShortTerm() {
        Test.startTest();
        List<Lead> results = ConflictCheckWithoutSharing.searchLeads('W');
        Test.stopTest();

        System.assertEquals(0, results.size(), 'Should return empty list for short term');
    }
}