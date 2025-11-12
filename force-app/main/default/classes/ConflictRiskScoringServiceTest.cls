/**
 * @description Test class for ConflictRiskScoringService
 */
@isTest
private class ConflictRiskScoringServiceTest {

    @isTest
    static void testCalculateScoreEmailMatch() {
        Integer score = ConflictRiskScoringService.calculateScore('Email', 'Contact', null, false);
        System.assertEquals(95, score, 'Email match with Contact should score 95');
    }

    @isTest
    static void testCalculateScorePhoneMatch() {
        Integer score = ConflictRiskScoringService.calculateScore('Phone', 'Lead', null, false);
        System.assertEquals(85, score, 'Phone match with Lead should score 85');
    }

    @isTest
    static void testCalculateScoreNameMatch() {
        Integer score = ConflictRiskScoringService.calculateScore('Name', 'Account', null, false);
        System.assertEquals(85, score, 'Name match with Account should score 85');
    }

    @isTest
    static void testCalculateScoreBusinessMatch() {
        Integer score = ConflictRiskScoringService.calculateScore('Business', 'Account', null, false);
        System.assertEquals(80, score, 'Business match with Account should score 80');
    }

    @isTest
    static void testCalculateScoreMatterRelationship() {
        Integer score = ConflictRiskScoringService.calculateScore('Matter Relationship', 'Contact', null, false);
        System.assertEquals(65, score, 'Matter Relationship with Contact should score 65');
    }

    @isTest
    static void testCalculateScoreWithActiveMatter() {
        Integer score = ConflictRiskScoringService.calculateScore('Email', 'Matter__c', 'Open', false);
        System.assertEquals(100, score, 'Active matter should add 20 points but still cap at 100');
    }

    @isTest
    static void testCalculateScoreWithClosedMatter() {
        Integer score = ConflictRiskScoringService.calculateScore('Email', 'Matter__c', 'Closed', false);
        System.assertEquals(100, score, 'Closed matter should add 5 points, capped at 100');
    }

    @isTest
    static void testCalculateScoreWithPendingMatter() {
        Integer score = ConflictRiskScoringService.calculateScore('Phone', 'Matter__c', 'Pending', false);
        System.assertEquals(100, score, 'Pending matter should add 10 points, capped at 100');
    }

    @isTest
    static void testCalculateScoreWithMultipleMatches() {
        Integer score = ConflictRiskScoringService.calculateScore('Email', 'Contact', 'Open', true);
        System.assertEquals(100, score, 'Multiple matches should add 10 points, capped at 100');
    }

    @isTest
    static void testGetRiskLevelCritical() {
        String level = ConflictRiskScoringService.getRiskLevel(95);
        System.assertEquals('Critical', level, '95 should be Critical risk');
    }

    @isTest
    static void testGetRiskLevelHigh() {
        String level = ConflictRiskScoringService.getRiskLevel(70);
        System.assertEquals('High', level, '70 should be High risk');
    }

    @isTest
    static void testGetRiskLevelMedium() {
        String level = ConflictRiskScoringService.getRiskLevel(50);
        System.assertEquals('Medium', level, '50 should be Medium risk');
    }

    @isTest
    static void testGetRiskLevelLow() {
        String level = ConflictRiskScoringService.getRiskLevel(30);
        System.assertEquals('Low', level, '30 should be Low risk');
    }

    @isTest
    static void testGetRiskLevelBoundary() {
        System.assertEquals('Critical', ConflictRiskScoringService.getRiskLevel(80), '80 should be Critical');
        System.assertEquals('High', ConflictRiskScoringService.getRiskLevel(60), '60 should be High');
        System.assertEquals('Medium', ConflictRiskScoringService.getRiskLevel(40), '40 should be Medium');
        System.assertEquals('Low', ConflictRiskScoringService.getRiskLevel(39), '39 should be Low');
    }

    @isTest
    static void testConflictMatchWrapper() {
        ConflictRiskScoringService.ConflictMatch match = new ConflictRiskScoringService.ConflictMatch();
        match.id = '003000000000001';
        match.name = 'Test Contact';
        match.recordType = 'Contact';
        match.matchType = 'Email';
        match.riskScore = 95;
        match.riskLevel = 'Critical';

        System.assertEquals('003000000000001', match.id);
        System.assertEquals('Test Contact', match.name);
        System.assertEquals('Contact', match.recordType);
        System.assertEquals('Email', match.matchType);
        System.assertEquals(95, match.riskScore);
        System.assertEquals('Critical', match.riskLevel);
    }

    @isTest
    static void testConflictMatchDefaultValues() {
        ConflictRiskScoringService.ConflictMatch match = new ConflictRiskScoringService.ConflictMatch();
        System.assertEquals(0, match.riskScore, 'Default risk score should be 0');
        System.assertEquals('Low', match.riskLevel, 'Default risk level should be Low');
    }

