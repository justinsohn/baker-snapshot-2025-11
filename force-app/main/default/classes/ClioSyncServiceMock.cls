@isTest
public class ClioSyncServiceMock implements HttpCalloutMock {

    public HTTPResponse respond(HTTPRequest req) {
        HttpResponse res = new HttpResponse();
        res.setHeader('Content-Type', 'application/json');
        
        String endpoint = req.getEndpoint();
        String body = '';
        
        // Handle different endpoints
        if (endpoint.contains('/users')) {
            body = '{"data":[{"id":12345,"name":"Test User","first_name":"Test","last_name":"User","email":"test@user.com","enabled":true,"updated_at":"2023-01-01T00:00:00Z"}],"meta":{"records":1,"has_more":false,"cursor":"123"}}';
        } else if (endpoint.contains('/contacts')) {
            body = '{"data":[{"id":54321,"name":"Test Contact","first_name":"Test","last_name":"Contact","type":"Person","primary_email_address":"test@contact.com","primary_phone_number":"555-1234","company":"Test Company","updated_at":"2023-01-01T00:00:00Z"}],"meta":{"records":1,"has_more":false}}';
        } else if (endpoint.contains('/matters')) {
            body = '{"data":[{"id":98765,"display_number":"M-001","description":"Test Matter","status":"Open","location":"Office","client":{"id":54321,"name":"Test Client"},"responsible_attorney":{"id":12345,"name":"Test Attorney"},"open_date":"2023-01-01","billable":{"rate":300.00},"practice_area":{"name":"Corporate Law"},"updated_at":"2023-01-01T00:00:00Z"}],"meta":{"records":1,"has_more":false}}';
        } else if (endpoint.contains('/activities')) {
            body = '{"data":[{"id":11111,"type":"TimeEntry","quantity":3600,"price":300.00,"total":300.00,"note":"Test time entry","date":"2023-01-01","matter":{"id":98765,"display_number":"M-001"},"user":{"id":12345,"name":"Test User"},"non_billable":false,"created_at":"2023-01-01T00:00:00Z","updated_at":"2023-01-01T00:00:00Z"}],"meta":{"records":1,"has_more":false}}';
        } else if (endpoint.contains('/bills')) {
            body = '{"data":[{"id":22222,"number":"INV-001","issued_at":"2023-01-01T00:00:00Z","due_at":"2023-01-31T00:00:00Z","subtotal":300.00,"total":330.00,"balance":330.00,"state":"sent","client":{"id":54321,"name":"Test Client"},"matter":{"id":98765,"display_number":"M-001"},"updated_at":"2023-01-01T00:00:00Z"}],"meta":{"records":1,"has_more":false}}';
        } else if (endpoint.contains('/calendar_entries')) {
            body = '{"data":[{"id":33333,"summary":"Test Meeting","description":"Test calendar entry","start_at":"2023-01-01T10:00:00Z","end_at":"2023-01-01T11:00:00Z","location":"Conference Room","matter":{"id":98765,"display_number":"M-001"},"attendees":[],"updated_at":"2023-01-01T00:00:00Z"}],"meta":{"records":1,"has_more":false}}';
        } else if (endpoint.contains('/bank_transactions')) {
            body = '{"data":[{"id":44444,"type":"Payment","date":"2023-01-01","amount":1000.00,"note":"Test payment","matter":{"id":98765,"display_number":"M-001"},"allocations":[],"updated_at":"2023-01-01T00:00:00Z"}],"meta":{"records":1,"has_more":false}}';
        } else if (endpoint.contains('/rate-limit')) {
            res.setStatusCode(429);
            body = '{"error":"Rate limit exceeded"}';
        } else if (endpoint.contains('/error')) {
            res.setStatusCode(500);
            body = '{"error":"Internal server error"}';
        } else if (endpoint.contains('/invalid-json')) {
            res.setStatusCode(200);
            body = 'invalid json response';
        } else {
            // Default response
            body = '{"data":[],"meta":{"records":0,"has_more":false}}';
        }
        
        if (res.getStatusCode() == 0) {
            res.setStatusCode(200);
        }
        
        res.setBody(body);
        return res;
    }
}