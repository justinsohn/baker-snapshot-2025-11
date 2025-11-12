public with sharing class InvoiceDashboardController {

    public class DashboardData {
        @AuraEnabled
        public Decimal totalInvoiced { get; set; }
        @AuraEnabled
        public Decimal paymentsReceived { get; set; }
        @AuraEnabled
        public Decimal outstandingBalance { get; set; }
        @AuraEnabled
        public Decimal collectionRate { get; set; }
        @AuraEnabled
        public List<ChartData> invoicedByTeam { get; set; }
        @AuraEnabled
        public List<ChartData> paymentsByTeam { get; set; }
        @AuraEnabled
        public List<ChartData> outstandingByTeam { get; set; }
        @AuraEnabled
        public List<ChartData> collectionRateByTeam { get; set; }
    }

    public class ChartData {
        @AuraEnabled
        public String label { get; set; }
        @AuraEnabled
        public Decimal value { get; set; }
    }

    public class InvoiceDetailData {
        @AuraEnabled
        public String invoiceNumber { get; set; }
        @AuraEnabled
        public Date invoiceDate { get; set; }
        @AuraEnabled
        public Decimal totalAmount { get; set; }
        @AuraEnabled
        public Decimal paidAmount { get; set; }
        @AuraEnabled
        public Decimal paymentsReceivedTotal { get; set; }
        @AuraEnabled
        public Decimal outstandingBalance { get; set; }
        @AuraEnabled
        public String status { get; set; }
        @AuraEnabled
        public String teamMatter { get; set; }
        @AuraEnabled
        public String matter { get; set; }
        @AuraEnabled
        public String invoiceId { get; set; }
    }

    public class TeamData implements Comparable {
        @AuraEnabled
        public String teamName { get; set; }
        @AuraEnabled
        public Decimal totalInvoiced { get; set; }
        @AuraEnabled
        public Decimal paymentsReceived { get; set; }
        @AuraEnabled
        public Decimal outstandingBalance { get; set; }

        public Integer compareTo(Object compareTo) {
            TeamData compareToTd = (TeamData)compareTo;
            return teamName.compareTo(compareToTd.teamName);
        }
    }

    @AuraEnabled(cacheable=true)
    public static DashboardData getDashboardData(String dateFilter, String teamFilter, String startDate, String endDate) {
        Date calculatedStartDate;
        Date calculatedEndDate;
        
        // Custom date range takes precedence over dropdown filter
        if (String.isNotBlank(startDate) || String.isNotBlank(endDate)) {
            calculatedStartDate = String.isNotBlank(startDate) ? Date.valueOf(startDate) : null;
            calculatedEndDate = String.isNotBlank(endDate) ? Date.valueOf(endDate) : null;
        } else {
            calculatedStartDate = calculateStartDate(dateFilter);
            calculatedEndDate = calculateEndDate(dateFilter);
        }

        List<String> invoiceStatus = new List<String>{'Paid', 'awaiting_payment', 'awaiting_approval'};
        String likeClause = '%' + 'trust' + '%';

        String invoiceQueryString = 'SELECT Id, Amount__c, Balance__c, Paid_Amount__c, TeamMatter__c FROM Invoice__c WHERE (KindOfBill__c = null OR (NOT KindOfBill__c LIKE :likeClause)) AND Status__c IN :invoiceStatus';
        if (calculatedStartDate != null) {
            invoiceQueryString += ' AND Date__c >= :calculatedStartDate';
        }
        if (calculatedEndDate != null) {
            invoiceQueryString += ' AND Date__c <= :calculatedEndDate';
        }
        if (String.isNotBlank(teamFilter) && teamFilter != 'All') {
            invoiceQueryString += ' AND TeamMatter__c = :teamFilter';
        }

        List<Invoice__c> invoices = Database.query(invoiceQueryString);
        Set<Id> invoiceIds = (new Map<Id, SObject>(invoices)).keySet();

        Decimal totalInvoiced = 0;
        for (Invoice__c inv : invoices) {
            if(inv.Amount__c != null) {
                totalInvoiced += inv.Amount__c;
            }
        }

        // Calculate totals using Invoice fields only - no Payment processing needed
        Decimal paymentsReceived = 0;
        Decimal outstandingBalance = 0;
        
        for (Invoice__c inv : invoices) {
            if (inv.Paid_Amount__c != null) {
                paymentsReceived += inv.Paid_Amount__c;
            }
            if (inv.Balance__c != null) {
                outstandingBalance += inv.Balance__c;
            }
        }
        Decimal collectionRate = totalInvoiced > 0 ? (paymentsReceived / totalInvoiced * 100).setScale(1) : 0;

        // Calculate chart data by team
        Map<String, ChartData> invoicedByTeamMap = new Map<String, ChartData>();
        Map<String, ChartData> paymentsByTeamMap = new Map<String, ChartData>();
        Map<String, ChartData> outstandingByTeamMap = new Map<String, ChartData>();
        Map<String, ChartData> collectionRateByTeamMap = new Map<String, ChartData>();

        // Process invoices for team aggregation using simplified Invoice-based logic
        for (Invoice__c inv : invoices) {
            String teamName = String.isNotBlank(inv.TeamMatter__c) ? inv.TeamMatter__c : 'No Team';
            
            // Total Invoiced by Team
            ChartData invoiceData = invoicedByTeamMap.get(teamName);
            if (invoiceData == null) {
                invoiceData = new ChartData();
                invoiceData.label = teamName;
                invoiceData.value = 0;
                invoicedByTeamMap.put(teamName, invoiceData);
            }
            if (inv.Amount__c != null) {
                invoiceData.value += inv.Amount__c;
            }
            
            // Payments Received by Team (using Paid_Amount__c)
            ChartData paymentData = paymentsByTeamMap.get(teamName);
            if (paymentData == null) {
                paymentData = new ChartData();
                paymentData.label = teamName;
                paymentData.value = 0;
                paymentsByTeamMap.put(teamName, paymentData);
            }
            if (inv.Paid_Amount__c != null) {
                paymentData.value += inv.Paid_Amount__c;
            }
            
            // Outstanding Balance by Team (using Balance__c)
            ChartData outstandingData = outstandingByTeamMap.get(teamName);
            if (outstandingData == null) {
                outstandingData = new ChartData();
                outstandingData.label = teamName;
                outstandingData.value = 0;
                outstandingByTeamMap.put(teamName, outstandingData);
            }
            if (inv.Balance__c != null) {
                outstandingData.value += inv.Balance__c;
            }
        }

        // Calculate collection rate by team (Outstanding Balance already calculated above)
        Set<String> allTeams = new Set<String>();
        allTeams.addAll(invoicedByTeamMap.keySet());
        allTeams.addAll(paymentsByTeamMap.keySet());
        allTeams.addAll(outstandingByTeamMap.keySet());

        for (String teamName : allTeams) {
            ChartData invoiceData = invoicedByTeamMap.get(teamName);
            ChartData paymentData = paymentsByTeamMap.get(teamName);
            
            Decimal invoiceAmount = invoiceData != null ? invoiceData.value : 0;
            Decimal paymentAmount = paymentData != null ? paymentData.value : 0;
            
            // Collection rate calculation
            ChartData collectionRateData = new ChartData();
            collectionRateData.label = teamName;
            collectionRateData.value = invoiceAmount > 0 ? (paymentAmount / invoiceAmount * 100).setScale(1) : 0;
            collectionRateByTeamMap.put(teamName, collectionRateData);
        }

        DashboardData data = new DashboardData();
        data.totalInvoiced = totalInvoiced.setScale(2);
        data.paymentsReceived = paymentsReceived.setScale(2);
        data.outstandingBalance = outstandingBalance.setScale(2);
        data.collectionRate = collectionRate;
        data.invoicedByTeam = invoicedByTeamMap.values();
        data.paymentsByTeam = paymentsByTeamMap.values();
        data.outstandingByTeam = outstandingByTeamMap.values();
        data.collectionRateByTeam = collectionRateByTeamMap.values();

        return data;
    }

    @AuraEnabled(cacheable=true)
    public static List<String> getTeamOptions(String dateFilter, String startDate, String endDate) {
        Date calculatedStartDate;
        Date calculatedEndDate;
        
        // Custom date range takes precedence over dropdown filter
        if (String.isNotBlank(startDate) || String.isNotBlank(endDate)) {
            calculatedStartDate = String.isNotBlank(startDate) ? Date.valueOf(startDate) : null;
            calculatedEndDate = String.isNotBlank(endDate) ? Date.valueOf(endDate) : null;
        } else {
            calculatedStartDate = calculateStartDate(dateFilter);
            calculatedEndDate = calculateEndDate(dateFilter);
        }

        String query = 'SELECT TeamMatter__c FROM Invoice__c WHERE TeamMatter__c != null';
        if (calculatedStartDate != null) {
            query += ' AND Date__c >= :calculatedStartDate';
        }
        if (calculatedEndDate != null) {
            query += ' AND Date__c <= :calculatedEndDate';
        }
        query += ' ORDER BY TeamMatter__c';

        List<Invoice__c> invoices = Database.query(query);
        Set<String> teamOptionsSet = new Set<String>();
        for (Invoice__c inv : invoices) {
            teamOptionsSet.add(inv.TeamMatter__c);
        }
        List<String> teamOptions = new List<String>(teamOptionsSet);
        teamOptions.sort();
        return teamOptions;
    }

    @AuraEnabled(cacheable=true)
    public static List<TeamData> getChartData(String dateFilter) {
        Date startDate = calculateStartDate(dateFilter);
        Date endDate = calculateEndDate(dateFilter);

        String likeClause = '%' + 'trust' + '%';
        List<String> invoiceStatus = new List<String>{'Paid', 'awaiting_payment', 'awaiting_approval'};

        String invoiceQueryString = 'SELECT TeamMatter__c, Amount__c, Balance__c FROM Invoice__c WHERE (KindOfBill__c = null OR (NOT KindOfBill__c LIKE :likeClause)) AND Status__c IN :invoiceStatus';
        if (startDate != null) {
            invoiceQueryString += ' AND Date__c >= :startDate';
        }
        if (endDate != null) {
            invoiceQueryString += ' AND Date__c <= :endDate';
        }

        List<Invoice__c> invoices = Database.query(invoiceQueryString);
        Map<Id, String> invoiceIdToTeamMap = new Map<Id, String>();
        for(Invoice__c inv : invoices) {
            invoiceIdToTeamMap.put(inv.Id, inv.TeamMatter__c);
        }


        Map<String, TeamData> teamDataMap = new Map<String, TeamData>();

        for (Invoice__c inv : invoices) {
            String teamName = inv.TeamMatter__c;
            if (teamName == null) {
                teamName = 'No Team';
            }

            TeamData td = teamDataMap.get(teamName);
            if (td == null) {
                td = new TeamData();
                td.teamName = teamName;
                td.totalInvoiced = 0;
                td.paymentsReceived = 0;
                teamDataMap.put(teamName, td);
            }
            if(inv.Amount__c != null) {
                td.totalInvoiced += inv.Amount__c;
            }
        }

        if(!invoiceIdToTeamMap.isEmpty()){
            List<Id> invoiceIdsList = new List<Id>(invoiceIdToTeamMap.keySet());
            String paymentQueryString = 'SELECT Invoice__c, Amount__c FROM Payment__c WHERE Invoice__c IN :invoiceIdsList';
            if (startDate != null) {
                paymentQueryString += ' AND Date__c >= :startDate';
            }
            if (endDate != null) {
                paymentQueryString += ' AND Date__c <= :endDate';
            }

            List<Payment__c> payments = Database.query(paymentQueryString);

            // Calculate payments by invoice first
            Map<Id, Decimal> invoiceToPaymentMap = new Map<Id, Decimal>();
            for (Payment__c p : payments) {
                if (!invoiceToPaymentMap.containsKey(p.Invoice__c)) {
                    invoiceToPaymentMap.put(p.Invoice__c, 0);
                }
                if (p.Amount__c != null) {
                    invoiceToPaymentMap.put(p.Invoice__c, invoiceToPaymentMap.get(p.Invoice__c) + p.Amount__c);
                }
            }
            
            // Add payments and credit notes to team data
            Decimal EPS = 0.01;
            for (Invoice__c inv : invoices) {
                String teamName = inv.TeamMatter__c;
                if (teamName == null) {
                    teamName = 'No Team';
                }
                
                Decimal paidSum = invoiceToPaymentMap.get(inv.Id) != null ? invoiceToPaymentMap.get(inv.Id) : 0;
                Decimal totalAmount = inv.Amount__c != null ? inv.Amount__c : 0;
                Decimal balance = inv.Balance__c != null ? inv.Balance__c : 0;
                
                Decimal expectedOutstanding = totalAmount - paidSum;
                Decimal inferredCredit = expectedOutstanding - balance;
                Decimal creditNoteAmount = (inferredCredit > EPS) ? inferredCredit : 0;
                Decimal paymentsReceivedTotal = paidSum + creditNoteAmount;
                
                TeamData td = teamDataMap.get(teamName);
                if (td == null) {
                    td = new TeamData();
                    td.teamName = teamName;
                    td.totalInvoiced = 0;
                    td.paymentsReceived = 0;
                    teamDataMap.put(teamName, td);
                }
                td.paymentsReceived += paymentsReceivedTotal;
            }
        }


        for (TeamData td : teamDataMap.values()) {
            td.outstandingBalance = td.totalInvoiced - td.paymentsReceived;
        }

        List<TeamData> result = teamDataMap.values();
        result.sort();
        return result;
    }

    @AuraEnabled(cacheable=true)
    public static List<InvoiceDetailData> getInvoiceDetails(String dateFilter, String teamFilter, String metricType, String startDate, String endDate) {
        Date calculatedStartDate;
        Date calculatedEndDate;
        
        // Custom date range takes precedence over dropdown filter
        if (String.isNotBlank(startDate) || String.isNotBlank(endDate)) {
            calculatedStartDate = String.isNotBlank(startDate) ? Date.valueOf(startDate) : null;
            calculatedEndDate = String.isNotBlank(endDate) ? Date.valueOf(endDate) : null;
        } else {
            calculatedStartDate = calculateStartDate(dateFilter);
            calculatedEndDate = calculateEndDate(dateFilter);
        }

        List<String> invoiceStatus = new List<String>{'Paid', 'awaiting_payment', 'awaiting_approval'};
        String likeClause = '%' + 'trust' + '%';

        String invoiceQueryString = 'SELECT Id, Invoice_Number__c, Date__c, Amount__c, Balance__c, Paid_Amount__c, Status__c, TeamMatter__c, Matter__r.Name FROM Invoice__c WHERE (KindOfBill__c = null OR (NOT KindOfBill__c LIKE :likeClause)) AND Status__c IN :invoiceStatus';
        
        if (calculatedStartDate != null) {
            invoiceQueryString += ' AND Date__c >= :calculatedStartDate';
        }
        if (calculatedEndDate != null) {
            invoiceQueryString += ' AND Date__c <= :calculatedEndDate';
        }
        if (String.isNotBlank(teamFilter) && teamFilter != 'All') {
            invoiceQueryString += ' AND TeamMatter__c = :teamFilter';
        }
        invoiceQueryString += ' ORDER BY Date__c DESC';

        List<Invoice__c> invoices = Database.query(invoiceQueryString);

        List<InvoiceDetailData> result = new List<InvoiceDetailData>();
        
        for (Invoice__c invoice : invoices) {
            Decimal totalAmount = invoice.Amount__c != null ? invoice.Amount__c : 0;
            Decimal paidAmount = invoice.Paid_Amount__c != null ? invoice.Paid_Amount__c : 0;
            Decimal outstandingBalance = invoice.Balance__c != null ? invoice.Balance__c : 0;

            // Filter based on metric type
            Boolean includeInvoice = false;
            if (metricType == 'totalInvoiced') {
                includeInvoice = true; // All invoices
            } else if (metricType == 'paymentsReceived') {
                includeInvoice = paidAmount > 0; // Only invoices with payments
            } else if (metricType == 'outstandingBalance') {
                includeInvoice = outstandingBalance > 0; // Only invoices with outstanding balance
            }

            if (includeInvoice) {
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
        }

        return result;
    }

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