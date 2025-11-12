public with sharing class ClioModels {
    
    public class ClioContact {
        public String id { get; set; }
        public String name { get; set; }
        public String type { get; set; }
        public String first_name { get; set; }
        public String last_name { get; set; }
        public String middle_name { get; set; }
        public String email { get; set; }
        public String phone_number { get; set; }
        public String mobile_number { get; set; }
        public String home_phone_number { get; set; }
        public String fax_number { get; set; }
        public Address addresses { get; set; }
        public String company_name { get; set; }
        public String title { get; set; }
        public String updated_at { get; set; }
        public String created_at { get; set; }
    }
    
    public class ClioMatter {
        public String id { get; set; }
        public String display_number { get; set; }
        public String description { get; set; }
        public String status { get; set; }
        public String location { get; set; }
        public ClioContact client { get; set; }
        public String client_reference { get; set; }
        public ResponsibleAttorney responsible_attorney { get; set; }
        public String open_date { get; set; }
        public String close_date { get; set; }
        public String pending_date { get; set; }
        public PracticeArea practice_area { get; set; }
        public String updated_at { get; set; }
        public String created_at { get; set; }
        public TrustBalances trust_balances { get; set; }
    }
    
    public class ClioTimeEntry {
        public String id { get; set; }
        public String type { get; set; }
        public Decimal quantity { get; set; }
        public Decimal price { get; set; }
        public Decimal total { get; set; }
        public String note { get; set; }
        public String date_x { get; set; }
        public Matter matter { get; set; }
        public User user { get; set; }
        public Boolean non_billable { get; set; }
        public String updated_at { get; set; }
        public String created_at { get; set; }
    }
    
    public class ClioBill {
        public String id { get; set; }
        public String number_x { get; set; }
        public String issued_at { get; set; }
        public String due_at { get; set; }
        public Decimal subtotal { get; set; }
        public Decimal total { get; set; }
        public Decimal tax_amount { get; set; }
        public Decimal balance { get; set; }
        public String state { get; set; }
        public ClioContact client { get; set; }
        public Matter matter { get; set; }
        public String updated_at { get; set; }
        public String created_at { get; set; }
    }
    
    public class ClioCalendarEntry {
        public String id { get; set; }
        public String summary { get; set; }
        public String description { get; set; }
        public String start_at { get; set; }
        public String end_at { get; set; }
        public String location { get; set; }
        public Matter matter { get; set; }
        public Attendee[] attendees { get; set; }
        public String updated_at { get; set; }
        public String created_at { get; set; }
    }
    
    public class ClioPayment {
        public String id { get; set; }
        public String type { get; set; }
        public String date_x { get; set; }
        public Decimal amount { get; set; }
        public String note { get; set; }
        public ClioContact client { get; set; }
        public Matter matter { get; set; }
        public Allocations[] allocations { get; set; }
        public String updated_at { get; set; }
        public String created_at { get; set; }
    }
    
    public class Address {
        public String street { get; set; }
        public String city { get; set; }
        public String province { get; set; }
        public String postal_code { get; set; }
        public String country { get; set; }
    }
    
    public class ResponsibleAttorney {
        public String id { get; set; }
        public String name { get; set; }
    }
    
    public class PracticeArea {
        public String id { get; set; }
        public String name { get; set; }
    }
    
    public class TrustBalances {
        public Decimal balance { get; set; }
        public Decimal available { get; set; }
    }
    
    public class Matter {
        public String id { get; set; }
        public String display_number { get; set; }
    }
    
    public class User {
        public String id { get; set; }
        public String name { get; set; }
    }
    
    public class Attendee {
        public String email { get; set; }
        public String name { get; set; }
    }
    
    public class Allocations {
        public String id { get; set; }
        public String type { get; set; }
        public Decimal amount { get; set; }
        public ClioBill bill { get; set; }
    }
    
    public class ClioUser {
        public String id { get; set; }
        public String name { get; set; }
        public String first_name { get; set; }
        public String last_name { get; set; }
        public String email { get; set; }
        public Boolean enabled { get; set; }
        public String role { get; set; }
        public String updated_at { get; set; }
        public String created_at { get; set; }
    }
}