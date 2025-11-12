public class EmailHandlerInvoiceProcessor implements Messaging.InboundEmailHandler {

    public Messaging.InboundEmailResult handleInboundEmail(Messaging.InboundEmail email, Messaging.InboundEnvelope envelope) {
        Messaging.InboundEmailResult result = new Messaging.InboundEmailResult();

        try {
            String emailBody = getEmailBody(email);
            String invoiceNumber = extractInvoiceNumber(emailBody);

            if (String.isNotBlank(invoiceNumber)) {
                processInvoicePayment(invoiceNumber);
                result.success = true;
                System.debug('Successfully processed invoice: ' + invoiceNumber);
            } else {
                result.success = false;
                result.message = 'No valid Trust Request or Invoice number found in email body';
                System.debug('No valid invoice number found in email: ' + emailBody);
            }

        } catch (Exception e) {
            result.success = false;
            result.message = 'Error processing email: ' + e.getMessage();
            System.debug('Error in EmailHandlerInvoiceProcessor: ' + e.getMessage() + '\n' + e.getStackTraceString());
        }

        return result;
    }

    @TestVisible
    private String getEmailBody(Messaging.InboundEmail email) {
        String emailBody = '';

        if (String.isNotBlank(email.plainTextBody)) {
            emailBody = email.plainTextBody;
        } else if (String.isNotBlank(email.htmlBody)) {
            emailBody = email.htmlBody.stripHtmlTags();
        }

        return emailBody != null ? emailBody : '';
    }

    @TestVisible
    private String extractInvoiceNumber(String emailBody) {
        if (String.isBlank(emailBody)) {
            return null;
        }

        String emailBodyLower = emailBody.toLowerCase();
        Set<String> foundNumbers = new Set<String>();

        // Updated patterns to handle optional # symbol and various spacing
        Pattern trustRequestPattern = Pattern.compile('trust request\\s*#?\\s*(\\d+)');
        Pattern invoicePattern = Pattern.compile('invoice\\s*#?\\s*(\\d+)');

        // Find all Trust Request numbers first (higher priority)
        Matcher trustMatcher = trustRequestPattern.matcher(emailBodyLower);
        while (trustMatcher.find()) {
            foundNumbers.add(trustMatcher.group(1));
        }

        // If no Trust Request found, look for Invoice numbers
        if (foundNumbers.isEmpty()) {
            Matcher invoiceMatcher = invoicePattern.matcher(emailBodyLower);
            while (invoiceMatcher.find()) {
                foundNumbers.add(invoiceMatcher.group(1));
            }
        }

        // Return the first number found (deduplication handled by Set)
        if (!foundNumbers.isEmpty()) {
            List<String> numberList = new List<String>(foundNumbers);
            return numberList[0];
        }

        return null;
    }

    private void processInvoicePayment(String invoiceNumber) {
        List<Invoice__c> invoices = [
            SELECT Id, Matter__c
            FROM Invoice__c
            WHERE Invoice_Number__c = :invoiceNumber
            LIMIT 1
        ];

        if (invoices.isEmpty()) {
            throw new EmailProcessingException('No Invoice found with number: ' + invoiceNumber);
        }

        Invoice__c invoice = invoices[0];

        if (String.isBlank(invoice.Matter__c)) {
            throw new EmailProcessingException('Invoice ' + invoiceNumber + ' has no associated Matter');
        }

        List<Matter__c> matters = [
            SELECT Id, Date_First_Payment__c
            FROM Matter__c
            WHERE Id = :invoice.Matter__c
            LIMIT 1
        ];

        if (matters.isEmpty()) {
            throw new EmailProcessingException('Matter not found for Invoice: ' + invoiceNumber);
        }

        Matter__c matter = matters[0];
        matter.Date_First_Payment__c = Date.today();

        update matter;

        System.debug('Updated Matter ' + matter.Id + ' with Date_First_Payment__c: ' + Date.today());
    }

    public class EmailProcessingException extends Exception {}
}