public with sharing class ClioAsyncIntegrationScheduler implements Schedulable {

    public void execute(SchedulableContext ctx) {
        try {
            System.debug('=== SCHEDULED CLIO SYNC STARTED ===');
            System.debug('Execution time: ' + DateTime.now());
            ClioDataRetrieveService.syncUsers(null);
            
        } catch (Exception e) {
            System.debug('SCHEDULED SYNC FAILED: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            
        }
    }
    
    // Utility method to schedule the job
    public static String scheduleSync(Integer minutesFromNow) {
        DateTime scheduleTime = DateTime.now().addMinutes(minutesFromNow);
        String cronExpression = scheduleTime.format('s m H d M ? yyyy');
        
        String jobName = Test.isRunningTest()? 'Test Clio Async Integration' : 'Clio Async Integration';
        ClioAsyncIntegrationScheduler scheduler = new ClioAsyncIntegrationScheduler(); //select id from CronTrigger where CronJobDetail.Name = 'Program Status Update Cron Job'
        List<CronTrigger> cronjobs = [Select Id from CronTrigger where CronJobDetail.Name = :jobName];
        for(CronTrigger c : cronjobs){
            system.abortJob(c.Id);
        }
        String jobId = System.schedule(jobName, cronExpression, scheduler);
        
        System.debug('✅ Scheduled Clio Async Integration job: ' + jobName);
        System.debug('Job ID: ' + jobId);
        System.debug('Will run at: ' + scheduleTime);
        
        return jobId;
    }
}