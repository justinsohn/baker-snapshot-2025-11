public class ClioSyncScheduler implements Schedulable {
    
    public void execute(SchedulableContext ctx) {
        try {
            System.debug('SCHEDULED CLIO SYNC STARTED');
            System.debug('Execution time: ' + DateTime.now());
            
            ClioSyncService.syncContacts(null);
            System.debug('Contact sync completed');
            
            ClioSyncService.syncMatters(null);
            System.debug('Matter sync completed');
            
            ClioSyncService.syncTimeEntries(null);
            System.debug('Time Entry sync completed');
            
            ClioSyncService.syncBills(null);
            System.debug('Invoice sync completed');
            
            ClioSyncService.syncPayments(null);
            System.debug('Payment sync completed');
            
            ClioSyncService.syncCalendarEntries(null);
            System.debug('Calendar sync completed');
            
            System.debug('Sync Summary:');
            System.debug('Callouts used: ' + Limits.getCallouts() + ' / ' + Limits.getLimitCallouts());
            System.debug('SOQL queries used: ' + Limits.getQueries() + ' / ' + Limits.getLimitQueries());
            System.debug('DML statements used: ' + Limits.getDMLStatements() + ' / ' + Limits.getLimitDMLStatements());
            
            System.debug('SCHEDULED CLIO SYNC COMPLETED SUCCESSFULLY');
            
        } catch (Exception e) {
            System.debug('SCHEDULED SYNC FAILED: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
        }
    }
    
    public static String scheduleSync(Integer minutesFromNow) {
        DateTime scheduleTime = DateTime.now().addMinutes(minutesFromNow);
        String cronExpression = scheduleTime.format('s m H d M ? yyyy');
        
        String jobName = 'Clio Sync - ' + scheduleTime.format('yyyy-MM-dd HH:mm:ss');
        
        ClioSyncScheduler scheduler = new ClioSyncScheduler();
        String jobId = System.schedule(jobName, cronExpression, scheduler);
        
        System.debug('Scheduled Clio sync job: ' + jobName);
        System.debug('Job ID: ' + jobId);
        System.debug('Will run at: ' + scheduleTime);
        
        return jobId;
    }
}