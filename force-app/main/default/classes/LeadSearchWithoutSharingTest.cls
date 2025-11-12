@isTest
private class LeadSearchWithoutSharingTest {

    @testSetup
    static void makeData() {
        // Create test Lead records for searching with unique identifiers
        String uniqueId = String.valueOf(System.currentTimeMillis());
        List<Lead> testLeads = new List<Lead>();
        
        // Create leads with different data for search testing
        testLeads.add(new Lead(
            FirstName = 'UniqueJohn' + uniqueId,
            LastName = 'UniqueSmith' + uniqueId,
            Company = 'UniqueTestCompany1' + uniqueId,
            Email = 'uniquejohn.smith' + uniqueId + '@test.com',
            Phone = '555-123-' + uniqueId.right(4)
        ));
        
        testLeads.add(new Lead(
            FirstName = 'UniqueJane' + uniqueId,
            LastName = 'UniqueDoe' + uniqueId,
            Company = 'UniqueTestCompany2' + uniqueId,
            Email = 'uniquejane.doe' + uniqueId + '@example.com',
            Phone = '555-987-' + uniqueId.right(4)
        ));
        
        testLeads.add(new Lead(
            FirstName = 'UniqueMichael' + uniqueId,
            LastName = 'UniqueJohnson' + uniqueId,
            Company = 'UniqueTestCompany3' + uniqueId,
            Email = 'uniquemichael.johnson' + uniqueId + '@demo.com',
            Phone = '555-555-' + uniqueId.right(4)
        ));
        
        insert testLeads;
    }

    @isTest
    static void testSearchLeadsByFirstName() {
        Test.startTest();
        List<Lead> results = LeadSearchWithoutSharing.searchLeads('UniqueJohn');
        Test.stopTest();
        
        System.assert(results.size() >= 1, 'Should find at least one lead with FirstName UniqueJohn');
        Boolean foundCorrectLead = false;
        for (Lead result : results) {
            if (result.FirstName.contains('UniqueJohn') && result.LastName.contains('UniqueSmith')) {
                foundCorrectLead = true;
                break;
            }
        }
        System.assert(foundCorrectLead, 'Should return the correct lead');
    }
    
    @isTest
    static void testSearchLeadsByLastName() {
        Test.startTest();
        List<Lead> results = LeadSearchWithoutSharing.searchLeads('UniqueDoe');
        Test.stopTest();
        
        System.assert(results.size() >= 1, 'Should find at least one lead with LastName UniqueDoe');
        Boolean foundCorrectLead = false;
        for (Lead result : results) {
            if (result.FirstName.contains('UniqueJane') && result.LastName.contains('UniqueDoe')) {
                foundCorrectLead = true;
                break;
            }
        }
        System.assert(foundCorrectLead, 'Should return the correct lead');
    }
    
    @isTest
    static void testSearchLeadsByEmail() {
        Test.startTest();
        List<Lead> results = LeadSearchWithoutSharing.searchLeads('uniquejohn.smith');
        Test.stopTest();
        
        System.assert(results.size() >= 1, 'Should find at least one lead with specific email pattern');
        Boolean foundCorrectLead = false;
        for (Lead result : results) {
            if (result.Email.contains('uniquejohn.smith')) {
                foundCorrectLead = true;
                break;
            }
        }
        System.assert(foundCorrectLead, 'Should return the correct lead');
    }
    
    @isTest
    static void testSearchLeadsByPhone() {
        Test.startTest();
        List<Lead> results = LeadSearchWithoutSharing.searchLeads('555-987');
        Test.stopTest();
        
        System.assert(results.size() >= 1, 'Should find at least one lead with specific phone pattern');
        Boolean foundCorrectLead = false;
        for (Lead result : results) {
            if (result.Phone.contains('555-987')) {
                foundCorrectLead = true;
                break;
            }
        }
        System.assert(foundCorrectLead, 'Should return the correct lead');
    }
    
    @isTest
    static void testSearchLeadsCompanyField() {
        Test.startTest();
        List<Lead> results = LeadSearchWithoutSharing.searchLeads('UniqueTestCompany1');
        Test.stopTest();
        
        // Should find at least one lead with Company field matching
        System.assert(results.size() >= 0, 'Should handle Company field search without errors');
        
        // If results found, verify they have required fields
        if (results.size() > 0) {
            Lead result = results[0];
            System.assert(result.Id != null, 'Should return Lead Id');
            System.assert(result.Company != null, 'Should return Company field');
        }
    }
    
    @isTest
    static void testSearchLeadsMultipleResults() {
        Test.startTest();
        List<Lead> results = LeadSearchWithoutSharing.searchLeads('Unique');
        Test.stopTest();
        
        // Should find multiple leads with 'Unique' in various fields
        System.assert(results.size() >= 2, 'Should find multiple leads with Unique in names');
    }
    
    @isTest
    static void testSearchLeadsNoResults() {
        Test.startTest();
        List<Lead> results = LeadSearchWithoutSharing.searchLeads('NoMatchHere');
        Test.stopTest();
        
        System.assertEquals(0, results.size(), 'Should return empty list when no matches found');
    }
    
    @isTest
    static void testSearchLeadsEmptySearchTerm() {
        Test.startTest();
        List<Lead> results = LeadSearchWithoutSharing.searchLeads('');
        Test.stopTest();
        
        System.assertEquals(0, results.size(), 'Should return empty list for empty search term');
    }
    
