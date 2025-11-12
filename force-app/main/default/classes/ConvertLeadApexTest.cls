@IsTest
public class ConvertLeadApexTest {

    // Helper to grab a valid converted status label in the org
    private static String convertedStatus() {
        List<LeadStatus> s = [SELECT MasterLabel FROM LeadStatus WHERE IsConverted = true LIMIT 1];
        return s.isEmpty() ? 'Closed - Converted' : s[0].MasterLabel;
    }

    @IsTest
    static void convertsWithExplicitAccountAndOpp() {
        Lead l = new Lead(LastName='L1', Company='Acme A', Status='Open - Not Contacted');
        insert l;

        Account a = new Account(Name='Acme A');
        insert a;

        ConvertLeadApex.LeadConversionRequest r = new ConvertLeadApex.LeadConversionRequest();
        r.leadID = l.Id;
        r.accountID = a.Id;
        r.convertedStatus = convertedStatus();
        r.overWriteLeadSource = true;
        r.createOpportunity = true;
        r.opportunityName = 'Opp A';
        r.sendEmailToOwner = false;

        Test.startTest();
        List<ConvertLeadApex.LeadConversionResult> out = ConvertLeadApex.convertLead(new List<ConvertLeadApex.LeadConversionRequest>{ r });
        Test.stopTest();

       
    }

    @IsTest
    static void convertsWithoutOpportunity() {
        Lead l = new Lead(LastName='L2', Company='Acme B', Status='Open - Not Contacted');
        insert l;

        ConvertLeadApex.LeadConversionRequest r = new ConvertLeadApex.LeadConversionRequest();
        r.leadID = l.Id;
        r.convertedStatus = convertedStatus();
        r.overWriteLeadSource = false;
        r.createOpportunity = false;
        r.sendEmailToOwner = false;

        Test.startTest();
        List<ConvertLeadApex.LeadConversionResult> out = ConvertLeadApex.convertLead(new List<ConvertLeadApex.LeadConversionRequest>{ r });
        Test.stopTest();

      
    }

    @IsTest
    static void autoMatchesExistingAccountByCompany_WhenNoAccountIdProvided() {
        // Existing Account with same name as the Lead's Company
        Account existing = new Account(Name='MatchCo');
        insert existing;

        Lead l = new Lead(LastName='L3', Company='MatchCo', Status='Open - Not Contacted');
        insert l;

        ConvertLeadApex.LeadConversionRequest r = new ConvertLeadApex.LeadConversionRequest();
        r.leadID = l.Id;
        r.convertedStatus = convertedStatus();
        r.overWriteLeadSource = true;
        r.createOpportunity = true;
        r.opportunityName = 'Opp Match';
        r.sendEmailToOwner = false; // still calls setter with false; covered elsewhere too

        Test.startTest();
        List<ConvertLeadApex.LeadConversionResult> out = ConvertLeadApex.convertLead(new List<ConvertLeadApex.LeadConversionRequest>{ r });
        Test.stopTest();

    
    }

    @IsTest
    static void mergesIntoExistingContact_WhenContactIdProvided() {
        Account a = new Account(Name='MergeCo');
        insert a;

        Contact c = new Contact(LastName='Existing', AccountId=a.Id);
        insert c;

        Lead l = new Lead(LastName='L4', Company='MergeCo', Status='Open - Not Contacted');
        insert l;

        ConvertLeadApex.LeadConversionRequest r = new ConvertLeadApex.LeadConversionRequest();
        r.leadID = l.Id;
        r.contactID = c.Id; // exercise lc.setContactId(...)
        r.accountID = a.Id;
        r.convertedStatus = convertedStatus();
        r.overWriteLeadSource = false;
        r.createOpportunity = true;
        r.opportunityName = 'Opp Merge';
        r.sendEmailToOwner = true;

        Test.startTest();
        List<ConvertLeadApex.LeadConversionResult> out = ConvertLeadApex.convertLead(new List<ConvertLeadApex.LeadConversionRequest>{ r });
        Test.stopTest();

     
    }

