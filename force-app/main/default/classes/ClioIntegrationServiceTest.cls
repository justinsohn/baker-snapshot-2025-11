@isTest
private class ClioIntegrationServiceTest {

    @isTest
    static void testMakeCallout() {
        // Create mock data and callouts
        Test.setMock(HttpCalloutMock.class, new ClioSyncServiceMock());

        // Call the method to test
        Test.startTest();
        HttpResponse res = ClioIntegrationService.makeCallout('/users', 'GET', null);
        Test.stopTest();

        // Assertions
        System.assertEquals(200, res.getStatusCode());
    }

}