    @isTest
    static void testScoreCapAt100() {
        // Test multiple scenarios that would exceed 100
        Integer score1 = ConflictRiskScoringService.calculateScore('Email', 'Matter__c', 'Open', true);
        System.assert(score1 <= 100, 'Score should never exceed 100');

        Integer score2 = ConflictRiskScoringService.calculateScore('Phone', 'Matter__c', 'Active', true);
        System.assert(score2 <= 100, 'Score should never exceed 100');
    }

    @isTest
    static void testNullMatterStatus() {
        Integer score = ConflictRiskScoringService.calculateScore('Email', 'Contact', null, false);
        System.assertEquals(95, score, 'Null matter status should not add points');
    }

    @isTest
    static void testBlankMatterStatus() {
        Integer score = ConflictRiskScoringService.calculateScore('Email', 'Contact', '', false);
        System.assertEquals(95, score, 'Blank matter status should not add points');
    }

    @isTest
    static void testUnrecognizedMatchType() {
        Integer score = ConflictRiskScoringService.calculateScore('Unknown', 'Contact', null, false);
        System.assertEquals(5, score, 'Unknown match type should result in low base score with Contact adjustment');
    }

    @isTest
    static void testActiveStatusVariations() {
        Integer scoreActive = ConflictRiskScoringService.calculateScore('Email', 'Matter', 'Active', false);
        Integer scoreOpen = ConflictRiskScoringService.calculateScore('Email', 'Matter', 'Open', false);
        System.assertEquals(scoreActive, scoreOpen, 'Active and Open should be treated the same');
    }

    @isTest
    static void testAccountTypeBonus() {
        Integer score = ConflictRiskScoringService.calculateScore('Email', 'Account', null, false);
        System.assertEquals(95, score, 'Account should get +5 bonus');
    }

    @isTest
    static void testLeadTypeNoBonus() {
        Integer score = ConflictRiskScoringService.calculateScore('Email', 'Lead', null, false);
        System.assertEquals(90, score, 'Lead should not get type bonus');
    }

    @isTest
    static void testClientIntakeType() {
        Integer score = ConflictRiskScoringService.calculateScore('Name', 'Client_Intake__c', null, false);
        System.assertEquals(80, score, 'Client Intake should have base name score');
    }

    @isTest
    static void testTimeEntryType() {
        Integer score = ConflictRiskScoringService.calculateScore('Name', 'Time_Entry__c', null, false);
        System.assertEquals(80, score, 'Time Entry should have base name score');
    }

    @isTest
    static void testClioNoteType() {
        Integer score = ConflictRiskScoringService.calculateScore('Name', 'Clio_Note__c', null, false);
        System.assertEquals(80, score, 'Clio Note should have base name score');
    }

    @isTest
    static void testRiskLevelEdgeCases() {
        System.assertEquals('Critical', ConflictRiskScoringService.getRiskLevel(100), '100 should be Critical');
        System.assertEquals('Critical', ConflictRiskScoringService.getRiskLevel(80), '80 should be Critical');
        System.assertEquals('High', ConflictRiskScoringService.getRiskLevel(79), '79 should be High');
        System.assertEquals('High', ConflictRiskScoringService.getRiskLevel(60), '60 should be High');
        System.assertEquals('Medium', ConflictRiskScoringService.getRiskLevel(59), '59 should be Medium');
        System.assertEquals('Medium', ConflictRiskScoringService.getRiskLevel(40), '40 should be Medium');
        System.assertEquals('Low', ConflictRiskScoringService.getRiskLevel(39), '39 should be Low');
        System.assertEquals('Low', ConflictRiskScoringService.getRiskLevel(0), '0 should be Low');
    }

    @isTest
    static void testConflictMatchAllFields() {
        ConflictRiskScoringService.ConflictMatch match = new ConflictRiskScoringService.ConflictMatch();
        match.id = '003000000000001';
        match.name = 'Test Match';
        match.recordType = 'Contact';
        match.matchType = 'Email';
        match.matchReason = 'Exact email match';
        match.email = 'test@test.com';
        match.phone = '555-123-4567';
        match.accountName = 'Test Account';
        match.ownerName = 'John Doe';
        match.matterId = '500000000000001';
        match.matterStatus = 'Open';
        match.riskScore = 95;
        match.riskLevel = 'Critical';
        match.nameUrl = '/003000000000001';

        System.assertEquals('003000000000001', match.id);
        System.assertEquals('Test Match', match.name);
        System.assertEquals('Contact', match.recordType);
        System.assertEquals('Email', match.matchType);
        System.assertEquals('Exact email match', match.matchReason);
        System.assertEquals('test@test.com', match.email);
        System.assertEquals('555-123-4567', match.phone);
        System.assertEquals('Test Account', match.accountName);
        System.assertEquals('John Doe', match.ownerName);
        System.assertEquals('500000000000001', match.matterId);
        System.assertEquals('Open', match.matterStatus);
        System.assertEquals(95, match.riskScore);
        System.assertEquals('Critical', match.riskLevel);
        System.assertEquals('/003000000000001', match.nameUrl);
    }
}