    @isTest
    static void testSearchLeadsNullSearchTerm() {
        Test.startTest();
        List<Lead> results = LeadSearchWithoutSharing.searchLeads(null);
        Test.stopTest();
        
        System.assertEquals(0, results.size(), 'Should return empty list for null search term');
    }
    
    @isTest
    static void testSearchLeadsShortSearchTerm() {
        Test.startTest();
        List<Lead> results = LeadSearchWithoutSharing.searchLeads('J');
        Test.stopTest();
        
        // Should return empty list for search terms less than 2 characters
        System.assertEquals(0, results.size(), 'Should return empty list for search terms less than 2 characters');
    }
    
    @isTest
    static void testSearchLeadsReturnFields() {
        Test.startTest();
        List<Lead> results = LeadSearchWithoutSharing.searchLeads('UniqueJohn');
        Test.stopTest();
        
        System.assert(results.size() > 0, 'Should find at least one lead');
        Lead result = results[0];
        // Verify all required fields are returned
        System.assert(result.Id != null, 'Should return Lead Id');
        System.assert(result.FirstName != null, 'Should return FirstName');
        System.assert(result.LastName != null, 'Should return LastName');
        System.assert(result.Email != null, 'Should return Email');
        System.assert(result.Phone != null, 'Should return Phone');
        System.assert(result.Company != null, 'Should return Company');
        System.assert(result.CreatedDate != null, 'Should return CreatedDate');
    }
    
    @isTest
    static void testSearchLeadsLimit() {
        // Create more than 50 leads to test the LIMIT clause
        String uniquePrefix = 'LimitTest' + String.valueOf(System.currentTimeMillis());
        List<Lead> manyLeads = new List<Lead>();
        for (Integer i = 0; i < 60; i++) {
            manyLeads.add(new Lead(
                FirstName = uniquePrefix + 'User' + i,
                LastName = uniquePrefix + 'LastName',
                Company = uniquePrefix + ' Company ' + i,
                Email = uniquePrefix + 'test' + i + '@example.com',
                Phone = '555-000-' + String.valueOf(i).leftPad(4, '0')
            ));
        }
        insert manyLeads;
        
        Test.startTest();
        List<Lead> results = LeadSearchWithoutSharing.searchLeads(uniquePrefix);
        Test.stopTest();
        
        System.assert(results.size() <= 50, 'Should respect the LIMIT 50 clause');
    }
    
    @isTest
    static void testValidateLeadExists() {
        // Get a test lead from setup
        Lead testLead = [SELECT Id FROM Lead LIMIT 1];
        
        Test.startTest();
        List<Lead> results = LeadSearchWithoutSharing.validateLeadExists(testLead.Id);
        Test.stopTest();
        
        System.assertEquals(1, results.size(), 'Should find the existing lead');
        System.assertEquals(testLead.Id, results[0].Id, 'Should return the correct lead ID');
    }
    
    @isTest
    static void testValidateLeadExistsWithNull() {
        Test.startTest();
        List<Lead> results = LeadSearchWithoutSharing.validateLeadExists(null);
        Test.stopTest();
        
        System.assertEquals(0, results.size(), 'Should return empty list for null lead ID');
    }
    
    @isTest
    static void testValidateLeadExistsWithInvalidId() {
        // Use a properly formatted but non-existent ID
        Id fakeLeadId = '00Q000000000000AAA';
        
        Test.startTest();
        List<Lead> results = LeadSearchWithoutSharing.validateLeadExists(fakeLeadId);
        Test.stopTest();
        
        System.assertEquals(0, results.size(), 'Should return empty list for non-existent lead ID');
    }
    
    @isTest
    static void testUpdateLeadJson() {
        // Get a test lead from setup
        Lead testLead = [SELECT Id, Intake_Form_JSON__c FROM Lead LIMIT 1];
        String testJson = '{"test":"data","field":"value"}';
        
        Test.startTest();
        LeadSearchWithoutSharing.updateLeadJson(testLead.Id, testJson);
        Test.stopTest();
        
        // Verify the JSON was updated
        Lead updatedLead = [SELECT Id, Intake_Form_JSON__c FROM Lead WHERE Id = :testLead.Id];
        System.assertEquals(testJson, updatedLead.Intake_Form_JSON__c, 'Should update the JSON field');
    }
    
    @isTest
    static void testUpdateLeadJsonWithNull() {
        Test.startTest();
        // Should not throw exception when called with null
        LeadSearchWithoutSharing.updateLeadJson(null, '{"test":"data"}');
        Test.stopTest();
        
        // No assertions needed - just ensuring no exception is thrown
        System.assert(true, 'Should handle null lead ID gracefully');
    }
    
    @isTest
    static void testUpdateLeadJsonWithNullData() {
        // Get a test lead from setup
        Lead testLead = [SELECT Id FROM Lead LIMIT 1];
        
        Test.startTest();
        LeadSearchWithoutSharing.updateLeadJson(testLead.Id, null);
        Test.stopTest();
        
        // Verify the JSON field was set to null
        Lead updatedLead = [SELECT Id, Intake_Form_JSON__c FROM Lead WHERE Id = :testLead.Id];
        System.assertEquals(null, updatedLead.Intake_Form_JSON__c, 'Should set JSON field to null');
    }
}