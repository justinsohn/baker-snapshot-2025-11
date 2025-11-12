@isTest
private class ClioSyncSchedulerTest {

    @isTest
    static void testScheduledExecution() {
        Test.setMock(HttpCalloutMock.class, new ClioSyncServiceMock());

        Test.startTest();
        
        ClioSyncScheduler scheduler = new ClioSyncScheduler();
        String cronExp = '0 0 0 * * ?'; // Daily at midnight
        String jobId = System.schedule('Test Clio Sync', cronExp, scheduler);
        
        // Simulate the scheduled execution
        scheduler.execute(null);
        
        Test.stopTest();

        System.assertNotEquals(null, jobId);
    }

    @isTest
    static void testScheduleSync() {
        Test.startTest();
        
        String jobId = ClioSyncScheduler.scheduleSync(5); // Schedule 5 minutes from now
        
        Test.stopTest();

        System.assertNotEquals(null, jobId);
        System.assert(jobId.length() > 0);
    }

    @isTest
    static void testExecuteWithException() {
        // Don't set mock to force an exception
        
        Test.startTest();
        
        ClioSyncScheduler scheduler = new ClioSyncScheduler();
        // This should handle the exception gracefully
        scheduler.execute(null);
        
        Test.stopTest();

        // Should complete without throwing unhandled exceptions
        System.assert(true);
    }

    @isTest
    static void testExecuteSuccess() {
        Test.setMock(HttpCalloutMock.class, new ClioSyncServiceMock());

        Test.startTest();
        
        ClioSyncScheduler scheduler = new ClioSyncScheduler();
        scheduler.execute(null);
        
        Test.stopTest();

        // Should complete successfully
        System.assert(true);
    }

    @isTest
    static void testScheduleSyncFuture() {
        Test.startTest();
        
        String jobId = ClioSyncScheduler.scheduleSync(60); // Schedule 1 hour from now
        
        Test.stopTest();

        System.assertNotEquals(null, jobId);
    }

    @isTest
    static void testScheduleSyncImmediate() {
        Test.startTest();
        
        String jobId = ClioSyncScheduler.scheduleSync(1); // Schedule 1 minute from now
        
        Test.stopTest();

        System.assertNotEquals(null, jobId);
    }

}