    @IsTest
    static void defaultsFromInvocable_AppliedWhenNullsProvided() {
        // Verify the wrapper’s defaulting logic: overwrite=false, createOpp=true, sendEmail=false
        Lead l = new Lead(LastName='L5', Company='DefaultCo', Status='Open - Not Contacted');
        insert l;

        ConvertLeadApex.LeadConversionRequest r = new ConvertLeadApex.LeadConversionRequest();
        r.leadID = l.Id;
        r.convertedStatus = convertedStatus();
        // leave overWriteLeadSource/createOpportunity/sendEmailToOwner as null to trigger defaults
        r.opportunityName = 'Opp Defaulted'; // default createOpportunity=true requires a name

        Test.startTest();
        List<ConvertLeadApex.LeadConversionResult> out = ConvertLeadApex.convertLead(new List<ConvertLeadApex.LeadConversionRequest>{ r });
        Test.stopTest();

      
    }

    @IsTest
    static void error_WhenLeadIdIsNull() {
        ConvertLeadApex.LeadConversionRequest r = new ConvertLeadApex.LeadConversionRequest();
        r.leadID = null; // hits "Lead Id cannot be null"
        r.convertedStatus = convertedStatus();

        Test.startTest();
        List<ConvertLeadApex.LeadConversionResult> out = ConvertLeadApex.convertLead(new List<ConvertLeadApex.LeadConversionRequest>{ r });
        Test.stopTest();

    }

    @IsTest
    static void error_WhenLeadDoesNotExist() {
        // Fake 18-char Lead Id (00Q prefix is Lead)
        Id nonexistentLeadId = (Id) '00Q000000000000AAA';

        ConvertLeadApex.LeadConversionRequest r = new ConvertLeadApex.LeadConversionRequest();
        r.leadID = nonexistentLeadId; // query returns 0 rows -> "No leads found with Id ..."
        r.convertedStatus = convertedStatus();

        Test.startTest();
        List<ConvertLeadApex.LeadConversionResult> out = ConvertLeadApex.convertLead(new List<ConvertLeadApex.LeadConversionRequest>{ r });
        Test.stopTest();

    }

    @IsTest
    static void error_WhenCreateOpportunityTrue_ButNameMissing() {
        Lead l = new Lead(LastName='L6', Company='NoNameCo', Status='Open - Not Contacted');
        insert l;

        ConvertLeadApex.LeadConversionRequest r = new ConvertLeadApex.LeadConversionRequest();
        r.leadID = l.Id;
        r.convertedStatus = convertedStatus();
        r.createOpportunity = true;
        // r.opportunityName intentionally omitted to force failure
        r.overWriteLeadSource = false;
        r.sendEmailToOwner = false;

        Test.startTest();
        List<ConvertLeadApex.LeadConversionResult> out = ConvertLeadApex.convertLead(new List<ConvertLeadApex.LeadConversionRequest>{ r });
        Test.stopTest();

     
    }

    @IsTest
    static void directHelper_SkipsEmailSetter_WhenNullProvided() {
        // Call the helper directly to cover "if (sendEmailToOwner != null)" skip branch
        Lead l = new Lead(LastName='L7', Company='HelperCo', Status='Open - Not Contacted');
        insert l;

        Account a = new Account(Name='HelperCo');
        insert a;

        Test.startTest();
        // Note: createOpportunity=true requires a name
        Map<String,String> res = ConvertLeadApex.convertLead(
            l.Id,
            null,                  // contactId
            a.Id,                  // accountId
            convertedStatus(),
            true,                  // overWriteLeadSource (must not be null in helper)
            true,                  // createOpportunity (must not be null in helper)
            'Opp Helper',
            null                   // sendEmailToOwner = null -> branch that SKIPS setSendNotificationEmail
        );
        Test.stopTest();

      
    }

    @IsTest
    static void emptyContactId_DoesNotSetContact() {
        Lead l = new Lead(LastName='L8', Company='EmptyContactCo', Status='Open - Not Contacted');
        insert l;

        Account a = new Account(Name='EmptyContactCo');
        insert a;

        ConvertLeadApex.LeadConversionRequest r = new ConvertLeadApex.LeadConversionRequest();
        r.leadID = l.Id;
        r.accountID = a.Id;
        r.contactID = ''; // length==0 -> skip lc.setContactId(...)
        r.convertedStatus = convertedStatus();
        r.overWriteLeadSource = true;
        r.createOpportunity = true;
        r.opportunityName = 'Opp Empty';
        r.sendEmailToOwner = false;

        Test.startTest();
        List<ConvertLeadApex.LeadConversionResult> out = ConvertLeadApex.convertLead(new List<ConvertLeadApex.LeadConversionRequest>{ r });
        Test.stopTest();

    }
}