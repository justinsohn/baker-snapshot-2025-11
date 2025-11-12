public with sharing class ARAgingController {
    
    @AuraEnabled(cacheable=true)
    public static ARAgingData getARAgingData(Date asOfDate, String teamFilter) {
        ARAgingData result = new ARAgingData();
        
        try {
            if (asOfDate == null) {
                asOfDate = Date.today();
            }
            
            // Calculate date boundaries
            Date date30DaysAgo = asOfDate.addDays(-30);
            Date date60DaysAgo = asOfDate.addDays(-60);
            Date date90DaysAgo = asOfDate.addDays(-90);
            
            // Build base WHERE clause with filters
            String baseWhereClause = buildBaseWhereClause(teamFilter);
            
            // Get 0-30 days aging (cumulative)
            String query30 = 'SELECT SUM(Balance__c) totalBalance, COUNT(Id) invoiceCount ' +
                            'FROM Invoice__c ' +
                            'WHERE ' + baseWhereClause + 
                            ' AND Date__c <= :asOfDate' +
                            ' AND Date__c >= :date30DaysAgo';
            List<AggregateResult> aging30 = Database.query(query30);
            
            // Get 0-60 days aging (cumulative)
            String query60 = 'SELECT SUM(Balance__c) totalBalance, COUNT(Id) invoiceCount ' +
                            'FROM Invoice__c ' +
                            'WHERE ' + baseWhereClause + 
                            ' AND Date__c <= :asOfDate' +
                            ' AND Date__c >= :date60DaysAgo';
            List<AggregateResult> aging60 = Database.query(query60);
            
            // Get 0-90 days aging (cumulative)
            String query90 = 'SELECT SUM(Balance__c) totalBalance, COUNT(Id) invoiceCount ' +
                            'FROM Invoice__c ' +
                            'WHERE ' + baseWhereClause + 
                            ' AND Date__c <= :asOfDate' +
                            ' AND Date__c >= :date90DaysAgo';
            List<AggregateResult> aging90 = Database.query(query90);
            
            // Get 0-91+ days aging (all outstanding invoices)
            String query91Plus = 'SELECT SUM(Balance__c) totalBalance, COUNT(Id) invoiceCount ' +
                                'FROM Invoice__c ' +
                                'WHERE ' + baseWhereClause + 
                                ' AND Date__c <= :asOfDate';
            List<AggregateResult> aging91Plus = Database.query(query91Plus);
            
            if (!aging30.isEmpty()) {
                result.aging30Days = (Decimal) aging30[0].get('totalBalance') ?? 0;
                result.count30Days = (Integer) aging30[0].get('invoiceCount') ?? 0;
            }
            
            if (!aging60.isEmpty()) {
                result.aging60Days = (Decimal) aging60[0].get('totalBalance') ?? 0;
                result.count60Days = (Integer) aging60[0].get('invoiceCount') ?? 0;
            }
            
            if (!aging90.isEmpty()) {
                result.aging90Days = (Decimal) aging90[0].get('totalBalance') ?? 0;
                result.count90Days = (Integer) aging90[0].get('invoiceCount') ?? 0;
            }
            
            if (!aging91Plus.isEmpty()) {
                result.aging91PlusDays = (Decimal) aging91Plus[0].get('totalBalance') ?? 0;
                result.count91PlusDays = (Integer) aging91Plus[0].get('invoiceCount') ?? 0;
            }
            
        } catch (Exception e) {
            System.debug('Error in getARAgingData: ' + e.getMessage());
            throw new AuraHandledException('Error retrieving AR aging data: ' + e.getMessage());
        }
        
        return result;
    }
    
    @AuraEnabled(cacheable=true)
    public static List<InvoiceDetailData> getInvoiceDetails(Date asOfDate, String agingBucket, String teamFilter) {
        List<InvoiceDetailData> result = new List<InvoiceDetailData>();
        
        try {
            if (asOfDate == null) {
                asOfDate = Date.today();
            }
            
            // Calculate date boundaries
            Date date30DaysAgo = asOfDate.addDays(-30);
            Date date60DaysAgo = asOfDate.addDays(-60);
            Date date90DaysAgo = asOfDate.addDays(-90);
            
            // Build base WHERE clause with filters
            String baseWhereClause = buildBaseWhereClause(teamFilter);
            String query = 'SELECT Id, Name, Invoice_Number__c, Date__c, Balance__c, Account__r.Name, TeamMatter__c, Matter__r.Name, Status__c ' +
                          'FROM Invoice__c ' +
                          'WHERE ' + baseWhereClause;
            
            if (agingBucket == '30') {
                query += ' AND Date__c <= :asOfDate AND Date__c >= :date30DaysAgo';
            } else if (agingBucket == '60') {
                query += ' AND Date__c <= :asOfDate AND Date__c >= :date60DaysAgo';
            } else if (agingBucket == '90') {
                query += ' AND Date__c <= :asOfDate AND Date__c >= :date90DaysAgo';
            } else if (agingBucket == '91+') {
                query += ' AND Date__c <= :asOfDate';
            }
            
            query += ' ORDER BY Date__c ASC';
            
            List<Invoice__c> invoices = Database.query(query);
            
            for (Invoice__c inv : invoices) {
                InvoiceDetailData detail = new InvoiceDetailData();
                detail.invoiceId = inv.Id;
                detail.invoiceName = inv.Name;
                detail.invoiceNumber = inv.Invoice_Number__c;
                detail.invoiceDate = inv.Date__c;
                detail.balance = inv.Balance__c;
                detail.daysOutstanding = asOfDate.daysBetween(inv.Date__c);
                detail.accountName = inv.Account__r?.Name;
                detail.teamMatter = inv.TeamMatter__c;
                detail.matter = inv.Matter__r?.Name;
                detail.status = inv.Status__c;
                
                result.add(detail);
            }
            
        } catch (Exception e) {
            System.debug('Error in getInvoiceDetails: ' + e.getMessage());
            throw new AuraHandledException('Error retrieving invoice details: ' + e.getMessage());
        }
        
        return result;
    }
    
    @AuraEnabled(cacheable=true)
    public static List<String> getAvailableTeams(Date asOfDate) {
        List<String> teams = new List<String>();
        Set<String> uniqueTeams = new Set<String>();
        
        try {
            if (asOfDate == null) {
                asOfDate = Date.today();
            }
            
            // Build base WHERE clause without team filter
            String baseWhereClause = buildBaseWhereClause(null);
            
            String query = 'SELECT TeamMatter__c ' +
                          'FROM Invoice__c ' +
                          'WHERE ' + baseWhereClause + 
                          ' AND Date__c <= :asOfDate' +
                          ' AND TeamMatter__c != null' +
                          ' ORDER BY TeamMatter__c';
            
            List<Invoice__c> invoices = Database.query(query);
            
            // Collect unique team names
            for (Invoice__c inv : invoices) {
                if (String.isNotBlank(inv.TeamMatter__c)) {
                    uniqueTeams.add(inv.TeamMatter__c);
                }
            }
            
            teams.add('All'); // Default option
            
            // Add sorted unique teams
            List<String> sortedTeams = new List<String>(uniqueTeams);
            sortedTeams.sort();
            teams.addAll(sortedTeams);
            
        } catch (Exception e) {
            System.debug('Error in getAvailableTeams: ' + e.getMessage());
            throw new AuraHandledException('Error retrieving available teams: ' + e.getMessage());
        }
        
        return teams;
    }
    
    private static String buildBaseWhereClause(String teamFilter) {
        List<String> conditions = new List<String>();
        
        // Base conditions
        conditions.add('Balance__c > 0');
        conditions.add('Matter__c != null');
        conditions.add('(Status__c = \'Paid\' OR Status__c = \'awaiting_payment\' OR Status__c = \'awaiting_approval\')');
        conditions.add('(KindOfBill__c = null OR (NOT KindOfBill__c LIKE \'%trust%\'))');
        
        // Team filter
        if (String.isNotBlank(teamFilter) && teamFilter != 'All') {
            conditions.add('TeamMatter__c = \'' + String.escapeSingleQuotes(teamFilter) + '\'');
        }
        
        return String.join(conditions, ' AND ');
    }
    
    public class ARAgingData {
        @AuraEnabled public Decimal aging30Days = 0;
        @AuraEnabled public Integer count30Days = 0;
        @AuraEnabled public Decimal aging60Days = 0;
        @AuraEnabled public Integer count60Days = 0;
        @AuraEnabled public Decimal aging90Days = 0;
        @AuraEnabled public Integer count90Days = 0;
        @AuraEnabled public Decimal aging91PlusDays = 0;
        @AuraEnabled public Integer count91PlusDays = 0;
    }
    
    public class InvoiceDetailData {
        @AuraEnabled public String invoiceId;
        @AuraEnabled public String invoiceName;
        @AuraEnabled public String invoiceNumber;
        @AuraEnabled public Date invoiceDate;
        @AuraEnabled public Decimal balance;
        @AuraEnabled public Integer daysOutstanding;
        @AuraEnabled public String accountName;
        @AuraEnabled public String teamMatter;
        @AuraEnabled public String matter;
        @AuraEnabled public String status;
    }
}