public class ConvertLeadApex {

    @InvocableMethod(label='Convert Lead' description='Converts a lead into an account, a contact, and optionally an opportunity.')
    public static List<LeadConversionResult> convertLead(List<LeadConversionRequest> requests) {
        List<LeadConversionResult> results = new List<LeadConversionResult>();
        
        System.debug('=== INVOCABLE METHOD START ===');
        System.debug('Number of requests received: ' + requests.size());

        for (LeadConversionRequest request : requests) {
            System.debug('Processing request for Lead ID: ' + request.leadID);
            LeadConversionResult result = new LeadConversionResult();
            try {
                // Set the default handling for booleans.
                if (request.overWriteLeadSource == null) request.overWriteLeadSource = false;
                if (request.createOpportunity == null) request.createOpportunity = true;
                if (request.sendEmailToOwner == null) request.sendEmailToOwner = false;

                // Convert the lead by passing it to a helper method.
                Map<String,String> conversionResult = convertLead(request.leadID, request.contactID, request.accountID, 
                    request.convertedStatus, request.overWriteLeadSource, request.createOpportunity, 
                    request.opportunityName, request.sendEmailToOwner);

                result.accountID = conversionResult.get('AccountID');
                result.contactID = conversionResult.get('ContactID');
                result.opportunityID = conversionResult.get('OpportunityID');
                System.debug('Conversion successful for Lead ID: ' + request.leadID);
            } catch (Exception e) {
                result.errorMessage = e.getMessage();
                System.debug('Exception occurred for Lead ID ' + request.leadID + ': ' + e.getMessage());
                System.debug('Exception Stack Trace: ' + e.getStackTraceString());
            }
            results.add(result);
        }
        System.debug('=== INVOCABLE METHOD END ===');
        return results;
    }

    public static Map<String,String> convertLead (
        String leadID,
        String contactID,
        String accountID,
        String convertedStatus,
        Boolean overWriteLeadSource,
        Boolean createOpportunity,
        String opportunityName,
        Boolean sendEmailToOwner
    ) {
        Map<String,String> result = new Map<String,String>();
        
        // Debug input parameters
        System.debug('=== LEAD CONVERSION DEBUG START ===');
        System.debug('Lead ID: ' + leadID);
        System.debug('Contact ID: ' + contactID);
        System.debug('Account ID: ' + accountID);
        System.debug('Converted Status: ' + convertedStatus);
        System.debug('Overwrite Lead Source: ' + overWriteLeadSource);
        System.debug('Create Opportunity: ' + createOpportunity);
        System.debug('Opportunity Name: ' + opportunityName);
        System.debug('Send Email to Owner: ' + sendEmailToOwner);

        if (leadID == null) throw new ConvertLeadPluginException('Lead Id cannot be null');

        // Check for multiple leads with the same ID
        Lead[] leads = [Select Id, FirstName, LastName, Company From Lead where Id = :leadID];
        System.debug('Leads found: ' + leads.size());
        
        if (leads.size() > 0) {
            Lead l = leads[0];
            System.debug('Lead details - Name: ' + l.FirstName + ' ' + l.LastName + ', Company: ' + l.Company);
            
            // CheckAccount = true, checkContact = false
            if (accountID == null && l.Company != null) {
                System.debug('Looking for existing account with name: ' + l.Company);
                Account[] accounts = [Select Id, Name FROM Account where Name = :l.Company LIMIT 1];
                System.debug('Accounts found with company name: ' + accounts.size());
                if (accounts.size() > 0) {
                    accountID = accounts[0].Id;
                    System.debug('Using existing account ID: ' + accountID);
                }
            }

            // Perform the lead conversion.
            System.debug('Starting lead conversion process...');
            Database.LeadConvert lc = new Database.LeadConvert();
            lc.setLeadId(leadID);
            lc.setOverwriteLeadSource(overWriteLeadSource);
            lc.setDoNotCreateOpportunity(!createOpportunity);
            lc.setConvertedStatus(convertedStatus);
            if (sendEmailToOwner != null) lc.setSendNotificationEmail(sendEmailToOwner);
            if (accountID != null && accountID.length() > 0) {
                lc.setAccountId(accountID);
                System.debug('Setting Account ID for conversion: ' + accountID);
            }
            if (contactID != null && contactID.length() > 0) {
                lc.setContactId(contactID);
                System.debug('Setting Contact ID for conversion: ' + contactID);
            }
            if (createOpportunity && opportunityName != null) {
                lc.setOpportunityName(opportunityName);
                System.debug('Setting Opportunity Name: ' + opportunityName);
            }

            System.debug('Executing Database.convertLead...');
            Database.LeadConvertResult lcr = Database.convertLead(lc, true);
            if (lcr.isSuccess()) {
                System.debug('Lead conversion successful!');
                System.debug('Converted Account ID: ' + lcr.getAccountId());
                System.debug('Converted Contact ID: ' + lcr.getContactId());
                System.debug('Converted Opportunity ID: ' + lcr.getOpportunityId());
                
                result.put('AccountID', lcr.getAccountId());
                result.put('ContactID', lcr.getContactId());
                if (createOpportunity) {
                    result.put('OpportunityID', lcr.getOpportunityId());
                }
            } else {
                System.debug('Lead conversion failed!');
                Database.Error[] errors = lcr.getErrors();
                for (Database.Error error : errors) {
                    System.debug('Conversion Error: ' + error.getMessage());
                    System.debug('Error Fields: ' + error.getFields());
                    System.debug('Error Status Code: ' + error.getStatusCode());
                }
                String error = errors[0].getMessage();
                throw new ConvertLeadPluginException(error);
            }
        } else { 
            System.debug('ERROR: No leads found with the provided ID');
            throw new ConvertLeadPluginException('No leads found with Id : "' + leadID + '"');
        }
        
        System.debug('Returning result: ' + result);
        System.debug('=== LEAD CONVERSION DEBUG END ===');
        return result;
    }

    public class LeadConversionRequest {
        @InvocableVariable(required=true)
        public String leadID;
        @InvocableVariable
        public String contactID;
        @InvocableVariable
        public String accountID;
        @InvocableVariable(required=true)
        public String convertedStatus;
        @InvocableVariable
        public Boolean overWriteLeadSource;
        @InvocableVariable
        public Boolean createOpportunity;
        @InvocableVariable
        public String opportunityName;
        @InvocableVariable
        public Boolean sendEmailToOwner;
    }

    public class LeadConversionResult {
        @InvocableVariable
        public String accountID;
        @InvocableVariable
        public String contactID;
        @InvocableVariable
        public String opportunityID;
        @InvocableVariable
        public String errorMessage;
    }

    // Utility exception class
    public class ConvertLeadPluginException extends Exception {}
}