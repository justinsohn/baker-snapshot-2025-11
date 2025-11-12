@isTest
private class ClioAsyncIntegrationRescheduleTest {
    private class StubSchedulableContext implements SchedulableContext {
        public String getTriggerId() {
            return null;
        }
    }

    private class DummySchedulable implements Schedulable {
        public void execute(SchedulableContext ctx) {
        }
    }

    private static CronTrigger buildCronTrigger(Id jobId, DateTime startTime, DateTime nextFireTime) {
        String json = '{' +
            '"Id":"' + String.valueOf(jobId) + '",' +
            '"StartTime":"' + startTime.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'') + '",' +
            (nextFireTime == null ? '"NextFireTime":null' : '"NextFireTime":"' + nextFireTime.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'') + '"') +
            '}';
        return (CronTrigger)System.JSON.deserialize(json, CronTrigger.class);
    }

    private static CronTrigger buildSyntheticCronTrigger(DateTime startTime, DateTime nextFireTime) {
        String json = '{' +
            '"Id":"08e000000000001AAA",' +
            '"StartTime":"' + startTime.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'') + '",' +
            (nextFireTime == null ? '"NextFireTime":null' : '"NextFireTime":"' + nextFireTime.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'') + '"') +
            '}';
        return (CronTrigger)System.JSON.deserialize(json, CronTrigger.class);
    }

    @isTest
    static void executesWhenNoJobsExist() {
        ClioAsyncIntegrationReschedule.testNow = null;
        ClioAsyncIntegrationReschedule.forceSyncFailure = false;
        ClioAsyncIntegrationReschedule.testCronResultsSequence = new List<List<CronTrigger>>{
            new List<CronTrigger>(),
            new List<CronTrigger>()
        };
        Test.setMock(HttpCalloutMock.class, new ClioIntServiceQueueableMock());

        Test.startTest();
        Integer beforeJobs = Limits.getQueueableJobs();
        new ClioAsyncIntegrationReschedule().execute(new StubSchedulableContext());
        Integer afterJobs = Limits.getQueueableJobs();
        Test.stopTest();

        ClioAsyncIntegrationReschedule.testCronResultsSequence = null;
        System.assertEquals(beforeJobs + 1, afterJobs, 'Expected the reschedule logic to enqueue a queueable job when no cron jobs exist');
    }

    @isTest
    static void skipsEnqueueWhenJobExists() {
        ClioAsyncIntegrationReschedule.testNow = null;
        ClioAsyncIntegrationReschedule.forceSyncFailure = false;
        DateTime startTime = DateTime.now().addMinutes(10);
        DateTime nextFire = DateTime.now().addHours(1);
        CronTrigger activeCron = buildSyntheticCronTrigger(startTime, nextFire);
        ClioAsyncIntegrationReschedule.testCronResultsSequence = new List<List<CronTrigger>>{
            new List<CronTrigger>{ activeCron },
            new List<CronTrigger>{ activeCron }
        };

        Test.startTest();
        Integer beforeJobs = Limits.getQueueableJobs();
        new ClioAsyncIntegrationReschedule().execute(new StubSchedulableContext());
        Integer afterJobs = Limits.getQueueableJobs();
        Test.stopTest();

        ClioAsyncIntegrationReschedule.testCronResultsSequence = null;
        System.assertEquals(beforeJobs, afterJobs, 'No queueable job should be enqueued when an active cron job already exists');
    }

    @isTest
    static void abortsStaleCronJobAndTriggersSync() {
        String cron = '0 0 0 1 1 ? 2099';
        Id jobId = System.schedule('Test Clio Async Integration', cron, new DummySchedulable());
        DateTime pastStart = DateTime.now().addHours(-2);
        ClioAsyncIntegrationReschedule.testNow = DateTime.now();
        ClioAsyncIntegrationReschedule.forceSyncFailure = false;
        ClioAsyncIntegrationReschedule.testCronResultsSequence = new List<List<CronTrigger>>{
            new List<CronTrigger>{ buildCronTrigger(jobId, pastStart, null) },
            new List<CronTrigger>()
        };
        Test.setMock(HttpCalloutMock.class, new ClioIntServiceQueueableMock());

        Test.startTest();
        new ClioAsyncIntegrationReschedule().execute(new StubSchedulableContext());
        Test.stopTest();

        ClioAsyncIntegrationReschedule.testCronResultsSequence = null;
        ClioAsyncIntegrationReschedule.testNow = null;
        List<CronTrigger> stateCheck = [SELECT Id, State FROM CronTrigger WHERE Id = :jobId];
        Boolean jobRemoved = stateCheck.isEmpty();
        Boolean jobDeleted = !jobRemoved && stateCheck[0].State == 'DELETED';
        System.assert(jobRemoved || jobDeleted, 'Expected the stale cron job to be aborted or removed');
    }

    @isTest
    static void handlesForcedSyncFailureGracefully() {
        ClioAsyncIntegrationReschedule.testNow = null;
        ClioAsyncIntegrationReschedule.forceSyncFailure = true;
        ClioAsyncIntegrationReschedule.testCronResultsSequence = new List<List<CronTrigger>>{
            new List<CronTrigger>(),
            new List<CronTrigger>()
        };

        Test.startTest();
        new ClioAsyncIntegrationReschedule().execute(new StubSchedulableContext());
        Test.stopTest();

        ClioAsyncIntegrationReschedule.forceSyncFailure = false;
        ClioAsyncIntegrationReschedule.testCronResultsSequence = null;
        System.assertEquals(0, Limits.getQueueableJobs(), 'No queueable jobs should be enqueued when forced failure occurs');
    }
}