@isTest
private class ClioSyncServiceTest {

    @isTest
    static void testSyncUsers() {
        // Create mock data and callouts
        Test.setMock(HttpCalloutMock.class, new ClioSyncServiceMock());

        // Create a user to update
        User u = new User(
            FirstName = 'Test',
            LastName = 'User',
            Email = 'test@user.com',
            Username = 'test@user.com' + System.currentTimeMillis(),
            Alias = 'tuser',
            CommunityNickname = 'Test User',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1].Id,
            LanguageLocaleKey = 'en_US'
        );
        insert u;

        // Call the method to test
        Test.startTest();
        ClioSyncService.syncUsers(null);
        Test.stopTest();

        // Assertions
        List<User> users = [SELECT Id, Clio_Id__c FROM User WHERE Email = 'test@user.com'];
        System.assertEquals(1, users.size());
        System.assertEquals('12345', users[0].Clio_Id__c);
    }

}