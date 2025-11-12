@isTest
public class EmailHandlerInvoiceProcessorTest {

    @TestSetup
    static void setupTestData() {
        Matter__c testMatter = new Matter__c(
            Name = 'Test Matter',
            Status__c = 'Active'
        );
        insert testMatter;

        Invoice__c testInvoice = new Invoice__c(
            Name = 'Test Invoice',
            Invoice_Number__c = '12345',
            Matter__c = testMatter.Id
        );
        insert testInvoice;

        Invoice__c testInvoiceNoMatter = new Invoice__c(
            Name = 'Test Invoice No Matter',
            Invoice_Number__c = '99999'
        );
        insert testInvoiceNoMatter;
    }

    @isTest
    static void testHandleInboundEmail_TrustRequest_Success() {
        EmailHandlerInvoiceProcessor handler = new EmailHandlerInvoiceProcessor();

        Messaging.InboundEmail email = new Messaging.InboundEmail();
        email.plainTextBody = 'Please process Trust Request 12345 for payment.';

        Messaging.InboundEnvelope envelope = new Messaging.InboundEnvelope();

        Test.startTest();
        Messaging.InboundEmailResult result = handler.handleInboundEmail(email, envelope);
        Test.stopTest();

        System.assert(result.success, 'Email processing should succeed');

        Matter__c updatedMatter = [SELECT Date_First_Payment__c FROM Matter__c LIMIT 1];
        System.assertEquals(Date.today(), updatedMatter.Date_First_Payment__c, 'Date_First_Payment__c should be set to today');
    }

    @isTest
    static void testHandleInboundEmail_Invoice_Success() {
        EmailHandlerInvoiceProcessor handler = new EmailHandlerInvoiceProcessor();

        Messaging.InboundEmail email = new Messaging.InboundEmail();
        email.plainTextBody = 'Please process Invoice 12345 for payment.';

        Messaging.InboundEnvelope envelope = new Messaging.InboundEnvelope();

        Test.startTest();
        Messaging.InboundEmailResult result = handler.handleInboundEmail(email, envelope);
        Test.stopTest();

        System.assert(result.success, 'Email processing should succeed');

        Matter__c updatedMatter = [SELECT Date_First_Payment__c FROM Matter__c LIMIT 1];
        System.assertEquals(Date.today(), updatedMatter.Date_First_Payment__c, 'Date_First_Payment__c should be set to today');
    }

    @isTest
    static void testHandleInboundEmail_HtmlBody() {
        EmailHandlerInvoiceProcessor handler = new EmailHandlerInvoiceProcessor();

        Messaging.InboundEmail email = new Messaging.InboundEmail();
        email.htmlBody = '<p>Please process <strong>Trust Request 12345</strong> for payment.</p>';

        Messaging.InboundEnvelope envelope = new Messaging.InboundEnvelope();

        Test.startTest();
        Messaging.InboundEmailResult result = handler.handleInboundEmail(email, envelope);
        Test.stopTest();

        System.assert(result.success, 'Email processing should succeed with HTML body');

        Matter__c updatedMatter = [SELECT Date_First_Payment__c FROM Matter__c LIMIT 1];
        System.assertEquals(Date.today(), updatedMatter.Date_First_Payment__c, 'Date_First_Payment__c should be set to today');
    }

    @isTest
    static void testHandleInboundEmail_CaseInsensitive() {
        EmailHandlerInvoiceProcessor handler = new EmailHandlerInvoiceProcessor();

        Messaging.InboundEmail email = new Messaging.InboundEmail();
        email.plainTextBody = 'Please process TRUST REQUEST 12345 for payment.';

        Messaging.InboundEnvelope envelope = new Messaging.InboundEnvelope();

        Test.startTest();
        Messaging.InboundEmailResult result = handler.handleInboundEmail(email, envelope);
        Test.stopTest();

        System.assert(result.success, 'Email processing should succeed with case insensitive matching');
    }

