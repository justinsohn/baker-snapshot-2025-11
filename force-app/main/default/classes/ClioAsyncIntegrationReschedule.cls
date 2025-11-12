public with sharing class ClioAsyncIntegrationReschedule implements Schedulable{
    public class ForcedRescheduleException extends Exception {}

    @TestVisible private static DateTime testNow;
    @TestVisible private static Boolean forceSyncFailure = false;
    @TestVisible private static List<List<CronTrigger>> testCronResultsSequence;

    private static DateTime currentTime() {
        return (testNow == null) ? DateTime.now() : testNow;
    }

    private static List<CronTrigger> getCronJobs(String jobName) {
        if (testCronResultsSequence != null && !testCronResultsSequence.isEmpty()) {
            return testCronResultsSequence.remove(0);
        }
        return [Select Id, StartTime, NextFireTime, state from CronTrigger where CronJobDetail.Name = :jobName];
    }

    public void execute(SchedulableContext ctx) {
        try {
            String jobName = Test.isRunningTest()? 'Test Clio Async Integration' : 'Clio Async Integration';
            List<CronTrigger> cronjobs = getCronJobs(jobName);
            for(CronTrigger c : cronjobs){
                if(c.StartTime < currentTime().AddMinutes(-20) && c.NextFireTime == null){
                    system.abortJob(c.Id);
                }
            }
            cronjobs = getCronJobs(jobName);
            if(cronjobs.size() == 0){
                if(forceSyncFailure){
                    throw new ForcedRescheduleException('Forced reschedule failure for testing');
                }
                ClioDataRetrieveService.syncUsers(null);
            }
            
        } catch (Exception e) {
            System.debug('SCHEDULED SYNC FAILED: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            
        }
    }
}