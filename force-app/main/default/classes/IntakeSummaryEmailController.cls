public with sharing class IntakeSummaryEmailController {
    
    @AuraEnabled
    public static List<User> getActiveUsers() {
        try {
            return [
                SELECT Id, Name, Email, Title, Department
                FROM User 
                WHERE IsActive = true 
                AND Email != null
                ORDER BY Name ASC
                LIMIT 200
            ];
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching users: ' + e.getMessage());
        }
    }
    
    @AuraEnabled
    public static void sendIntakeSummaryEmail(Id leadId, List<Id> userIds, String emailSubject, String emailBody) {
        try {
            if (userIds == null || userIds.isEmpty()) {
                throw new AuraHandledException('Please select at least one user to email.');
            }
            
            // Get lead information
            Lead leadRecord = [SELECT Id, Name, Email, Phone, Company FROM Lead WHERE Id = :leadId LIMIT 1];
            
            // Get user email addresses
            List<User> users = [SELECT Id, Email FROM User WHERE Id IN :userIds AND IsActive = true];
            List<String> toAddresses = new List<String>();
            for (User user : users) {
                if (user.Email != null) {
                    toAddresses.add(user.Email);
                }
            }
            
            if (toAddresses.isEmpty()) {
                throw new AuraHandledException('No valid email addresses found for selected users.');
            }
            
            // Create and send email
            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
            email.setToAddresses(toAddresses);
            email.setSubject(emailSubject);
            email.setHtmlBody(emailBody);
            
            Messaging.SendEmailResult[] results = Messaging.sendEmail(new Messaging.SingleEmailMessage[]{ email });
            
            if (!results[0].isSuccess()) {
                throw new AuraHandledException('Failed to send email: ' + results[0].getErrors()[0].getMessage());
            }
            
        } catch (AuraHandledException e) {
            // Re-throw AuraHandledException as-is to preserve the original message
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException('Error sending email: ' + e.getMessage());
        }
    }
}