/**
 * @description Apex controller for the Team Time Dashboard LWC.
 * Provides methods to fetch time entries, user goals, teams and users.
 */
public with sharing class TeamTimeDashboardController {

    /**
     * @description Fetches Time_Entry__c records based on a date range, billable status, team and user.
     * @param startDate The start of the date range filter.
     * @param endDate The end of the date range filter.
     * @param billableStatus Filter for 'All', 'Billable', or 'Non-Billable' entries.
     * @param team The team to filter by.
     * @param userId The user to filter by.
     * @return A list of Time_Entry__c records.
     */
    @AuraEnabled(cacheable=true)
    public static List<Time_Entry__c> getTeamTimeEntries(Date startDate, Date endDate, String billableStatus, String team, String userId) {
        String query = 'SELECT Id, Date__c, Non_Billable__c, Matter__r.Name, Note__c, Rate__c, Hours__c, User__r.Name ' +
                       'FROM Time_Entry__c ' +
                       'WHERE Date__c >= :startDate AND Date__c <= :endDate ';

        if (String.isNotBlank(billableStatus)) {
            if (billableStatus == 'Billable') {
                query += 'AND Non_Billable__c = false ';
            } else if (billableStatus == 'Non-Billable') {
                query += 'AND Non_Billable__c = true ';
            }
        }

        List<Id> userIds = new List<Id>();
        if (String.isNotBlank(userId) && userId != 'All') {
            userIds.add(userId);
        } else if (String.isNotBlank(team) && team != 'All') {
            for (User u : [SELECT Id FROM User WHERE Team__c = :team AND IsActive = true]) {
                userIds.add(u.Id);
            }
        }

        if(!userIds.isEmpty()){
             query += 'AND User__c IN :userIds ';
        }
        
        query += 'ORDER BY Date__c DESC, CreatedDate DESC';

        return Database.query(query);
    }

    /**
     * @description Fetches target hour and start date information for users.
     * @param team The team to filter users by. Can be 'All'.
     * @param userId The specific user to fetch information for. Can be 'All'.
     * @return A list of User records containing Target_Hours__c and Start_Date__c fields.
     */
    @AuraEnabled(cacheable=true)
    public static List<User> getTargetInfo(String team, String userId) {
        String query = 'SELECT Target_Hours__c, Start_Date__c FROM User WHERE IsActive = true ';

        if (String.isNotBlank(userId) && userId != 'All') {
            query += 'AND Id = :userId';
        } else if (String.isNotBlank(team) && team != 'All') {
            query += 'AND Team__c = :team';
        }
        
        return Database.query(query);
    }

    /**
     * @description Fetches the list of teams dynamically from data within the date range.
     * Combines teams from User.Team__c (time entries/goals) and TeamMatter__c (invoices).
     * @param startDate The start date for filtering data.
     * @param endDate The end date for filtering data.
     * @return A list of unique team names found in the data.
     */
    @AuraEnabled(cacheable=true)
    public static List<String> getTeams(Date startDate, Date endDate) {
        Set<String> teamSet = new Set<String>();
        
        // Get teams from Time Entries via User.Team__c
        String timeEntryQuery = 'SELECT User__r.Team__c FROM Time_Entry__c WHERE Date__c >= :startDate AND Date__c <= :endDate AND User__r.Team__c != null';
        List<Time_Entry__c> timeEntries = Database.query(timeEntryQuery);
        for (Time_Entry__c entry : timeEntries) {
            if (String.isNotBlank(entry.User__r.Team__c)) {
                teamSet.add(entry.User__r.Team__c);
            }
        }
        
        // Get teams from Invoices via TeamMatter__c (which derives from Matter__r.Team__c)
        List<String> invoiceStatus = new List<String>{'Paid', 'awaiting_payment', 'awaiting_approval'};
        String likeClause = '%' + 'trust' + '%';
        String invoiceQuery = 'SELECT TeamMatter__c FROM Invoice__c WHERE (KindOfBill__c = null OR (NOT KindOfBill__c LIKE :likeClause)) AND Status__c IN :invoiceStatus AND Date__c >= :startDate AND Date__c <= :endDate AND TeamMatter__c != null';
        List<Invoice__c> invoices = Database.query(invoiceQuery);
        for (Invoice__c inv : invoices) {
            if (String.isNotBlank(inv.TeamMatter__c)) {
                teamSet.add(inv.TeamMatter__c);
            }
        }
        
        // Convert to sorted list
        List<String> teams = new List<String>(teamSet);
        teams.sort();
        return teams;
    }

    /**
     * @description Fetches active users, optionally filtered by team.
     * @param team The team to filter users by.
     * @return A list of active User records.
     */
    @AuraEnabled(cacheable=true)
    public static List<User> getUsers(String team) {
        String query = 'SELECT Id, Name FROM User WHERE IsActive = true';
        if (String.isNotBlank(team) && team != 'All') {
            // By building the string with an escaped variable, we ensure the filter is correctly applied.
            String sanitizedTeam = String.escapeSingleQuotes(team);
            query += ' AND Team__c = \'' + sanitizedTeam + '\'';
        }
        query += ' ORDER BY Name';
        return Database.query(query);
    }

    /**
     * @description Fetches collection rate data based on Invoice records, matching InvoiceDashboard logic.
     * @param startDate The start of the date range filter.
     * @param endDate The end of the date range filter.
     * @param team The team to filter by.
     * @param userId The user to filter by.
     * @return Collection rate as a decimal percentage.
     */
    @AuraEnabled(cacheable=true)
    public static Decimal getCollectionRate(String dateFilter, Date startDate, Date endDate, String team, String userId) {
        // Calculate dates on server-side to match Invoice Dashboard logic exactly
        Date calculatedStartDate;
        Date calculatedEndDate;
        
        // Custom date range takes precedence over dropdown filter
        if (startDate != null || endDate != null) {
            calculatedStartDate = startDate;
            calculatedEndDate = endDate;
        } else {
            calculatedStartDate = calculateStartDate(dateFilter);
            calculatedEndDate = calculateEndDate(dateFilter);
        }
        List<String> invoiceStatus = new List<String>{'Paid', 'awaiting_payment', 'awaiting_approval'};
        String likeClause = '%' + 'trust' + '%';

        // Build dynamic query for invoices with Matter relationship
        String invoiceQuery = 'SELECT Id, Amount__c, Paid_Amount__c, TeamMatter__c, Matter__r.Responsible_Attorney__c FROM Invoice__c WHERE (KindOfBill__c = null OR (NOT KindOfBill__c LIKE :likeClause)) AND Status__c IN :invoiceStatus';
        
        if (calculatedStartDate != null) {
            invoiceQuery += ' AND Date__c >= :calculatedStartDate';
        }
        if (calculatedEndDate != null) {
            invoiceQuery += ' AND Date__c <= :calculatedEndDate';
        }

        // Apply team filter using Invoice's TeamMatter__c field
        if (String.isNotBlank(team) && team != 'All') {
            invoiceQuery += ' AND TeamMatter__c = :team';
        }

        // Apply person filter using Matter's Responsible_Attorney__c field
        if (String.isNotBlank(userId) && userId != 'All') {
            invoiceQuery += ' AND Matter__r.Responsible_Attorney__c = :userId';
        }

        List<Invoice__c> invoices = Database.query(invoiceQuery);

        Decimal totalInvoiced = 0;
        Decimal paymentsReceived = 0;

        for (Invoice__c inv : invoices) {
            if (inv.Amount__c != null) {
                totalInvoiced += inv.Amount__c;
            }
            if (inv.Paid_Amount__c != null) {
                paymentsReceived += inv.Paid_Amount__c;
            }
        }

        return totalInvoiced > 0 ? (paymentsReceived / totalInvoiced * 100).setScale(1) : 0;
    }

    /**
     * @description Fetches detailed invoice information for collection rate modal.
     * @param startDate The start of the date range filter.
     * @param endDate The end of the date range filter.
     * @param team The team to filter by.
     * @param userId The user to filter by.
     * @return A list of invoice detail records for the modal.
     */
    @AuraEnabled(cacheable=true)
    public static List<InvoiceDetailData> getCollectionRateDetails(String dateFilter, Date startDate, Date endDate, String team, String userId) {
        // Calculate dates on server-side to match Invoice Dashboard logic exactly
        Date calculatedStartDate;
        Date calculatedEndDate;
        
        // Custom date range takes precedence over dropdown filter
        if (startDate != null || endDate != null) {
            calculatedStartDate = startDate;
            calculatedEndDate = endDate;
        } else {
            calculatedStartDate = calculateStartDate(dateFilter);
            calculatedEndDate = calculateEndDate(dateFilter);
        }
        List<String> invoiceStatus = new List<String>{'Paid', 'awaiting_payment', 'awaiting_approval'};
        String likeClause = '%' + 'trust' + '%';

        // Build dynamic query for invoices with Matter relationship
        String invoiceQuery = 'SELECT Id, Invoice_Number__c, Date__c, Amount__c, Paid_Amount__c, Balance__c, Status__c, TeamMatter__c, Matter__r.Name, Matter__r.Responsible_Attorney__c, Matter__r.Responsible_Attorney__r.Name FROM Invoice__c WHERE (KindOfBill__c = null OR (NOT KindOfBill__c LIKE :likeClause)) AND Status__c IN :invoiceStatus';
        
        if (calculatedStartDate != null) {
            invoiceQuery += ' AND Date__c >= :calculatedStartDate';
        }
        if (calculatedEndDate != null) {
            invoiceQuery += ' AND Date__c <= :calculatedEndDate';
        }

        // Apply team filter using Invoice's TeamMatter__c field
        if (String.isNotBlank(team) && team != 'All') {
            invoiceQuery += ' AND TeamMatter__c = :team';
        }

        // Apply person filter using Matter's Responsible_Attorney__c field
        if (String.isNotBlank(userId) && userId != 'All') {
            invoiceQuery += ' AND Matter__r.Responsible_Attorney__c = :userId';
        }

        invoiceQuery += ' ORDER BY Date__c DESC';

        List<Invoice__c> invoices = Database.query(invoiceQuery);
        List<InvoiceDetailData> result = new List<InvoiceDetailData>();
        
        for (Invoice__c invoice : invoices) {
            Decimal totalAmount = invoice.Amount__c != null ? invoice.Amount__c : 0;
            Decimal paidAmount = invoice.Paid_Amount__c != null ? invoice.Paid_Amount__c : 0;
            Decimal outstandingBalance = invoice.Balance__c != null ? invoice.Balance__c : 0;

            InvoiceDetailData detail = new InvoiceDetailData();
            detail.invoiceNumber = invoice.Invoice_Number__c;
            detail.invoiceDate = invoice.Date__c;
            detail.totalAmount = totalAmount.setScale(2);
            detail.paidAmount = paidAmount.setScale(2);
            detail.paymentsReceivedTotal = paidAmount.setScale(2);
            detail.outstandingBalance = outstandingBalance.setScale(2);
            detail.status = invoice.Status__c;
            detail.teamMatter = invoice.TeamMatter__c;
            detail.matter = invoice.Matter__r?.Name;
            detail.responsibleAttorney = invoice.Matter__r?.Responsible_Attorney__r?.Name;
            detail.invoiceId = invoice.Id;
            result.add(detail);
        }

        return result;
    }

    // Inner class for invoice detail data
    public class InvoiceDetailData {
        @AuraEnabled public String invoiceNumber;
        @AuraEnabled public Date invoiceDate;
        @AuraEnabled public Decimal totalAmount;
        @AuraEnabled public Decimal paidAmount;
        @AuraEnabled public Decimal paymentsReceivedTotal;
        @AuraEnabled public Decimal outstandingBalance;
        @AuraEnabled public String status;
        @AuraEnabled public String teamMatter;
        @AuraEnabled public String matter;
        @AuraEnabled public String responsibleAttorney;
        @AuraEnabled public String invoiceId;
    }

    // Date calculation helper methods - copied from InvoiceDashboardController to ensure consistency
    private static Date calculateStartDate(String filter) {
        Date today = Date.today();
        if (filter == 'Today') {
            return today;
        }
        else if (filter == 'Yesterday') {
            return today.addDays(-1);
        }
        else if (filter == 'This Week') {
            return today.toStartOfWeek();
        }
        else if (filter == 'Last Week') {
            return today.toStartOfWeek().addDays(-7);
        }
        else if (filter == 'This Month') {
            return today.toStartOfMonth();
        }
        else if (filter == 'Last Month') {
            return today.toStartOfMonth().addMonths(-1);
        }
        else if (filter == 'This Quarter') {
            return getQuarterStartDate(today);
        }
        else if (filter == 'Last Quarter') {
            return getQuarterStartDate(today.addMonths(-3));
        }
        else if (filter == 'This Year') {
            return Date.newInstance(today.year(), 1, 1);
        }
        else if (filter == 'Last Year') {
            return Date.newInstance(today.year() - 1, 1, 1);
        }
        return null;
    }

    private static Date calculateEndDate(String filter) {
        Date today = Date.today();
        if (filter == 'Today') {
            return today;
        }
        else if (filter == 'Yesterday') {
            return today.addDays(-1);
        }
        else if (filter == 'This Week') {
            return today.toStartOfWeek().addDays(6);
        }
        else if (filter == 'Last Week') {
            return today.toStartOfWeek().addDays(-1);
        }
        else if (filter == 'This Month') {
            Date firstDay = today.toStartOfMonth();
            return firstDay.addMonths(1).addDays(-1);
        }
        else if (filter == 'Last Month') {
            Date firstDay = today.toStartOfMonth().addMonths(-1);
            return firstDay.addMonths(1).addDays(-1);
        }
        else if (filter == 'This Quarter') {
            return getQuarterEndDate(today);
        }
        else if (filter == 'Last Quarter') {
            return getQuarterEndDate(today.addMonths(-3));
        }
        else if (filter == 'This Year') {
            return Date.newInstance(today.year(), 12, 31);
        }
        else if (filter == 'Last Year') {
            return Date.newInstance(today.year() - 1, 12, 31);
        }
        return null;
    }

    private static Date getQuarterStartDate(Date d) {
        Integer quarter = (d.month() - 1) / 3 + 1;
        Integer month = (quarter - 1) * 3 + 1;
        return Date.newInstance(d.year(), month, 1);
    }

    private static Date getQuarterEndDate(Date d) {
        Integer quarter = (d.month() - 1) / 3 + 1;
        Integer month = quarter * 3;
        return Date.newInstance(d.year(), month, Date.daysInMonth(d.year(), month));
    }
}