    @isTest
    static void testHandleInboundEmail_NoInvoiceNumber() {
        EmailHandlerInvoiceProcessor handler = new EmailHandlerInvoiceProcessor();

        Messaging.InboundEmail email = new Messaging.InboundEmail();
        email.plainTextBody = 'This email has no invoice or trust request number.';

        Messaging.InboundEnvelope envelope = new Messaging.InboundEnvelope();

        Test.startTest();
        Messaging.InboundEmailResult result = handler.handleInboundEmail(email, envelope);
        Test.stopTest();

        System.assert(!result.success, 'Email processing should fail when no invoice number found');
        System.assert(result.message.contains('No valid Trust Request or Invoice number found'), 'Should contain appropriate error message');
    }

    @isTest
    static void testHandleInboundEmail_InvoiceNotFound() {
        EmailHandlerInvoiceProcessor handler = new EmailHandlerInvoiceProcessor();

        Messaging.InboundEmail email = new Messaging.InboundEmail();
        email.plainTextBody = 'Please process Trust Request 99999999 for payment.';

        Messaging.InboundEnvelope envelope = new Messaging.InboundEnvelope();

        Test.startTest();
        Messaging.InboundEmailResult result = handler.handleInboundEmail(email, envelope);
        Test.stopTest();

        System.assert(!result.success, 'Email processing should fail when invoice not found');
        System.assert(result.message.contains('No Invoice found with number'), 'Should contain appropriate error message');
    }

    @isTest
    static void testHandleInboundEmail_InvoiceNoMatter() {
        EmailHandlerInvoiceProcessor handler = new EmailHandlerInvoiceProcessor();

        Messaging.InboundEmail email = new Messaging.InboundEmail();
        email.plainTextBody = 'Please process Trust Request 99999 for payment.';

        Messaging.InboundEnvelope envelope = new Messaging.InboundEnvelope();

        Test.startTest();
        Messaging.InboundEmailResult result = handler.handleInboundEmail(email, envelope);
        Test.stopTest();

        System.assert(!result.success, 'Email processing should fail when invoice has no matter');
        System.assert(result.message.contains('has no associated Matter'), 'Should contain appropriate error message');
    }

    @isTest
    static void testExtractInvoiceNumber_MultipleNumbers() {
        EmailHandlerInvoiceProcessor handler = new EmailHandlerInvoiceProcessor();

        String emailBody = 'Process Trust Request 12345 and also Invoice 67890';

        Test.startTest();
        String result = handler.extractInvoiceNumber(emailBody);
        Test.stopTest();

        System.assertEquals('12345', result, 'Should extract the first matching number (Trust Request)');
    }

    @isTest
    static void testExtractInvoiceNumber_WithWhitespace() {
        EmailHandlerInvoiceProcessor handler = new EmailHandlerInvoiceProcessor();

        String emailBody = 'Process Trust Request    12345 with extra spaces';

        Test.startTest();
        String result = handler.extractInvoiceNumber(emailBody);
        Test.stopTest();

        System.assertEquals('12345', result, 'Should handle multiple whitespace characters');
    }

    @isTest
    static void testGetEmailBody_PlainTextPriority() {
        EmailHandlerInvoiceProcessor handler = new EmailHandlerInvoiceProcessor();

        Messaging.InboundEmail email = new Messaging.InboundEmail();
        email.plainTextBody = 'Plain text content';
        email.htmlBody = '<p>HTML content</p>';

        Test.startTest();
        String result = handler.getEmailBody(email);
        Test.stopTest();

        System.assertEquals('Plain text content', result, 'Should prioritize plain text over HTML');
    }

    @isTest
    static void testGetEmailBody_HtmlFallback() {
        EmailHandlerInvoiceProcessor handler = new EmailHandlerInvoiceProcessor();

        Messaging.InboundEmail email = new Messaging.InboundEmail();
        email.htmlBody = '<p>HTML content</p>';

        Test.startTest();
        String result = handler.getEmailBody(email);
        Test.stopTest();

        System.assertEquals('HTML content', result, 'Should use HTML body when plain text not available');
    }

    @isTest
    static void testHandleInboundEmail_TrustRequestWithHash() {
        EmailHandlerInvoiceProcessor handler = new EmailHandlerInvoiceProcessor();

        Messaging.InboundEmail email = new Messaging.InboundEmail();
        email.plainTextBody = 'Please process Trust Request #12345 for payment.';

        Messaging.InboundEnvelope envelope = new Messaging.InboundEnvelope();

        Test.startTest();
        Messaging.InboundEmailResult result = handler.handleInboundEmail(email, envelope);
        Test.stopTest();

        System.assert(result.success, 'Email processing should succeed with # symbol');

        Matter__c updatedMatter = [SELECT Date_First_Payment__c FROM Matter__c LIMIT 1];
        System.assertEquals(Date.today(), updatedMatter.Date_First_Payment__c, 'Date_First_Payment__c should be set to today');
    }

