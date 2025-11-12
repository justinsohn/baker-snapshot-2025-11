@isTest
private class ClioModelsTest {

    @isTest
    static void testClioContactModel() {
        Test.startTest();
        
        ClioModels.ClioContact contact = new ClioModels.ClioContact();
        contact.id = '12345';
        contact.name = 'Test Contact';
        contact.type = 'Person';
        contact.first_name = 'Test';
        contact.last_name = 'Contact';
        contact.email = 'test@contact.com';
        contact.phone_number = '555-1234';
        contact.company_name = 'Test Company';
        contact.title = 'CEO';
        contact.updated_at = '2023-01-01T00:00:00Z';
        contact.created_at = '2023-01-01T00:00:00Z';
        
        Test.stopTest();

        System.assertEquals('12345', contact.id);
        System.assertEquals('Test Contact', contact.name);
        System.assertEquals('Person', contact.type);
        System.assertEquals('Test', contact.first_name);
        System.assertEquals('Contact', contact.last_name);
        System.assertEquals('test@contact.com', contact.email);
    }

    @isTest
    static void testClioMatterModel() {
        Test.startTest();
        
        ClioModels.ClioMatter matter = new ClioModels.ClioMatter();
        matter.id = '98765';
        matter.display_number = 'M-001';
        matter.description = 'Test Matter';
        matter.status = 'Open';
        matter.open_date = '2023-01-01';
        matter.updated_at = '2023-01-01T00:00:00Z';
        
        Test.stopTest();

        System.assertEquals('98765', matter.id);
        System.assertEquals('M-001', matter.display_number);
        System.assertEquals('Test Matter', matter.description);
        System.assertEquals('Open', matter.status);
    }

    @isTest
    static void testClioUserModel() {
        Test.startTest();
        
        ClioModels.ClioUser user = new ClioModels.ClioUser();
        user.id = '11111';
        user.name = 'Test User';
        user.first_name = 'Test';
        user.last_name = 'User';
        user.email = 'test@user.com';
        user.enabled = true;
        
        Test.stopTest();

        System.assertEquals('11111', user.id);
        System.assertEquals('Test User', user.name);
        System.assertEquals('test@user.com', user.email);
        System.assertEquals(true, user.enabled);
    }

    @isTest
    static void testClioTimeEntryModel() {
        Test.startTest();
        
        ClioModels.ClioTimeEntry timeEntry = new ClioModels.ClioTimeEntry();
        timeEntry.id = '22222';
        timeEntry.quantity = 3600;
        timeEntry.price = 300.00;
        timeEntry.total = 300.00;
        timeEntry.note = 'Test time entry';
        timeEntry.date_x = '2023-01-01';
        timeEntry.non_billable = false;
        
        Test.stopTest();

        System.assertEquals('22222', timeEntry.id);
        System.assertEquals(3600, timeEntry.quantity);
        System.assertEquals(300.00, timeEntry.price);
        System.assertEquals(false, timeEntry.non_billable);
    }

    @isTest
    static void testClioBillModel() {
        Test.startTest();
        
        ClioModels.ClioBill bill = new ClioModels.ClioBill();
        bill.id = '33333';
        bill.number_x = 'INV-001';
        bill.subtotal = 300.00;
        bill.total = 330.00;
        bill.balance = 330.00;
        bill.state = 'sent';
        bill.issued_at = '2023-01-01T00:00:00Z';
        bill.due_at = '2023-01-31T00:00:00Z';
        
        Test.stopTest();

        System.assertEquals('33333', bill.id);
        System.assertEquals('INV-001', bill.number_x);
        System.assertEquals(300.00, bill.subtotal);
        System.assertEquals('sent', bill.state);
    }

    @isTest
    static void testClioCalendarEntryModel() {
        Test.startTest();
        
        ClioModels.ClioCalendarEntry entry = new ClioModels.ClioCalendarEntry();
        entry.id = '44444';
        entry.summary = 'Test Meeting';
        entry.description = 'Test calendar entry';
        entry.start_at = '2023-01-01T10:00:00Z';
        entry.end_at = '2023-01-01T11:00:00Z';
        entry.location = 'Conference Room';
        
        Test.stopTest();

        System.assertEquals('44444', entry.id);
        System.assertEquals('Test Meeting', entry.summary);
        System.assertEquals('Conference Room', entry.location);
    }

    @isTest
    static void testClioPaymentModel() {
        Test.startTest();
        
        ClioModels.ClioPayment payment = new ClioModels.ClioPayment();
        payment.id = '55555';
        payment.type = 'Payment';
        payment.amount = 1000.00;
        payment.date_x = '2023-01-01';
        payment.note = 'Test payment';
        
        Test.stopTest();

        System.assertEquals('55555', payment.id);
        System.assertEquals('Payment', payment.type);
        System.assertEquals(1000.00, payment.amount);
        System.assertEquals('Test payment', payment.note);
    }

    @isTest
    static void testAddressModel() {
        Test.startTest();
        
        ClioModels.Address address = new ClioModels.Address();
        address.street = '123 Main St';
        address.city = 'Anytown';
        address.province = 'CA';
        address.postal_code = '12345';
        address.country = 'US';
        
        Test.stopTest();

        System.assertEquals('123 Main St', address.street);
        System.assertEquals('Anytown', address.city);
    }

}