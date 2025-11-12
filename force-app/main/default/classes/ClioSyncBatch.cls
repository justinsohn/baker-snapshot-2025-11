public with sharing class ClioSyncBatch implements Database.Batchable<String>, Database.AllowsCallouts {
    
    private String objectType;
    private String lastSyncTime;
    
    public ClioSyncBatch(String objectType) {
        this.objectType = objectType;
        this.lastSyncTime = ClioIntegrationService.getLastSyncTime(objectType);
    }
    
    public List<String> start(Database.BatchableContext context) {
        return new List<String>{ objectType };
    }
    
    public void execute(Database.BatchableContext context, List<String> scope) {
        try {
            for (String objType : scope) {
                switch on objType {
                    when 'User' {
                        ClioSyncService.syncUsers(lastSyncTime);
                    }
                    when 'Contact' {
                        ClioSyncService.syncContacts(lastSyncTime);
                    }
                    when 'Matter' {
                        ClioSyncService.syncMatters(lastSyncTime);
                    }
                    when 'TimeEntry' {
                        ClioSyncService.syncTimeEntries(lastSyncTime);
                    }
                    when 'Bill' {
                        ClioSyncService.syncBills(lastSyncTime);
                    }
                    when 'Calendar' {
                        ClioSyncService.syncCalendarEntries(lastSyncTime);
                    }
                    when 'Payment' {
                        ClioSyncService.syncPayments(lastSyncTime);
                    }
                }
            }
        } catch (Exception e) {
            System.debug('Error in ClioSyncBatch: ' + e.getMessage());
            sendErrorEmail(e);
        }
    }
    
    public void finish(Database.BatchableContext context) {
        System.debug('ClioSyncBatch completed for: ' + objectType);
    }
    
    private void sendErrorEmail(Exception e) {
        List<String> toAddresses = new List<String>();
        toAddresses.add(UserInfo.getUserEmail());
        
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setToAddresses(toAddresses);
        mail.setSubject('Clio Sync Error - ' + objectType);
        mail.setPlainTextBody('An error occurred during Clio sync for ' + objectType + ':\n\n' + 
                            'Error Message: ' + e.getMessage() + '\n' +
                            'Stack Trace: ' + e.getStackTraceString());
        
        try {
            Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ mail });
        } catch (Exception emailEx) {
            System.debug('Failed to send error email: ' + emailEx.getMessage());
        }
    }
}