    @isTest
    static void testHandleInboundEmail_InvoiceWithHash() {
        EmailHandlerInvoiceProcessor handler = new EmailHandlerInvoiceProcessor();

        Messaging.InboundEmail email = new Messaging.InboundEmail();
        email.plainTextBody = 'Please process Invoice #12345 for payment.';

        Messaging.InboundEnvelope envelope = new Messaging.InboundEnvelope();

        Test.startTest();
        Messaging.InboundEmailResult result = handler.handleInboundEmail(email, envelope);
        Test.stopTest();

        System.assert(result.success, 'Email processing should succeed with # symbol on Invoice');

        Matter__c updatedMatter = [SELECT Date_First_Payment__c FROM Matter__c LIMIT 1];
        System.assertEquals(Date.today(), updatedMatter.Date_First_Payment__c, 'Date_First_Payment__c should be set to today');
    }

    @isTest
    static void testHandleInboundEmail_DuplicateNumbers() {
        EmailHandlerInvoiceProcessor handler = new EmailHandlerInvoiceProcessor();

        // Reset matter to ensure clean test
        Matter__c testMatter = [SELECT Id FROM Matter__c LIMIT 1];
        testMatter.Date_First_Payment__c = null;
        update testMatter;

        Messaging.InboundEmail email = new Messaging.InboundEmail();
        email.plainTextBody = 'Trust Request #12345 has been processed. Please confirm Trust Request 12345 payment.';

        Messaging.InboundEnvelope envelope = new Messaging.InboundEnvelope();

        Test.startTest();
        Messaging.InboundEmailResult result = handler.handleInboundEmail(email, envelope);
        Test.stopTest();

        System.assert(result.success, 'Email processing should succeed with duplicate numbers');

        Matter__c updatedMatter = [SELECT Date_First_Payment__c FROM Matter__c LIMIT 1];
        System.assertEquals(Date.today(), updatedMatter.Date_First_Payment__c, 'Date_First_Payment__c should be set to today only once');
    }

    @isTest
    static void testHandleInboundEmail_VariousSpacing() {
        EmailHandlerInvoiceProcessor handler = new EmailHandlerInvoiceProcessor();

        Messaging.InboundEmail email = new Messaging.InboundEmail();
        email.plainTextBody = 'Process Trust Request   #   12345 with extra spacing.';

        Messaging.InboundEnvelope envelope = new Messaging.InboundEnvelope();

        Test.startTest();
        Messaging.InboundEmailResult result = handler.handleInboundEmail(email, envelope);
        Test.stopTest();

        System.assert(result.success, 'Email processing should succeed with various spacing');
    }

    @isTest
    static void testExtractInvoiceNumber_HashSymbol() {
        EmailHandlerInvoiceProcessor handler = new EmailHandlerInvoiceProcessor();

        String emailBody = 'Trust Request #65485 needs processing';

        Test.startTest();
        String result = handler.extractInvoiceNumber(emailBody);
        Test.stopTest();

        System.assertEquals('65485', result, 'Should extract number after # symbol');
    }

    @isTest
    static void testExtractInvoiceNumber_MultipleDifferentNumbers() {
        EmailHandlerInvoiceProcessor handler = new EmailHandlerInvoiceProcessor();

        String emailBody = 'Trust Request #12345 and also Invoice #67890';

        Test.startTest();
        String result = handler.extractInvoiceNumber(emailBody);
        Test.stopTest();

        System.assertEquals('12345', result, 'Should extract Trust Request number when both types present');
    }

    @isTest
    static void testExtractInvoiceNumber_NoSpaceBeforeHash() {
        EmailHandlerInvoiceProcessor handler = new EmailHandlerInvoiceProcessor();

        String emailBody = 'Trust Request#12345 with no space before hash';

        Test.startTest();
        String result = handler.extractInvoiceNumber(emailBody);
        Test.stopTest();

        System.assertEquals('12345', result, 'Should handle no space before # symbol');
    }
}