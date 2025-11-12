@isTest
private class UserAvailabilityControllerTest {
    
    @testSetup
    static void makeData() {
        // Create test users with different availability statuses and practice areas
        List<User> testUsers = new List<User>();
        
        // Get a profile to use for test users
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' OR Name = 'System Administrator' LIMIT 1];
        
        // Create users with different availability statuses
        testUsers.add(new User(
            FirstName = 'Green',
            LastName = 'User1',
            Email = 'green1@test.com',
            Username = 'green1@test' + System.currentTimeMillis() + '.com',
            Alias = 'green1',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = p.Id,
            IsActive = true,
            Weekly_Availability__c = 'Green',
            Practice_Area__c = 'Corporate'
        ));
        
        testUsers.add(new User(
            FirstName = 'Yellow',
            LastName = 'User1',
            Email = 'yellow1@test.com',
            Username = 'yellow1@test' + System.currentTimeMillis() + '.com',
            Alias = 'yellow1',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = p.Id,
            IsActive = true,
            Weekly_Availability__c = 'Yellow',
            Practice_Area__c = 'Litigation'
        ));
        
        testUsers.add(new User(
            FirstName = 'Red',
            LastName = 'User1',
            Email = 'red1@test.com',
            Username = 'red1@test' + System.currentTimeMillis() + '.com',
            Alias = 'red1',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = p.Id,
            IsActive = true,
            Weekly_Availability__c = 'Red',
            Practice_Area__c = 'Tax'
        ));
        
        // User with availability but no practice area (should be included)
        testUsers.add(new User(
            FirstName = 'Green',
            LastName = 'NoPractice',
            Email = 'greennopractice@test.com',
            Username = 'greennopractice@test' + System.currentTimeMillis() + '.com',
            Alias = 'greenno',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = p.Id,
            IsActive = true,
            Weekly_Availability__c = 'Green',
            Practice_Area__c = null
        ));
        
        // User with practice area but no availability (should NOT be included)
        testUsers.add(new User(
            FirstName = 'No',
            LastName = 'Availability',
            Email = 'noavail@test.com',
            Username = 'noavail@test' + System.currentTimeMillis() + '.com',
            Alias = 'noavail',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = p.Id,
            IsActive = true,
            Weekly_Availability__c = null,
            Practice_Area__c = 'Corporate'
        ));
        
        // Inactive user (should NOT be included)
        testUsers.add(new User(
            FirstName = 'Inactive',
            LastName = 'User',
            Email = 'inactive@test.com',
            Username = 'inactive@test' + System.currentTimeMillis() + '.com',
            Alias = 'inact',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = p.Id,
            IsActive = false,
            Weekly_Availability__c = 'Green',
            Practice_Area__c = 'Corporate'
        ));
        
        insert testUsers;
    }
    
    @isTest
    static void testGetActiveUsersByPracticeArea_ReturnsUsersWithAvailability() {
        Test.startTest();
        List<User> result = UserAvailabilityController.getActiveUsersByPracticeArea();
        Test.stopTest();
        
        // Verify we got some results
        System.assert(result.size() > 0, 'Should return at least some users');
        
        // Verify users without availability are excluded
        for (User u : result) {
            System.assertNotEquals(null, u.Weekly_Availability__c, 'All returned users should have availability set');
        }
        
        // Count how many of our test users were included
        Integer testUserCount = 0;
        for (User u : result) {
            if (u.FirstName != null && 
                (u.FirstName.startsWith('Green') || 
                 u.FirstName.startsWith('Yellow') || 
                 u.FirstName.startsWith('Red'))) {
                testUserCount++;
            }
        }
        
        // Should include at least 4 test users (all active users with availability)
        System.assert(testUserCount >= 4, 'Should include at least 4 test users with availability');
    }
    
    @isTest
    static void testGetActiveUsersByPracticeArea_ReturnsCorrectUsersInOrder() {
        Test.startTest();
        List<User> result = UserAvailabilityController.getActiveUsersByPracticeArea();
        Test.stopTest();
        
        // Verify the ordering: Green -> Yellow -> Red
        Integer greenIndex = -1;
        Integer yellowIndex = -1;
        Integer redIndex = -1;
        
        for (Integer i = 0; i < result.size(); i++) {
            if (result[i].Weekly_Availability__c == 'Green' && greenIndex == -1) {
                greenIndex = i;
            } else if (result[i].Weekly_Availability__c == 'Yellow' && yellowIndex == -1) {
                yellowIndex = i;
            } else if (result[i].Weekly_Availability__c == 'Red' && redIndex == -1) {
                redIndex = i;
            }
        }
        
        // All Green users should come before Yellow users
        for (User u : result) {
            if (u.Weekly_Availability__c == 'Green') {
                System.assert(result.indexOf(u) < yellowIndex || yellowIndex == -1, 'Green users should come before Yellow users');
            }
        }
        
        // All Yellow users should come before Red users
        for (User u : result) {
            if (u.Weekly_Availability__c == 'Yellow') {
                System.assert(result.indexOf(u) < redIndex || redIndex == -1, 'Yellow users should come before Red users');
            }
        }
    }
    
    @isTest
    static void testGetActiveUsersByPracticeArea_IncludesUsersWithoutPracticeArea() {
        Test.startTest();
        List<User> result = UserAvailabilityController.getActiveUsersByPracticeArea();
        Test.stopTest();
        
        // Find the user without practice area
        Boolean foundUserWithoutPracticeArea = false;
        for (User u : result) {
            if (u.Practice_Area__c == null) {
                foundUserWithoutPracticeArea = true;
                break;
            }
        }
        
        System.assertEquals(true, foundUserWithoutPracticeArea, 'Should include users without practice area if they have availability set');
    }
    
    @isTest
    static void testGetActiveUsersRefresh_ReturnsSameAsMainMethod() {
        Test.startTest();
        List<User> cachedResult = UserAvailabilityController.getActiveUsersByPracticeArea();
        List<User> refreshResult = UserAvailabilityController.getActiveUsersRefresh();
        Test.stopTest();
        
        System.assertEquals(cachedResult.size(), refreshResult.size(), 'Both methods should return the same number of users');
        
        // Verify the same users are returned (may be in same order due to consistent sorting)
        Set<Id> cachedIds = new Set<Id>();
        Set<Id> refreshIds = new Set<Id>();
        
        for (User u : cachedResult) {
            cachedIds.add(u.Id);
        }
        
        for (User u : refreshResult) {
            refreshIds.add(u.Id);
        }
        
        System.assertEquals(cachedIds, refreshIds, 'Both methods should return the same users');
    }
    
    @isTest
    static void testSortUsersByAvailability_ProperOrdering() {
        // This test verifies the private sorting method works correctly
        Test.startTest();
        List<User> result = UserAvailabilityController.getActiveUsersByPracticeArea();
        Test.stopTest();
        
        // Check that within each availability group, users are sorted by LastName, FirstName
        String lastAvailability = '';
        String lastFullName = '';
        
        for (User u : result) {
            String currentFullName = u.LastName + u.FirstName;
            
            if (u.Weekly_Availability__c == lastAvailability) {
                System.assert(currentFullName >= lastFullName, 
                    'Users within same availability should be sorted alphabetically by LastName, FirstName');
            }
            
            lastAvailability = u.Weekly_Availability__c;
            lastFullName = currentFullName;
        }
    }
}