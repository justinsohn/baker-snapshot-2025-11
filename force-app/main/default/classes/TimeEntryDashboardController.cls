/**
 * @description Apex controller for the Personal Time Dashboard LWC.
 * Provides methods to fetch time entries and user goals.
 */
public with sharing class TimeEntryDashboardController {

    /**
     * @description Fetches Time_Entry__c records for the current user or their team based on a date range and billable status.
     * @param startDate The start of the date range filter.
     * @param endDate The end of the date range filter.
     * @param billableStatus Filter for 'All', 'Billable', or 'Non-Billable' entries.
     * @param viewTeam Boolean to determine if viewing team data or personal data.
     * @return A list of Time_Entry__c records.
     */
    @AuraEnabled(cacheable=true)
    public static List<Time_Entry__c> getTimeEntries(Date startDate, Date endDate, String billableStatus, Boolean viewTeam) {
        String currentUserId = UserInfo.getUserId();
        String query = 'SELECT Id, Date__c, Non_Billable__c, Matter__r.Name, Note__c, Rate__c, Hours__c';
        
        // Add User name if viewing team data
        if (viewTeam != null && viewTeam) {
            query += ', User__r.Name';
        }
        
        query += ' FROM Time_Entry__c WHERE Date__c >= :startDate AND Date__c <= :endDate ';
        
        // Filter by current user or team
        if (viewTeam != null && viewTeam) {
            // Get current user's team
            User currentUser = [SELECT Team__c FROM User WHERE Id = :currentUserId LIMIT 1];
            if (String.isNotBlank(currentUser.Team__c)) {
                String userTeam = currentUser.Team__c;
                query += 'AND User__r.Team__c = :userTeam ';
            } else {
                // If user has no team, just show their own data
                query += 'AND User__c = :currentUserId ';
            }
        } else {
            // Personal view - just current user
            query += 'AND User__c = :currentUserId ';
        }

        if (String.isNotBlank(billableStatus)) {
            if (billableStatus == 'Billable') {
                query += 'AND Non_Billable__c = false ';
            } else if (billableStatus == 'Non-Billable') {
                query += 'AND Non_Billable__c = true ';
            }
        }
        
        query += 'ORDER BY Date__c DESC, CreatedDate DESC';

        return Database.query(query);
    }

    /**
     * @description Fetches the yearly hour goal and start date for the current user or their team.
     * @param viewTeam Boolean to determine if viewing team data or personal data.
     * @return A wrapper containing target info for either user or team.
     */
    @AuraEnabled(cacheable=true)
    public static TargetInfoWrapper getUserTargetInfo(Boolean viewTeam) {
        String currentUserId = UserInfo.getUserId();
        TargetInfoWrapper result = new TargetInfoWrapper();
        
        if (viewTeam != null && viewTeam) {
            // Get current user's team and aggregate team targets
            User currentUser = [SELECT Team__c FROM User WHERE Id = :currentUserId LIMIT 1];
            if (String.isNotBlank(currentUser.Team__c)) {
                String userTeam = currentUser.Team__c;
                List<User> teamUsers = [SELECT Id, Target_Hours__c, Start_Date__c FROM User WHERE Team__c = :userTeam AND IsActive = true];
                
                Decimal totalTarget = 0;
                Date earliestStartDate = null;
                
                for (User u : teamUsers) {
                    if (u.Target_Hours__c != null) {
                        totalTarget += u.Target_Hours__c;
                    }
                    if (u.Start_Date__c != null && (earliestStartDate == null || u.Start_Date__c < earliestStartDate)) {
                        earliestStartDate = u.Start_Date__c;
                    }
                }
                
                result.targetHours = totalTarget;
                result.startDate = earliestStartDate;
                result.userCount = teamUsers.size();
            } else {
                // If user has no team, return their personal info
                User user = [SELECT Id, Target_Hours__c, Start_Date__c FROM User WHERE Id = :currentUserId LIMIT 1];
                result.targetHours = user.Target_Hours__c;
                result.startDate = user.Start_Date__c;
                result.userCount = 1;
            }
        } else {
            // Personal view
            User user = [SELECT Id, Target_Hours__c, Start_Date__c FROM User WHERE Id = :currentUserId LIMIT 1];
            result.targetHours = user.Target_Hours__c;
            result.startDate = user.Start_Date__c;
            result.userCount = 1;
        }
        
        return result;
    }
    
    // Wrapper class for target info
    public class TargetInfoWrapper {
        @AuraEnabled public Decimal targetHours;
        @AuraEnabled public Date startDate;
        @AuraEnabled public Integer userCount;
    }

    /**
     * @description Fetches collection rate data for the current user or their team based on Invoice records.
     * @param dateFilter The date filter dropdown selection.
     * @param startDate The start of the date range filter.
     * @param endDate The end of the date range filter.
     * @param viewTeam Boolean to determine if viewing team data or personal data.
     * @return Collection rate as a decimal percentage.
     */
    @AuraEnabled(cacheable=true)
    public static Decimal getCollectionRate(String dateFilter, Date startDate, Date endDate, Boolean viewTeam) {
        String currentUserId = UserInfo.getUserId();
        
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

        // Build dynamic query for invoices with Matter relationship - filter by current user's Responsible Attorney
        String invoiceQuery = 'SELECT Id, Amount__c, Paid_Amount__c, TeamMatter__c FROM Invoice__c WHERE (KindOfBill__c = null OR (NOT KindOfBill__c LIKE :likeClause)) AND Status__c IN :invoiceStatus';
        
        if (calculatedStartDate != null) {
            invoiceQuery += ' AND Date__c >= :calculatedStartDate';
        }
        if (calculatedEndDate != null) {
            invoiceQuery += ' AND Date__c <= :calculatedEndDate';
        }

        // Filter by current user or team
        if (viewTeam != null && viewTeam) {
            // Get current user's team
            User currentUser = [SELECT Team__c FROM User WHERE Id = :currentUserId LIMIT 1];
            if (String.isNotBlank(currentUser.Team__c)) {
                String userTeam = currentUser.Team__c;
                invoiceQuery += ' AND TeamMatter__c = :userTeam';
            } else {
                // If user has no team, just show their own data
                invoiceQuery += ' AND Matter__r.Responsible_Attorney__c = :currentUserId';
            }
        } else {
            // Personal view - filter by current user as Responsible Attorney
            invoiceQuery += ' AND Matter__r.Responsible_Attorney__c = :currentUserId';
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
     * @description Fetches detailed invoice information for collection rate modal for the current user or their team.
     * @param dateFilter The date filter dropdown selection.
     * @param startDate The start of the date range filter.
     * @param endDate The end of the date range filter.
     * @param viewTeam Boolean to determine if viewing team data or personal data.
     * @return A list of invoice detail records for the modal.
     */
    @AuraEnabled(cacheable=true)
    public static List<InvoiceDetailData> getCollectionRateDetails(String dateFilter, Date startDate, Date endDate, Boolean viewTeam) {
        String currentUserId = UserInfo.getUserId();
        
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

        // Build dynamic query for invoices with Matter relationship - filter by current user's Responsible Attorney
        String invoiceQuery = 'SELECT Id, Invoice_Number__c, Date__c, Amount__c, Paid_Amount__c, Balance__c, Status__c, TeamMatter__c, Matter__r.Name, Matter__r.Responsible_Attorney__c FROM Invoice__c WHERE (KindOfBill__c = null OR (NOT KindOfBill__c LIKE :likeClause)) AND Status__c IN :invoiceStatus';
        
        if (calculatedStartDate != null) {
            invoiceQuery += ' AND Date__c >= :calculatedStartDate';
        }
        if (calculatedEndDate != null) {
            invoiceQuery += ' AND Date__c <= :calculatedEndDate';
        }

        // Filter by current user or team
        if (viewTeam != null && viewTeam) {
            // Get current user's team
            User currentUser = [SELECT Team__c FROM User WHERE Id = :currentUserId LIMIT 1];
            if (String.isNotBlank(currentUser.Team__c)) {
                String userTeam = currentUser.Team__c;
                invoiceQuery += ' AND TeamMatter__c = :userTeam';
            } else {
                // If user has no team, just show their own data
                invoiceQuery += ' AND Matter__r.Responsible_Attorney__c = :currentUserId';
            }
        } else {
            // Personal view - filter by current user as Responsible Attorney
            invoiceQuery += ' AND Matter__r.Responsible_Attorney__c = :currentUserId';
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
            detail.invoiceId = invoice.Id;
            result.add(detail);
        }

        return result;
    }

    /**
     * @description Gets the current user's team.
     * @return The team name of the current user, or null if no team.
     */
    @AuraEnabled(cacheable=true)
    public static String getCurrentUserTeam() {
        String currentUserId = UserInfo.getUserId();
        User currentUser = [SELECT Team__c FROM User WHERE Id = :currentUserId LIMIT 1];
        return currentUser.Team__c;
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
        @AuraEnabled public String invoiceId;
    }

    // Date calculation helper methods - copied from TeamTimeDashboardController to ensure consistency
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