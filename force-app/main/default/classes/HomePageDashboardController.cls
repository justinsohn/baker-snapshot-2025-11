public with sharing class HomePageDashboardController {
  // Date filter constants
  private static final String TODAY = 'TODAY';
  private static final String YESTERDAY = 'YESTERDAY';
  private static final String THIS_MONTH = 'THIS_MONTH';
  private static final String LAST_MONTH = 'LAST_MONTH';
  private static final String THIS_QUARTER = 'THIS_QUARTER';
  private static final String LAST_QUARTER = 'LAST_QUARTER';
  private static final String THIS_YEAR = 'THIS_YEAR';
  private static final String LAST_YEAR = 'LAST_YEAR';

  // Helper class to hold calculated date ranges
  public class DateRange {
    public Date startDate { get; set; }
    public Date endDate { get; set; }
    public String label { get; set; }
  }

  // All Wrapper Classes (Unchanged)
  public class MatterTreeNode {
    @AuraEnabled
    public String label { get; set; }
    @AuraEnabled
    public String name { get; set; }
    @AuraEnabled
    public Boolean expanded { get; set; }
    @AuraEnabled
    public List<MatterTreeNode> children { get; set; }
    @AuraEnabled
    public String status { get; set; }
    @AuraEnabled
    public String responsibleAttorney { get; set; }
    public MatterTreeNode(String label, String name, Boolean expanded) {
      this.label = label;
      this.name = name;
      this.expanded = expanded;
      this.children = new List<MatterTreeNode>();
    }
    public MatterTreeNode(Matter__c matter) {
      this.label = matter.Name;
      this.name = matter.Id;
      this.status = matter.Status__c;
      this.responsibleAttorney = matter.Responsible_Attorney__r != null
        ? matter.Responsible_Attorney__r.Name
        : 'Unassigned';
      this.expanded = false;
    }
  }
  public class LeadCountSummary {
    @AuraEnabled
    public String period { get; set; }
    @AuraEnabled
    public String periodLabel { get; set; }
    @AuraEnabled
    public Integer leadCount { get; set; }
    public LeadCountSummary(String p, String pl, Integer lc) {
      this.period = p;
      this.periodLabel = pl;
      this.leadCount = lc != null ? lc : 0;
    }
  }

  public class LeadMetricsSummary {
    @AuraEnabled
    public String period { get; set; }
    @AuraEnabled
    public String periodLabel { get; set; }
    @AuraEnabled
    public Integer newLeads { get; set; }
    @AuraEnabled
    public Integer intakeSpecialistCalls { get; set; }
    @AuraEnabled
    public Integer intakeAttorneyCalls { get; set; }
    @AuraEnabled
    public Integer intakeAttorneyNoShows { get; set; }
    @AuraEnabled
    public Integer totalClosedByIS { get; set; }
    @AuraEnabled
    public Integer totalClosedByIA { get; set; }

    public LeadMetricsSummary(
      String p,
      String pl,
      Integer nl,
      Integer isc,
      Integer iac,
      Integer ians,
      Integer tcis,
      Integer tcia
    ) {
      this.period = p;
      this.periodLabel = pl;
      this.newLeads = nl != null ? nl : 0;
      this.intakeSpecialistCalls = isc != null ? isc : 0;
      this.intakeAttorneyCalls = iac != null ? iac : 0;
      this.intakeAttorneyNoShows = ians != null ? ians : 0;
      this.totalClosedByIS = tcis != null ? tcis : 0;
      this.totalClosedByIA = tcia != null ? tcia : 0;
    }
  }
  public class LeadSourceConversionSummary implements Comparable {
    @AuraEnabled
    public String source { get; set; }
    @AuraEnabled
    public Decimal conversionRate { get; set; }
    @AuraEnabled
    public Integer totalClosed { get; set; }
    @AuraEnabled
    public Integer totalLeads { get; set; }
    public LeadSourceConversionSummary(
      String s,
      Decimal cr,
      Integer tc,
      Integer tl
    ) {
      this.source = s;
      this.conversionRate = cr != null ? cr : 0;
      this.totalClosed = tc != null ? tc : 0;
      this.totalLeads = tl != null ? tl : 0;
    }
    public Integer compareTo(Object compareTo) {
      LeadSourceConversionSummary other = (LeadSourceConversionSummary) compareTo;
      if (this.source == null)
        return -1;
      if (other.source == null)
        return 1;
      return this.source.compareTo(other.source);
    }
  }
  public class AttorneyCloseRateSummary implements Comparable {
    @AuraEnabled
    public String attorneyName { get; set; }
    @AuraEnabled
    public Decimal closeRate { get; set; }
    @AuraEnabled
    public Integer totalClosed { get; set; }
    @AuraEnabled
    public Integer totalLeads { get; set; }
    public AttorneyCloseRateSummary(
      String name,
      Decimal rate,
      Integer closed,
      Integer total
    ) {
      this.attorneyName = name;
      this.closeRate = rate;
      this.totalClosed = closed;
      this.totalLeads = total;
    }
    public Integer compareTo(Object compareTo) {
      AttorneyCloseRateSummary other = (AttorneyCloseRateSummary) compareTo;
      if (this.attorneyName == null)
        return -1;
      if (other.attorneyName == null)
        return 1;
      return this.attorneyName.compareTo(other.attorneyName);
    }
  }
  public class LeadSourceCountSummary {
    @AuraEnabled
    public String source { get; set; }
    @AuraEnabled
    public Integer leadCount { get; set; }
    public LeadSourceCountSummary(String s, Integer lc) {
      this.source = s;
      this.leadCount = lc != null ? lc : 0;
    }
  }

  public class LeadSourceCountComparator implements Comparator<LeadSourceCountSummary> {
    public Integer compare(LeadSourceCountSummary a, LeadSourceCountSummary b) {
      Integer aCount = a.leadCount != null ? a.leadCount : 0;
      Integer bCount = b.leadCount != null ? b.leadCount : 0;
      Integer countComparison = bCount - aCount;
      if (countComparison != 0) {
        return countComparison;
      }
      if (a.source == b.source) {
        return 0;
      }
      if (a.source == null) {
        return 1;
      }
      if (b.source == null) {
        return -1;
      }
      return a.source.toLowerCase().compareTo(b.source.toLowerCase());
    }
  }

  private static String normalizeLeadSource(Lead leadRecord) {
    String candidate = cleanQueryBasedSource(leadRecord.Source__c);
    if (String.isBlank(candidate) && !String.isBlank(leadRecord.LeadSource)) {
      candidate = leadRecord.LeadSource.trim();
    }
    if (String.isBlank(candidate)) {
      return null;
    }
    return candidate;
  }

  private static String cleanQueryBasedSource(String raw) {
    if (String.isBlank(raw)) {
      return null;
    }

    String trimmed = raw.trim();
    if (trimmed.startsWith('=')) {
      trimmed = trimmed.substring(1).trim();
    }

    String parsed = extractQueryParam(trimmed, 'utm_source');
    if (String.isBlank(parsed)) {
      parsed = extractQueryParam(trimmed, 'source');
    }

    String candidate = String.isBlank(parsed) ? trimmed : parsed.trim();
    if (candidate.startsWith('=')) {
      candidate = candidate.substring(1).trim();
    }

    candidate = stripNoiseMarkers(candidate);
    if (candidate != null && candidate.contains('%')) {
      candidate = EncodingUtil.urlDecode(candidate, 'UTF-8');
    }
    if (candidate != null) {
      candidate = candidate.replace('+', ' ').trim();
    }

    return String.isBlank(candidate) ? null : candidate;
  }

  private static String extractQueryParam(String value, String param) {
    if (String.isBlank(value)) {
      return null;
    }
    String lowerValue = value.toLowerCase();
    String key = param.toLowerCase() + '=';
    Integer startIdx = lowerValue.indexOf(key);
    if (startIdx == -1) {
      return null;
    }
    Integer valueStart = startIdx + key.length();
    String remainder = value.substring(valueStart);
    Integer ampIdx = remainder.indexOf('&');
    if (ampIdx != -1) {
      remainder = remainder.substring(0, ampIdx);
    }
    return remainder;
  }

  private static String stripNoiseMarkers(String value) {
    if (String.isBlank(value)) {
      return null;
    }

    String cleaned = value.trim();
    if (cleaned.startsWith('=')) {
      cleaned = cleaned.substring(1).trim();
    }

    List<String> noiseMarkers = new List<String>{
      'searchcampaign',
      'gbpcampaign',
      'campaign:',
      'campaign',
      'pageid',
      'utm_',
      '&',
      '?'
    };

    cleaned = trimAtMarkers(cleaned, noiseMarkers);

    Integer explicitSourceIdx = cleaned.toLowerCase().lastIndexOf('source:');
    if (explicitSourceIdx > -1) {
      cleaned = cleaned.substring(explicitSourceIdx + 'source:'.length())
        .trim();
      cleaned = trimAtMarkers(cleaned, noiseMarkers);
    }

    Integer colonIndex = cleaned.indexOf(':');
    if (colonIndex > -1) {
      String prefix = cleaned.substring(0, colonIndex).toLowerCase();
      if (
        prefix.endsWith('source') ||
        prefix.endsWith('campaign') ||
        prefix.endsWith('channel')
      ) {
        cleaned = cleaned.substring(colonIndex + 1).trim();
      }
    }

    if (cleaned.endsWith('.')) {
      cleaned = cleaned.substring(0, cleaned.length() - 1).trim();
    }

    return cleaned;
  }

  private static String trimAtMarkers(String value, List<String> markers) {
    if (String.isBlank(value)) {
      return null;
    }
    String cleaned = value;
    Boolean shortened = true;
    while (shortened && !String.isBlank(cleaned)) {
      shortened = false;
      String lower = cleaned.toLowerCase();
      for (String marker : markers) {
        Integer idx = lower.indexOf(marker);
        if (idx > -1 && idx > 0) {
          cleaned = cleaned.substring(0, idx).trim();
          shortened = true;
          break;
        }
      }
    }
    return cleaned;
  }
  public class IntakeCompletionSummary {
    @AuraEnabled
    public String ownerName { get; set; }
    @AuraEnabled
    public Integer intakeCount { get; set; }
    public IntakeCompletionSummary(String o, Integer i) {
      this.ownerName = o;
      this.intakeCount = i != null ? i : 0;
    }
  }

  public class IntakeCompletionComparator implements Comparator<IntakeCompletionSummary> {
    public Integer compare(
      IntakeCompletionSummary a,
      IntakeCompletionSummary b
    ) {
      // Sort by count descending (higher counts first)
      return b.intakeCount - a.intakeCount;
    }
  }

  public class ComboboxOption {
    @AuraEnabled
    public String label { get; set; }
    @AuraEnabled
    public String value { get; set; }
    public ComboboxOption(String l, String v) {
      label = l;
      value = v;
    }
  }
  public class LeadDetail {
    @AuraEnabled
    public Id Id { get; set; }
    @AuraEnabled
    public String Name { get; set; }
    @AuraEnabled
    public Date CreatedDate { get; set; }
    @AuraEnabled
    public String Status { get; set; }
    @AuraEnabled
    public String OwnerName { get; set; }
    @AuraEnabled
    public String PracticeArea { get; set; }
    public LeadDetail(Lead l) {
      this.Id = l.Id;
      this.Name = l.Name;
      this.CreatedDate = Date.valueOf(l.CreatedDate);
      this.Status = l.Status;
      this.OwnerName = l.Owner.Name;
      this.PracticeArea = l.Category__c;
    }
  }
  public class SQLLeadDetail {
    @AuraEnabled
    public Id Id { get; set; }
    @AuraEnabled
    public String Name { get; set; }
    @AuraEnabled
    public Date CreatedDate { get; set; }
    @AuraEnabled
    public String Status { get; set; }
    @AuraEnabled
    public String OwnerName { get; set; }
    @AuraEnabled
    public String PracticeArea { get; set; }
    @AuraEnabled
    public String PreferredOfficeLocation { get; set; }
    @AuraEnabled
    public String TeamLead { get; set; }
    public SQLLeadDetail(Lead l) {
      this.Id = l.Id;
      this.Name = l.Name;
      this.CreatedDate = Date.valueOf(l.CreatedDate);
      this.Status = l.Status;
      this.OwnerName = l.Owner.Name;
      this.PracticeArea = l.Category__c;
      this.PreferredOfficeLocation = l.Preferred_Office_Location__c;
      this.TeamLead = l.Supervising_Attorney__r != null
        ? l.Supervising_Attorney__r.Name
        : null;
    }
  }
  public class MatterDetail {
    @AuraEnabled
    public Id Id { get; set; }
    @AuraEnabled
    public String Name { get; set; }
    @AuraEnabled
    public String practiceArea { get; set; }
    @AuraEnabled
    public String status { get; set; }
    public MatterDetail(Matter__c m) {
      this.Id = m.Id;
      this.Name = m.Name;
      this.practiceArea = m.Practice_Area__c;
      this.status = m.Status__c;
    }
  }
  public class LandingPageLeadSummary implements Comparable {
    @AuraEnabled
    public String landingPage { get; set; }
    @AuraEnabled
    public Integer leadCount { get; set; }
    public LandingPageLeadSummary(String page, Integer count) {
      this.landingPage = page;
      this.leadCount = count;
    }
    public Integer compareTo(Object compareTo) {
      LandingPageLeadSummary other = (LandingPageLeadSummary) compareTo;
      return other.leadCount - this.leadCount;
    }
  }
  public class PracticeAreaLeadSummary implements Comparable {
    @AuraEnabled
    public String practiceArea { get; set; }
    @AuraEnabled
    public Integer leadCount { get; set; }
    public PracticeAreaLeadSummary(String pa, Integer count) {
      this.practiceArea = pa;
      this.leadCount = count;
    }
    public Integer compareTo(Object compareTo) {
      PracticeAreaLeadSummary other = (PracticeAreaLeadSummary) compareTo;
      return other.leadCount - this.leadCount;
    }
  }
  public class MatterPipelineSummary {
    @AuraEnabled
    public String practiceArea { get; set; }
    @AuraEnabled
    public Integer openCount { get; set; }
    @AuraEnabled
    public Integer pendingCount { get; set; }
    @AuraEnabled
    public Integer totalCount { get; set; }
    public MatterPipelineSummary(String pa, Integer open, Integer pending) {
      this.practiceArea = pa;
      this.openCount = open;
      this.pendingCount = pending;
      this.totalCount = open + pending;
    }
  }
  public class MatterPipelineComparator implements Comparator<MatterPipelineSummary> {
    public Integer compare(MatterPipelineSummary a, MatterPipelineSummary b) {
      return b.totalCount - a.totalCount;
    }
  }
  public class SQLTrendPoint {
    @AuraEnabled
    public String period { get; set; }
    @AuraEnabled
    public Integer sqlCount { get; set; }
    @AuraEnabled
    public Date periodDate { get; set; }
    @AuraEnabled
    public String periodLabel { get; set; }
    public SQLTrendPoint(String p, Integer sc, Date pd, String pl) {
      this.period = p;
      this.sqlCount = sc != null ? sc : 0;
      this.periodDate = pd;
      this.periodLabel = pl;
    }
  }

  //  Methods for filter dropdowns
  @AuraEnabled(cacheable=true)
  public static List<ComboboxOption> getPracticeAreaOptions() {
    List<ComboboxOption> options = new List<ComboboxOption>();
    options.add(new ComboboxOption('All Practice Areas', ''));
    Schema.DescribeFieldResult fieldResult = Lead.Category__c.getDescribe();
    List<Schema.PicklistEntry> ple = fieldResult.getPicklistValues();
    for (Schema.PicklistEntry f : ple) {
      options.add(new ComboboxOption(f.getLabel(), f.getValue()));
    }
    return options;
  }

  @AuraEnabled(cacheable=true)
  public static List<ComboboxOption> getTypeOfCivilLawOptions() {
    List<ComboboxOption> options = new List<ComboboxOption>();
    options.add(new ComboboxOption('All Types of Civil Law', ''));
    Schema.DescribeFieldResult fieldResult = Lead.Type_of_Civil_Law__c.getDescribe();
    List<Schema.PicklistEntry> ple = fieldResult.getPicklistValues();
    for (Schema.PicklistEntry f : ple) {
      options.add(new ComboboxOption(f.getLabel(), f.getValue()));
    }
    return options;
  }

  @AuraEnabled(cacheable=true)
  public static List<ComboboxOption> getOfficeLocationOptions() {
    List<ComboboxOption> options = new List<ComboboxOption>();
    options.add(new ComboboxOption('All Office Locations', ''));

    // Get distinct office locations from actual lead data
    try {
      List<AggregateResult> results = [
        SELECT Preferred_Office_Location__c location
        FROM Lead
        WHERE
          Preferred_Office_Location__c != NULL
          AND Preferred_Office_Location__c != ''
        GROUP BY Preferred_Office_Location__c
        ORDER BY Preferred_Office_Location__c
      ];

      for (AggregateResult result : results) {
        String location = (String) result.get('location');
        if (String.isNotBlank(location)) {
          options.add(new ComboboxOption(location, location));
        }
      }
    } catch (Exception e) {
      System.debug('Error getting office locations: ' + e.getMessage());
      // Fallback to picklist values if query fails
      Schema.DescribeFieldResult fieldResult = Lead.Preferred_Office_Location__c.getDescribe();
      List<Schema.PicklistEntry> ple = fieldResult.getPicklistValues();
      for (Schema.PicklistEntry f : ple) {
        options.add(new ComboboxOption(f.getLabel(), f.getValue()));
      }
    }

    return options;
  }

  // Unchanged method - not governed by date filter
  @AuraEnabled(cacheable=true)
  public static List<MatterTreeNode> getMatterTreeData(String practiceArea) {
    String query = 'SELECT Id, Name, Status__c, Practice_Area__c, Responsible_Attorney__c, Responsible_Attorney__r.Name FROM Matter__c WHERE Status__c IN (\'Open\', \'Pending\')';
    if (String.isNotBlank(practiceArea)) {
      query += ' AND Practice_Area__c = :practiceArea';
    }
    query += ' ORDER BY Practice_Area__c, Responsible_Attorney__r.Name, Name';
    List<Matter__c> matters = Database.query(query);
    Map<String, Map<String, List<Matter__c>>> groupedData = new Map<String, Map<String, List<Matter__c>>>();
    for (Matter__c matter : matters) {
      String pa = String.isBlank(matter.Practice_Area__c)
        ? 'Uncategorized'
        : matter.Practice_Area__c;
      String attorney = matter.Responsible_Attorney__r != null
        ? matter.Responsible_Attorney__r.Name
        : 'Unassigned';
      if (!groupedData.containsKey(pa)) {
        groupedData.put(pa, new Map<String, List<Matter__c>>());
      }
      if (!groupedData.get(pa).containsKey(attorney)) {
        groupedData.get(pa).put(attorney, new List<Matter__c>());
      }
      groupedData.get(pa).get(attorney).add(matter);
    }
    List<MatterTreeNode> treeNodes = new List<MatterTreeNode>();
    for (String paKey : groupedData.keySet()) {
      MatterTreeNode paNode = new MatterTreeNode(paKey, paKey, true);
      for (String attorneyKey : groupedData.get(paKey).keySet()) {
        MatterTreeNode attorneyNode = new MatterTreeNode(
          attorneyKey,
          paKey + '-' + attorneyKey,
          false
        );
        for (Matter__c matter : groupedData.get(paKey).get(attorneyKey)) {
          attorneyNode.children.add(new MatterTreeNode(matter));
        }
        paNode.children.add(attorneyNode);
      }
      treeNodes.add(paNode);
    }
    return treeNodes;
  }

  // =========================================================================
  // DATA FETCHING METHODS
  // =========================================================================

  @AuraEnabled(cacheable=true)
  public static LeadCountSummary getLeadCount(
    String dateFilter,
    String practiceArea,
    String officeLocation,
    String typeOfCivilLaw
  ) {
    DateRange dr = getDateRangeForFilter(dateFilter);
    DateTime startDateTime = DateTime.newInstance(
      dr.startDate,
      Time.newInstance(0, 0, 0, 0)
    );
    DateTime endDateTime = DateTime.newInstance(
      dr.endDate.addDays(1),
      Time.newInstance(0, 0, 0, 0)
    );
    String query = 'SELECT COUNT() FROM Lead WHERE CreatedDate >= :startDateTime AND CreatedDate < :endDateTime';
    if (String.isNotBlank(practiceArea)) {
      query += ' AND Category__c = :practiceArea';
    }
    if (String.isNotBlank(officeLocation)) {
      query += ' AND Preferred_Office_Location__c = :officeLocation';
    }
    if (String.isNotBlank(typeOfCivilLaw)) {
      query += ' AND Type_of_Civil_Law__c = :typeOfCivilLaw';
    }
    return new LeadCountSummary(
      dateFilter,
      dr.label,
      Database.countQuery(query)
    );
  }

  @AuraEnabled(cacheable=true)
  public static LeadMetricsSummary getLeadMetrics(
    String dateFilter,
    String practiceArea,
    String officeLocation,
    String typeOfCivilLaw
  ) {
    DateRange dr = getDateRangeForFilter(dateFilter);
    DateTime startDateTime = DateTime.newInstance(
      dr.startDate,
      Time.newInstance(0, 0, 0, 0)
    );
    DateTime endDateTime = DateTime.newInstance(
      dr.endDate.addDays(1),
      Time.newInstance(0, 0, 0, 0)
    );

    // Date variables for Post_Con_Completed_Date__c (Date field)
    Date startDate = dr.startDate;
    Date endDate = dr.endDate;

    // Base WHERE clause with CreatedDate (for New Leads)
    String baseWhereCreatedDate = 'CreatedDate >= :startDateTime AND CreatedDate < :endDateTime';
    if (String.isNotBlank(practiceArea)) {
      baseWhereCreatedDate += ' AND Category__c = :practiceArea';
    }
    if (String.isNotBlank(officeLocation)) {
      baseWhereCreatedDate += ' AND Preferred_Office_Location__c = :officeLocation';
    }
    if (String.isNotBlank(typeOfCivilLaw)) {
      baseWhereCreatedDate += ' AND Type_of_Civil_Law__c = :typeOfCivilLaw';
    }

    // Base WHERE clause with Post_Con_Completed_Date__c (for all other metrics)
    String baseWherePostCon = 'Post_Con_Completed_Date__c >= :startDate AND Post_Con_Completed_Date__c <= :endDate';
    if (String.isNotBlank(practiceArea)) {
      baseWherePostCon += ' AND Category__c = :practiceArea';
    }
    if (String.isNotBlank(officeLocation)) {
      baseWherePostCon += ' AND Preferred_Office_Location__c = :officeLocation';
    }
    if (String.isNotBlank(typeOfCivilLaw)) {
      baseWherePostCon += ' AND Type_of_Civil_Law__c = :typeOfCivilLaw';
    }

    // 1. New Leads (uses CreatedDate)
    String newLeadsQuery =
      'SELECT COUNT() FROM Lead WHERE ' + baseWhereCreatedDate;
    Integer newLeads = Database.countQuery(newLeadsQuery);

    // 2. Total Intake Specialist Calls (uses Post_Con_Completed_Date__c)
    String intakeSpecialistCallsQuery =
      'SELECT COUNT() FROM Lead WHERE ' +
      baseWherePostCon +
      ' AND Post_Consult_Complete__c = true AND Intake_Attorney__c = null AND Were_you_able_to_speak_with_client__c != \'No (No Show)\'';
    Integer intakeSpecialistCalls = Database.countQuery(
      intakeSpecialistCallsQuery
    );

    // 3. Total Intake Attorney Calls (uses Post_Con_Completed_Date__c)
    String intakeAttorneyCallsQuery =
      'SELECT COUNT() FROM Lead WHERE ' +
      baseWherePostCon +
      ' AND Intake_Attorney__c != null AND Post_Consult_Complete__c = true AND Were_you_able_to_speak_with_client__c != \'No (No Show)\'';
    Integer intakeAttorneyCalls = Database.countQuery(intakeAttorneyCallsQuery);

    // 4. Intake Attorney No Shows (uses Post_Con_Completed_Date__c)
    String intakeAttorneyNoShowsQuery =
      'SELECT COUNT() FROM Lead WHERE ' +
      baseWherePostCon +
      ' AND Intake_Attorney__c != null AND Were_you_able_to_speak_with_client__c = \'No (No Show)\' AND Post_Consult_Complete__c = true';
    Integer intakeAttorneyNoShows = Database.countQuery(
      intakeAttorneyNoShowsQuery
    );

    // Base WHERE clause for closed queries (uses Matter__r.Date_First_Payment__c)
    String baseWhereClosed = 'Matter__r.Date_First_Payment__c >= :startDate AND Matter__r.Date_First_Payment__c <= :endDate';
    if (String.isNotBlank(practiceArea)) {
      baseWhereClosed += ' AND Category__c = :practiceArea';
    }
    if (String.isNotBlank(officeLocation)) {
      baseWhereClosed += ' AND Preferred_Office_Location__c = :officeLocation';
    }
    if (String.isNotBlank(typeOfCivilLaw)) {
      baseWhereClosed += ' AND Type_of_Civil_Law__c = :typeOfCivilLaw';
    }

    // 5. Total Closed by Intake Specialist (uses Matter__r.Date_First_Payment__c)
    String totalClosedByISQuery =
      'SELECT COUNT() FROM Lead WHERE ' +
      baseWhereClosed +
      ' AND Intake_Attorney__c = null AND Matter__c != null AND Matter__r.Date_FA_was_sent__c != null AND Matter__r.Date_First_Payment__c != null';
    Integer totalClosedByIS = Database.countQuery(totalClosedByISQuery);

    // 6. Total Closed by Intake Attorney (uses Matter__r.Date_First_Payment__c)
    String totalClosedByIAQuery =
      'SELECT COUNT() FROM Lead WHERE ' +
      baseWhereClosed +
      ' AND Intake_Attorney__c != null AND Matter__c != null AND Matter__r.Date_FA_was_sent__c != null AND Matter__r.Date_First_Payment__c != null';
    Integer totalClosedByIA = Database.countQuery(totalClosedByIAQuery);

    return new LeadMetricsSummary(
      dateFilter,
      dr.label,
      newLeads,
      intakeSpecialistCalls,
      intakeAttorneyCalls,
      intakeAttorneyNoShows,
      totalClosedByIS,
      totalClosedByIA
    );
  }

  @AuraEnabled(cacheable=true)
  public static List<LeadSourceConversionSummary> getLeadConversionBySource(
    String dateFilter,
    String practiceArea,
    String officeLocation,
    String typeOfCivilLaw
  ) {
    DateRange dr = getDateRangeForFilter(dateFilter);
    DateTime startDateTime = DateTime.newInstance(
      dr.startDate,
      Time.newInstance(0, 0, 0, 0)
    );
    DateTime endDateTime = DateTime.newInstance(
      dr.endDate.addDays(1),
      Time.newInstance(0, 0, 0, 0)
    );
    Map<String, Integer> totalBySource = new Map<String, Integer>();
    Map<String, Integer> convertedBySource = new Map<String, Integer>();
    String baseQuery = 'SELECT Source__c, LeadSource, Status FROM Lead WHERE CreatedDate >= :startDateTime AND CreatedDate < :endDateTime';
    if (String.isNotBlank(practiceArea)) {
      baseQuery += ' AND Category__c = :practiceArea';
    }
    if (String.isNotBlank(officeLocation)) {
      baseQuery += ' AND Preferred_Office_Location__c = :officeLocation';
    }
    if (String.isNotBlank(typeOfCivilLaw)) {
      baseQuery += ' AND Type_of_Civil_Law__c = :typeOfCivilLaw';
    }

    List<Lead> leads = Database.query(baseQuery);
    for (Lead leadRecord : leads) {
      String sourceKey = normalizeLeadSource(leadRecord);
      if (String.isBlank(sourceKey)) {
        continue;
      }

      if (!totalBySource.containsKey(sourceKey)) {
        totalBySource.put(sourceKey, 0);
      }
      totalBySource.put(sourceKey, totalBySource.get(sourceKey) + 1);

      if (
        leadRecord.Status == 'Closed - Converted' ||
        leadRecord.Status == 'Qualified'
      ) {
        if (!convertedBySource.containsKey(sourceKey)) {
          convertedBySource.put(sourceKey, 0);
        }
        convertedBySource.put(sourceKey, convertedBySource.get(sourceKey) + 1);
      }
    }
    List<LeadSourceConversionSummary> summaries = new List<LeadSourceConversionSummary>();
    for (String source : totalBySource.keySet()) {
      Integer total = totalBySource.get(source);
      Integer converted = convertedBySource.get(source) == null
        ? 0
        : convertedBySource.get(source);
      Decimal rate = total > 0 ? ((Decimal) converted / total) * 100 : 0;
      summaries.add(
        new LeadSourceConversionSummary(source, rate, converted, total)
      );
    }
    summaries.sort();
    return summaries;
  }

  @AuraEnabled(cacheable=true)
  public static List<LeadSourceCountSummary> getTotalLeadsBySource(
    String dateFilter,
    String practiceArea,
    String officeLocation,
    String typeOfCivilLaw
  ) {
    DateRange dr = getDateRangeForFilter(dateFilter);
    DateTime startDateTime = DateTime.newInstance(
      dr.startDate,
      Time.newInstance(0, 0, 0, 0)
    );
    DateTime endDateTime = DateTime.newInstance(
      dr.endDate.addDays(1),
      Time.newInstance(0, 0, 0, 0)
    );
    List<LeadSourceCountSummary> summaries = new List<LeadSourceCountSummary>();
    String query = 'SELECT Source__c, LeadSource FROM Lead WHERE CreatedDate >= :startDateTime AND CreatedDate < :endDateTime';
    if (String.isNotBlank(practiceArea)) {
      query += ' AND Category__c = :practiceArea';
    }
    if (String.isNotBlank(officeLocation)) {
      query += ' AND Preferred_Office_Location__c = :officeLocation';
    }
    if (String.isNotBlank(typeOfCivilLaw)) {
      query += ' AND Type_of_Civil_Law__c = :typeOfCivilLaw';
    }
    Map<String, Integer> countsBySource = new Map<String, Integer>();
    for (Lead leadRecord : Database.query(query)) {
      String sourceKey = normalizeLeadSource(leadRecord);
      if (String.isBlank(sourceKey)) {
        continue;
      }
      if (!countsBySource.containsKey(sourceKey)) {
        countsBySource.put(sourceKey, 0);
      }
      countsBySource.put(sourceKey, countsBySource.get(sourceKey) + 1);
    }

    for (String sourceKey : countsBySource.keySet()) {
      summaries.add(
        new LeadSourceCountSummary(sourceKey, countsBySource.get(sourceKey))
      );
    }

    summaries.sort(new LeadSourceCountComparator());
    return summaries;
  }

  @AuraEnabled(cacheable=true)
  public static List<LandingPageLeadSummary> getLeadsByLandingPage(
    String dateFilter,
    String practiceArea,
    String officeLocation,
    String typeOfCivilLaw
  ) {
    DateRange dr = getDateRangeForFilter(dateFilter);
    DateTime startDateTime = DateTime.newInstance(
      dr.startDate,
      Time.newInstance(0, 0, 0, 0)
    );
    DateTime endDateTime = DateTime.newInstance(
      dr.endDate.addDays(1),
      Time.newInstance(0, 0, 0, 0)
    );
    List<LandingPageLeadSummary> summaries = new List<LandingPageLeadSummary>();
    String query = 'SELECT Landing_Page__c, COUNT(Id) cnt FROM Lead WHERE Landing_Page__c != null AND CreatedDate >= :startDateTime AND CreatedDate < :endDateTime';
    if (String.isNotBlank(practiceArea)) {
      query += ' AND Category__c = :practiceArea';
    }
    if (String.isNotBlank(officeLocation)) {
      query += ' AND Preferred_Office_Location__c = :officeLocation';
    }
    if (String.isNotBlank(typeOfCivilLaw)) {
      query += ' AND Type_of_Civil_Law__c = :typeOfCivilLaw';
    }
    query += ' GROUP BY Landing_Page__c ORDER BY COUNT(Id) DESC';
    for (AggregateResult ar : Database.query(query)) {
      summaries.add(
        new LandingPageLeadSummary(
          (String) ar.get('Landing_Page__c'),
          (Integer) ar.get('cnt')
        )
      );
    }
    return summaries;
  }

  @AuraEnabled(cacheable=true)
  public static List<PracticeAreaLeadSummary> getLeadsByPracticeArea(
    String dateFilter,
    String practiceArea,
    String officeLocation,
    String typeOfCivilLaw
  ) {
    DateRange dr = getDateRangeForFilter(dateFilter);
    DateTime startDateTime = DateTime.newInstance(
      dr.startDate,
      Time.newInstance(0, 0, 0, 0)
    );
    DateTime endDateTime = DateTime.newInstance(
      dr.endDate.addDays(1),
      Time.newInstance(0, 0, 0, 0)
    );
    List<PracticeAreaLeadSummary> summaries = new List<PracticeAreaLeadSummary>();
    String query = 'SELECT Category__c, COUNT(Id) cnt FROM Lead WHERE Category__c != null AND CreatedDate >= :startDateTime AND CreatedDate < :endDateTime';
    if (String.isNotBlank(practiceArea)) {
      query += ' AND Category__c = :practiceArea';
    }
    if (String.isNotBlank(officeLocation)) {
      query += ' AND Preferred_Office_Location__c = :officeLocation';
    }
    if (String.isNotBlank(typeOfCivilLaw)) {
      query += ' AND Type_of_Civil_Law__c = :typeOfCivilLaw';
    }
    query += ' GROUP BY Category__c ORDER BY COUNT(Id) DESC';
    for (AggregateResult ar : Database.query(query)) {
      summaries.add(
        new PracticeAreaLeadSummary(
          (String) ar.get('Category__c'),
          (Integer) ar.get('cnt')
        )
      );
    }
    return summaries;
  }

  @AuraEnabled(cacheable=true)
  public static List<MatterPipelineSummary> getMatterPipelineData(
    String practiceArea
  ) {
    Map<String, MatterPipelineSummary> summaryMap = new Map<String, MatterPipelineSummary>();

    String query = 'SELECT Practice_Area__c, Status__c, COUNT(Id) cnt FROM Matter__c WHERE Status__c IN (\'Open\', \'Pending\')';
    if (String.isNotBlank(practiceArea)) {
      query += ' AND Practice_Area__c = :practiceArea';
    }
    query += ' GROUP BY Practice_Area__c, Status__c';

    for (AggregateResult ar : Database.query(query)) {
      String pa = (String) ar.get('Practice_Area__c');
      if (String.isBlank(pa))
        pa = 'Uncategorized';
      String status = (String) ar.get('Status__c');
      Integer count = (Integer) ar.get('cnt');

      if (!summaryMap.containsKey(pa)) {
        summaryMap.put(pa, new MatterPipelineSummary(pa, 0, 0));
      }

      MatterPipelineSummary summary = summaryMap.get(pa);
      if (status == 'Open') {
        summary.openCount += count;
      } else if (status == 'Pending') {
        summary.pendingCount += count;
      }
      summary.totalCount = summary.openCount + summary.pendingCount;
    }

    List<MatterPipelineSummary> summaries = new List<MatterPipelineSummary>(
      summaryMap.values()
    );

    // Sort by total count descending using a comparator
    summaries.sort(new MatterPipelineComparator());

    // Limit to top 10 practice areas
    if (summaries.size() > 10) {
      List<MatterPipelineSummary> topSummaries = new List<MatterPipelineSummary>();
      for (Integer i = 0; i < 10; i++) {
        topSummaries.add(summaries[i]);
      }
      summaries = topSummaries;
    }

    return summaries;
  }

  @AuraEnabled(cacheable=true)
  public static List<AttorneyCloseRateSummary> getCloseRateByAttorney(
    String dateFilter,
    String practiceArea,
    String officeLocation,
    String typeOfCivilLaw
  ) {
    DateRange dr = getDateRangeForFilter(dateFilter);
    Date startDate = dr.startDate;
    Date endDate = dr.endDate;

    Map<String, Integer> postConsultByAttorney = new Map<String, Integer>();
    Map<String, Integer> closedByAttorney = new Map<String, Integer>();

    // Base WHERE clause for all queries - use Post_Con_Completed_Date__c
    String baseWhere = 'WHERE Post_Con_Completed_Date__c >= :startDate AND Post_Con_Completed_Date__c <= :endDate';
    if (String.isNotBlank(practiceArea)) {
      baseWhere += ' AND Category__c = :practiceArea';
    }
    if (String.isNotBlank(officeLocation)) {
      baseWhere += ' AND Preferred_Office_Location__c = :officeLocation';
    }
    if (String.isNotBlank(typeOfCivilLaw)) {
      baseWhere += ' AND Type_of_Civil_Law__c = :typeOfCivilLaw';
    }

    // Query 1: "At bat" leads by Intake Attorney (Post Consult Complete = true AND Were_you_able_to_speak_with_client__c != 'No (No Show)')
    String intakeAttorneyPostConsultQuery =
      'SELECT Intake_Attorney__r.Name attorneyName, COUNT(Id) cnt FROM Lead ' +
      baseWhere +
      ' AND Intake_Attorney__c != null AND Post_Consult_Complete__c = true AND Were_you_able_to_speak_with_client__c != \'No (No Show)\' GROUP BY Intake_Attorney__r.Name';
    for (AggregateResult ar : Database.query(intakeAttorneyPostConsultQuery)) {
      String name = (String) ar.get('attorneyName');
      Integer count = (Integer) ar.get('cnt');
      postConsultByAttorney.put(
        name,
        (postConsultByAttorney.containsKey(name)
          ? postConsultByAttorney.get(name)
          : 0) + count
      );
    }

    // Query 2: Closed leads by Intake Attorney - must have both Date FA Sent AND Date First Payment on Matter
    String intakeAttorneyClosedQuery =
      'SELECT Intake_Attorney__r.Name attorneyName, COUNT(Id) cnt FROM Lead ' +
      baseWhere +
      ' AND Intake_Attorney__c != null AND Matter__c != null AND Matter__r.Date_FA_was_sent__c != null AND Matter__r.Date_First_Payment__c != null GROUP BY Intake_Attorney__r.Name';
    for (AggregateResult ar : Database.query(intakeAttorneyClosedQuery)) {
      String name = (String) ar.get('attorneyName');
      Integer count = (Integer) ar.get('cnt');
      closedByAttorney.put(
        name,
        (closedByAttorney.containsKey(name) ? closedByAttorney.get(name) : 0) +
        count
      );
    }

    // Calculate close rates
    List<AttorneyCloseRateSummary> summaries = new List<AttorneyCloseRateSummary>();
    for (String attorneyName : postConsultByAttorney.keySet()) {
      Integer postConsultTotal = postConsultByAttorney.get(attorneyName);
      Integer closed = closedByAttorney.containsKey(attorneyName)
        ? closedByAttorney.get(attorneyName)
        : 0;
      Decimal rate = postConsultTotal > 0
        ? ((Decimal) closed / postConsultTotal * 100)
        : 0;
      summaries.add(
        new AttorneyCloseRateSummary(
          attorneyName,
          rate,
          closed,
          postConsultTotal
        )
      );
    }

    summaries.sort();
    return summaries;
  }

  @AuraEnabled(cacheable=true)
  public static List<AttorneyCloseRateSummary> getIntakeSpecialistCloseRate(
    String dateFilter,
    String practiceArea,
    String officeLocation,
    Boolean includeAttorney,
    String typeOfCivilLaw
  ) {
    DateRange dr = getDateRangeForFilter(dateFilter);
    Date startDate = dr.startDate;
    Date endDate = dr.endDate;

    Map<String, Integer> postConsultByOwner = new Map<String, Integer>();
    Map<String, Integer> closedByOwner = new Map<String, Integer>();

    // Base WHERE clause for all queries - use Post_Con_Completed_Date__c
    String baseWhere = 'WHERE Post_Con_Completed_Date__c >= :startDate AND Post_Con_Completed_Date__c <= :endDate';
    if (String.isNotBlank(practiceArea)) {
      baseWhere += ' AND Category__c = :practiceArea';
    }
    if (String.isNotBlank(officeLocation)) {
      baseWhere += ' AND Preferred_Office_Location__c = :officeLocation';
    }
    if (String.isNotBlank(typeOfCivilLaw)) {
      baseWhere += ' AND Type_of_Civil_Law__c = :typeOfCivilLaw';
    }

    // Additional filter based on includeAttorney checkbox
    String attorneyFilter = '';
    if (includeAttorney != null && includeAttorney) {
      attorneyFilter = '';
    } else {
      attorneyFilter = ' AND Intake_Attorney__c = null';
    }

    // Query 1: "At bat" leads by Lead Owner (Intake Specialist)
    // At bat = ALL leads with Post Consult Complete = true AND spoke with client (includes closed leads)
    String ownerPostConsultQuery =
      'SELECT Owner.Name ownerName, COUNT(Id) cnt FROM Lead ' +
      baseWhere +
      attorneyFilter +
      ' AND Post_Consult_Complete__c = true AND Were_you_able_to_speak_with_client__c != \'No (No Show)\' GROUP BY Owner.Name';
    for (AggregateResult ar : Database.query(ownerPostConsultQuery)) {
      String name = (String) ar.get('ownerName');
      Integer count = (Integer) ar.get('cnt');
      postConsultByOwner.put(name, count);
    }

    // Query 2: Closed leads by Lead Owner (Intake Specialist)
    // Closed = leads with both Date_FA_was_sent__c AND Date_First_Payment__c on Matter
    String ownerClosedQuery =
      'SELECT Owner.Name ownerName, COUNT(Id) cnt FROM Lead ' +
      baseWhere +
      attorneyFilter +
      ' AND Matter__c != null AND Matter__r.Date_FA_was_sent__c != null AND Matter__r.Date_First_Payment__c != null GROUP BY Owner.Name';
    for (AggregateResult ar : Database.query(ownerClosedQuery)) {
      String name = (String) ar.get('ownerName');
      Integer count = (Integer) ar.get('cnt');
      closedByOwner.put(name, count);
    }

    // Calculate close rates
    List<AttorneyCloseRateSummary> summaries = new List<AttorneyCloseRateSummary>();
    for (String ownerName : postConsultByOwner.keySet()) {
      Integer postConsultTotal = postConsultByOwner.get(ownerName);
      Integer closed = closedByOwner.containsKey(ownerName)
        ? closedByOwner.get(ownerName)
        : 0;
      Decimal rate = postConsultTotal > 0
        ? ((Decimal) closed / postConsultTotal * 100)
        : 0;
      summaries.add(
        new AttorneyCloseRateSummary(ownerName, rate, closed, postConsultTotal)
      );
    }

    summaries.sort();
    return summaries;
  }

  @AuraEnabled(cacheable=true)
  public static List<IntakeCompletionSummary> getIntakeCompletions(
    String dateFilter,
    String practiceArea,
    String officeLocation,
    String typeOfCivilLaw
  ) {
    DateRange dr = getDateRangeForFilter(dateFilter);
    Date startDate = dr.startDate;
    Date endDate = dr.endDate;

    // Base WHERE clause - filter by Intake_Completion_Date__c (not CreatedDate)
    String baseWhere = 'WHERE Intake_Completion_Date__c >= :startDate AND Intake_Completion_Date__c <= :endDate';
    if (String.isNotBlank(practiceArea)) {
      baseWhere += ' AND Category__c = :practiceArea';
    }
    if (String.isNotBlank(officeLocation)) {
      baseWhere += ' AND Preferred_Office_Location__c = :officeLocation';
    }
    if (String.isNotBlank(typeOfCivilLaw)) {
      baseWhere += ' AND Type_of_Civil_Law__c = :typeOfCivilLaw';
    }

    // Query: Group by Lead Owner (Intake Specialist) only
    String ownerQuery =
      'SELECT Owner.Name ownerName, COUNT(Id) cnt FROM Lead ' +
      baseWhere +
      ' GROUP BY Owner.Name';

    List<IntakeCompletionSummary> summaries = new List<IntakeCompletionSummary>();
    for (AggregateResult ar : Database.query(ownerQuery)) {
      String name = (String) ar.get('ownerName');
      Integer count = (Integer) ar.get('cnt');
      summaries.add(new IntakeCompletionSummary(name, count));
    }

    // Sort by count descending
    summaries.sort(new IntakeCompletionComparator());

    // Return top 10
    List<IntakeCompletionSummary> topSummaries = new List<IntakeCompletionSummary>();
    for (Integer i = 0; i < Math.min(10, summaries.size()); i++) {
      topSummaries.add(summaries[i]);
    }

    return topSummaries;
  }

  @AuraEnabled(cacheable=true)
  public static List<SQLTrendPoint> getSQLLeadsTrend(
    String dateFilter,
    String practiceArea,
    String officeLocation,
    String typeOfCivilLaw
  ) {
    DateRange dr = getDateRangeForFilter(dateFilter);
    List<SQLTrendPoint> trendPoints = new List<SQLTrendPoint>();

    // Get all SQL leads in the date range first - filter by CreatedDate
    DateTime startDateTime = DateTime.newInstance(
      dr.startDate,
      Time.newInstance(0, 0, 0, 0)
    );
    DateTime endDateTime = DateTime.newInstance(
      dr.endDate.addDays(1),
      Time.newInstance(0, 0, 0, 0)
    );

    String baseQuery = 'SELECT Id, CreatedDate FROM Lead WHERE SQL__c = true AND CreatedDate >= :startDateTime AND CreatedDate < :endDateTime';

    if (String.isNotBlank(practiceArea)) {
      baseQuery += ' AND Category__c = :practiceArea';
    }
    if (String.isNotBlank(officeLocation)) {
      baseQuery += ' AND Preferred_Office_Location__c = :officeLocation';
    }
    if (String.isNotBlank(typeOfCivilLaw)) {
      baseQuery += ' AND Type_of_Civil_Law__c = :typeOfCivilLaw';
    }

    baseQuery += ' ORDER BY CreatedDate ASC';

    List<Lead> sqlLeads = Database.query(baseQuery);

    // Process the data based on aggregation type
    Map<String, String> aggregationConfig = getAggregationConfig(
      dateFilter,
      dr
    );
    Map<String, Integer> aggregatedData = new Map<String, Integer>();

    // Group the leads by the appropriate time period
    for (Lead lead : sqlLeads) {
      DateTime createdDateTime = lead.CreatedDate;
      String periodKey = getPeriodKey(
        createdDateTime,
        aggregationConfig.get('type')
      );
      if (aggregatedData.containsKey(periodKey)) {
        aggregatedData.put(periodKey, aggregatedData.get(periodKey) + 1);
      } else {
        aggregatedData.put(periodKey, 1);
      }
    }

    // Convert to SQLTrendPoint objects
    for (String periodKey : aggregatedData.keySet()) {
      SQLTrendPoint point = createTrendPointFromPeriodKey(
        periodKey,
        aggregatedData.get(periodKey),
        aggregationConfig.get('type'),
        dr
      );
      if (point != null) {
        trendPoints.add(point);
      }
    }

    // Sort by period date
    trendPoints.sort(new SQLTrendPointComparator());

    return trendPoints;
  }

  private static Map<String, String> getAggregationConfig(
    String dateFilter,
    DateRange dr
  ) {
    Map<String, String> config = new Map<String, String>();

    switch on dateFilter {
      when 'TODAY', 'YESTERDAY' {
        config.put('type', 'hourly');
      }
      when 'THIS_WEEK', 'LAST_WEEK' {
        config.put('type', 'daily');
      }
      when 'THIS_MONTH', 'LAST_MONTH' {
        config.put('type', 'weekly');
      }
      when 'THIS_QUARTER', 'LAST_QUARTER', 'THIS_YEAR', 'LAST_YEAR' {
        config.put('type', 'monthly');
      }
      when else {
        config.put('type', 'daily');
      }
    }

    return config;
  }

  private static String getPeriodKey(
    DateTime createdDate,
    String aggregationType
  ) {
    if (aggregationType == 'hourly') {
      return createdDate.format('yyyy-MM-dd-HH');
    } else if (aggregationType == 'daily') {
      return createdDate.format('yyyy-MM-dd');
    } else if (aggregationType == 'weekly') {
      // Get the start of the week (Monday)
      Date dateOnly = createdDate.date();
      Integer dayOfWeek = Math.mod(
        Date.newInstance(1900, 1, 7).daysBetween(dateOnly),
        7
      );
      Date weekStart = dateOnly.addDays(-dayOfWeek);
      DateTime weekStartDateTime = DateTime.newInstance(
        weekStart,
        Time.newInstance(0, 0, 0, 0)
      );
      return weekStartDateTime.format('yyyy-MM-dd');
    } else if (aggregationType == 'monthly') {
      return createdDate.format('yyyy-MM');
    }
    return createdDate.format('yyyy-MM-dd');
  }

  private static SQLTrendPoint createTrendPointFromPeriodKey(
    String periodKey,
    Integer count,
    String aggregationType,
    DateRange dr
  ) {
    String period = periodKey;
    String periodLabel = '';
    Date periodDate = null;

    try {
      if (aggregationType == 'hourly') {
        // periodKey format: yyyy-MM-dd-HH
        String[] parts = periodKey.split('-');
        if (parts.size() >= 4) {
          Integer year = Integer.valueOf(parts[0]);
          Integer month = Integer.valueOf(parts[1]);
          Integer day = Integer.valueOf(parts[2]);
          Integer hour = Integer.valueOf(parts[3]);

          periodDate = Date.newInstance(year, month, day);
          periodLabel =
            (hour == 0
              ? '12'
              : (hour > 12
                  ? String.valueOf(hour - 12)
                  : String.valueOf(hour))) + (hour < 12 ? ' AM' : ' PM');
        }
      } else if (aggregationType == 'daily') {
        // periodKey format: yyyy-MM-dd
        String[] parts = periodKey.split('-');
        if (parts.size() >= 3) {
          Integer year = Integer.valueOf(parts[0]);
          Integer month = Integer.valueOf(parts[1]);
          Integer day = Integer.valueOf(parts[2]);

          periodDate = Date.newInstance(year, month, day);
          DateTime dayDateTime = DateTime.newInstance(
            periodDate,
            Time.newInstance(0, 0, 0, 0)
          );
          periodLabel = dayDateTime.format('EEE M/d');
        }
      } else if (aggregationType == 'weekly') {
        // periodKey format: yyyy-MM-dd (start of week)
        String[] parts = periodKey.split('-');
        if (parts.size() >= 3) {
          Integer year = Integer.valueOf(parts[0]);
          Integer month = Integer.valueOf(parts[1]);
          Integer day = Integer.valueOf(parts[2]);

          periodDate = Date.newInstance(year, month, day);
          DateTime weekDateTime = DateTime.newInstance(
            periodDate,
            Time.newInstance(0, 0, 0, 0)
          );
          periodLabel = 'Week of ' + weekDateTime.format('M/d');
        }
      } else if (aggregationType == 'monthly') {
        // periodKey format: yyyy-MM
        String[] parts = periodKey.split('-');
        if (parts.size() >= 2) {
          Integer year = Integer.valueOf(parts[0]);
          Integer month = Integer.valueOf(parts[1]);

          periodDate = Date.newInstance(year, month, 1);
          DateTime monthDate = DateTime.newInstance(year, month, 1, 0, 0, 0);
          periodLabel = monthDate.format('MMM');
          if (year != Date.today().year()) {
            periodLabel += ' \'' + String.valueOf(year).right(2);
          }
        }
      }
    } catch (Exception e) {
      // If date parsing fails, use periodKey as both period and label
      System.debug(
        'Date parsing error for periodKey: ' +
          periodKey +
          ', Error: ' +
          e.getMessage()
      );
      periodLabel = periodKey;
    }

    return new SQLTrendPoint(period, count, periodDate, periodLabel);
  }

  public class SQLTrendPointComparator implements Comparator<SQLTrendPoint> {
    public Integer compare(SQLTrendPoint a, SQLTrendPoint b) {
      if (a.periodDate == null && b.periodDate == null)
        return 0;
      if (a.periodDate == null)
        return 1;
      if (b.periodDate == null)
        return -1;
      return a.periodDate < b.periodDate
        ? -1
        : (a.periodDate > b.periodDate ? 1 : 0);
    }
  }

  // =========================================================================
  // HELPER AND MODAL METHODS
  // =========================================================================

  private static DateRange getDateRangeForFilter(String dateFilter) {
    DateRange dr = new DateRange();
    Date today = Date.today();

    switch on dateFilter {
      when 'TODAY' {
        dr.startDate = today;
        dr.endDate = today;
        dr.label = 'Today';
      }
      when 'YESTERDAY' {
        Date yesterday = today.addDays(-1);
        dr.startDate = yesterday;
        dr.endDate = yesterday;
        dr.label = 'Yesterday';
      }
      when 'THIS_WEEK' {
        // Calculate start of this week (Monday)
        Integer dayOfWeek = Math.mod(
          Date.newInstance(1900, 1, 7).daysBetween(today),
          7
        );
        Date startOfWeek = today.addDays(-dayOfWeek);
        dr.startDate = startOfWeek;
        dr.endDate = today;
        dr.label = 'This Week';
      }
      when 'LAST_WEEK' {
        // Calculate start of last week (Monday)
        Integer dayOfWeek = Math.mod(
          Date.newInstance(1900, 1, 7).daysBetween(today),
          7
        );
        Date startOfThisWeek = today.addDays(-dayOfWeek);
        Date startOfLastWeek = startOfThisWeek.addDays(-7);
        Date endOfLastWeek = startOfThisWeek.addDays(-1);
        dr.startDate = startOfLastWeek;
        dr.endDate = endOfLastWeek;
        dr.label = 'Last Week';
      }
      when 'THIS_MONTH' {
        dr.startDate = today.toStartOfMonth();
        dr.endDate = today;
        dr.label = 'This Month';
      }
      when 'LAST_MONTH' {
        Date lastMonthDate = today.addMonths(-1);
        dr.startDate = lastMonthDate.toStartOfMonth();
        dr.endDate = Date.newInstance(
          lastMonthDate.year(),
          lastMonthDate.month(),
          Date.daysInMonth(lastMonthDate.year(), lastMonthDate.month())
        );
        dr.label = 'Last Month';
      }
      when 'THIS_QUARTER' {
        dr.startDate = Date.newInstance(
          today.year(),
          ((today.month() - 1) / 3) * 3 + 1,
          1
        );
        dr.endDate = today;
        dr.label = 'This Quarter';
      }
      when 'LAST_QUARTER' {
        Date lastQuarterDate = today.addMonths(-3);
        Integer quarterNum = ((lastQuarterDate.month() - 1) / 3);
        dr.startDate = Date.newInstance(
          lastQuarterDate.year(),
          quarterNum * 3 + 1,
          1
        );
        dr.endDate = dr.startDate.addMonths(3).addDays(-1);
        dr.label = 'Last Quarter';
      }
      when 'THIS_YEAR' {
        dr.startDate = Date.newInstance(today.year(), 1, 1);
        dr.endDate = today;
        dr.label = 'This Year';
      }
      when 'LAST_YEAR' {
        dr.startDate = Date.newInstance(today.year() - 1, 1, 1);
        dr.endDate = Date.newInstance(today.year() - 1, 12, 31);
        dr.label = 'Last Year';
      }
      when else {
        // Default to THIS_MONTH
        dr.startDate = today.toStartOfMonth();
        dr.endDate = today;
        dr.label = 'This Month';
      }
    }
    return dr;
  }

  @AuraEnabled(cacheable=true)
  public static List<MatterDetail> getOpenMatterRecords(String practiceArea) {
    String query = 'SELECT Id, Name, Practice_Area__c, Status__c FROM Matter__c WHERE Status__c IN (\'Open\', \'Pending\')';
    if (String.isNotBlank(practiceArea)) {
      query += ' AND Practice_Area__c = :practiceArea';
    }
    query += ' ORDER BY Name LIMIT 1000';

    List<MatterDetail> details = new List<MatterDetail>();
    for (Matter__c m : Database.query(query)) {
      details.add(new MatterDetail(m));
    }
    return details;
  }

  @AuraEnabled(cacheable=true)
  public static List<LeadDetail> getNewLeadRecords(
    String dateFilter,
    String practiceArea,
    String officeLocation,
    String typeOfCivilLaw
  ) {
    DateRange dr = getDateRangeForFilter(dateFilter);
    DateTime startDateTime = DateTime.newInstance(
      dr.startDate,
      Time.newInstance(0, 0, 0, 0)
    );
    DateTime endDateTime = DateTime.newInstance(
      dr.endDate.addDays(1),
      Time.newInstance(0, 0, 0, 0)
    );

    String query = 'SELECT Id, Name, CreatedDate, Status, Owner.Name, Category__c FROM Lead WHERE CreatedDate >= :startDateTime AND CreatedDate < :endDateTime';
    if (String.isNotBlank(practiceArea)) {
      query += ' AND Category__c = :practiceArea';
    }
    if (String.isNotBlank(officeLocation)) {
      query += ' AND Preferred_Office_Location__c = :officeLocation';
    }
    if (String.isNotBlank(typeOfCivilLaw)) {
      query += ' AND Type_of_Civil_Law__c = :typeOfCivilLaw';
    }
    query += ' ORDER BY CreatedDate DESC LIMIT 1000';

    List<LeadDetail> details = new List<LeadDetail>();
    for (Lead l : Database.query(query)) {
      details.add(new LeadDetail(l));
    }
    return details;
  }

  @AuraEnabled(cacheable=true)
  public static List<SQLLeadDetail> getSQLLeadRecords(
    String dateFilter,
    String practiceArea,
    String officeLocation,
    String typeOfCivilLaw
  ) {
    DateRange dr = getDateRangeForFilter(dateFilter);
    DateTime startDateTime = DateTime.newInstance(
      dr.startDate,
      Time.newInstance(0, 0, 0, 0)
    );
    DateTime endDateTime = DateTime.newInstance(
      dr.endDate.addDays(1),
      Time.newInstance(0, 0, 0, 0)
    );

    String query = 'SELECT Id, Name, CreatedDate, Status, Owner.Name, Category__c, Preferred_Office_Location__c, Supervising_Attorney__c, Supervising_Attorney__r.Name FROM Lead WHERE SQL__c = true AND CreatedDate >= :startDateTime AND CreatedDate < :endDateTime';
    if (String.isNotBlank(practiceArea)) {
      query += ' AND Category__c = :practiceArea';
    }
    if (String.isNotBlank(officeLocation)) {
      query += ' AND Preferred_Office_Location__c = :officeLocation';
    }
    if (String.isNotBlank(typeOfCivilLaw)) {
      query += ' AND Type_of_Civil_Law__c = :typeOfCivilLaw';
    }
    query += ' ORDER BY CreatedDate DESC LIMIT 1000';

    List<SQLLeadDetail> details = new List<SQLLeadDetail>();
    for (Lead l : Database.query(query)) {
      details.add(new SQLLeadDetail(l));
    }
    return details;
  }

  // Export methods
  @AuraEnabled
  public static String exportSalesMarketingData(
    String dateFilter,
    String practiceArea,
    String officeLocation,
    String typeOfCivilLaw
  ) {
    DateRange dr = getDateRangeForFilter(dateFilter);
    Date startDate = dr.startDate;
    Date endDate = dr.endDate;

    List<String> csvData = new List<String>();
    csvData.add(
      'Section,Metric,Value,Period,Category,Office Location,Type of Civil Law'
    );

    // New Leads
    LeadCountSummary leadCount = getLeadCount(
      dateFilter,
      practiceArea,
      officeLocation,
      typeOfCivilLaw
    );
    csvData.add(
      '"Sales & Marketing","New Leads",' +
        leadCount.leadCount +
        ',"' +
        leadCount.periodLabel +
        '","' +
        (String.isBlank(practiceArea) ? 'All' : practiceArea) +
        '","' +
        (String.isBlank(officeLocation) ? 'All' : officeLocation) +
        '","' +
        (String.isBlank(typeOfCivilLaw) ? 'All' : typeOfCivilLaw) +
        '"'
    );

    // Intake Specialist Completions
    List<IntakeCompletionSummary> intakeCompletions = getIntakeCompletions(
      dateFilter,
      practiceArea,
      officeLocation,
      typeOfCivilLaw
    );
    for (IntakeCompletionSummary intake : intakeCompletions) {
      csvData.add(
        '"Sales & Marketing","Intake Specialist Completions - ' +
          intake.ownerName +
          '",' +
          intake.intakeCount +
          ',"' +
          dr.label +
          '","' +
          (String.isBlank(practiceArea) ? 'All' : practiceArea) +
          '","' +
          (String.isBlank(officeLocation) ? 'All' : officeLocation) +
          '","' +
          (String.isBlank(typeOfCivilLaw) ? 'All' : typeOfCivilLaw) +
          '"'
      );
    }

    // Close Rate by Attorney
    List<AttorneyCloseRateSummary> closeRates = getCloseRateByAttorney(
      dateFilter,
      practiceArea,
      officeLocation,
      typeOfCivilLaw
    );
    for (AttorneyCloseRateSummary attorney : closeRates) {
      csvData.add(
        '"Sales & Marketing","Close Rate - ' +
          attorney.attorneyName +
          '",' +
          attorney.totalClosed +
          ',' +
          attorney.closeRate +
          '%,"' +
          dr.label +
          '","' +
          (String.isBlank(practiceArea) ? 'All' : practiceArea) +
          '","' +
          (String.isBlank(officeLocation) ? 'All' : officeLocation) +
          '"'
      );
    }

    // Lead Conversion by Source
    List<LeadSourceConversionSummary> conversions = getLeadConversionBySource(
      dateFilter,
      practiceArea,
      officeLocation,
      typeOfCivilLaw
    );
    for (LeadSourceConversionSummary conversion : conversions) {
      csvData.add(
        '"Sales & Marketing","Lead Conversion - ' +
          conversion.source +
          '",' +
          conversion.conversionRate +
          '%,"' +
          dr.label +
          '","' +
          (String.isBlank(practiceArea) ? 'All' : practiceArea) +
          '","' +
          (String.isBlank(officeLocation) ? 'All' : officeLocation) +
          '"'
      );
    }

    // Total Leads by Source
    List<LeadSourceCountSummary> leadSources = getTotalLeadsBySource(
      dateFilter,
      practiceArea,
      officeLocation,
      typeOfCivilLaw
    );
    for (LeadSourceCountSummary source : leadSources) {
      csvData.add(
        '"Sales & Marketing","Total Leads - ' +
          source.source +
          '",' +
          source.leadCount +
          ',"' +
          dr.label +
          '","' +
          (String.isBlank(practiceArea) ? 'All' : practiceArea) +
          '","' +
          (String.isBlank(officeLocation) ? 'All' : officeLocation) +
          '"'
      );
    }

    // Leads by Landing Page
    List<LandingPageLeadSummary> landingPages = getLeadsByLandingPage(
      dateFilter,
      practiceArea,
      officeLocation,
      typeOfCivilLaw
    );
    for (LandingPageLeadSummary page : landingPages) {
      csvData.add(
        '"Sales & Marketing","Leads by Landing Page - ' +
          page.landingPage +
          '",' +
          page.leadCount +
          ',"' +
          dr.label +
          '","' +
          (String.isBlank(practiceArea) ? 'All' : practiceArea) +
          '","' +
          (String.isBlank(officeLocation) ? 'All' : officeLocation) +
          '"'
      );
    }

    return String.join(csvData, '\n');
  }

  // Individual component export methods
  @AuraEnabled
  public static String exportLeadCount(
    String dateFilter,
    String practiceArea,
    String officeLocation,
    String typeOfCivilLaw
  ) {
    DateRange dr = getDateRangeForFilter(dateFilter);
    LeadCountSummary leadCount = getLeadCount(
      dateFilter,
      practiceArea,
      officeLocation,
      typeOfCivilLaw
    );

    List<String> csvData = new List<String>();
    csvData.add(
      'Metric,Count,Period,Category,Office Location,Type of Civil Law'
    );
    csvData.add(
      '"New Leads",' +
        leadCount.leadCount +
        ',"' +
        leadCount.periodLabel +
        '","' +
        (String.isBlank(practiceArea) ? 'All' : practiceArea) +
        '","' +
        (String.isBlank(officeLocation) ? 'All' : officeLocation) +
        '","' +
        (String.isBlank(typeOfCivilLaw) ? 'All' : typeOfCivilLaw) +
        '"'
    );

    return String.join(csvData, '\n');
  }

  @AuraEnabled
  public static String exportLeadMetrics(
    String dateFilter,
    String practiceArea,
    String officeLocation,
    String typeOfCivilLaw
  ) {
    DateRange dr = getDateRangeForFilter(dateFilter);
    LeadMetricsSummary leadMetrics = getLeadMetrics(
      dateFilter,
      practiceArea,
      officeLocation,
      typeOfCivilLaw
    );

    List<String> csvData = new List<String>();
    csvData.add(
      'Metric,Count,Period,Category,Office Location,Type of Civil Law'
    );
    csvData.add(
      '"New Leads",' +
        leadMetrics.newLeads +
        ',"' +
        leadMetrics.periodLabel +
        '","' +
        (String.isBlank(practiceArea) ? 'All' : practiceArea) +
        '","' +
        (String.isBlank(officeLocation) ? 'All' : officeLocation) +
        '"'
    );
    csvData.add(
      '"Intake Spec. Post-Consults",' +
        leadMetrics.intakeSpecialistCalls +
        ',"' +
        leadMetrics.periodLabel +
        '","' +
        (String.isBlank(practiceArea) ? 'All' : practiceArea) +
        '","' +
        (String.isBlank(officeLocation) ? 'All' : officeLocation) +
        '"'
    );
    csvData.add(
      '"Intake Atty. Post-Consults",' +
        leadMetrics.intakeAttorneyCalls +
        ',"' +
        leadMetrics.periodLabel +
        '","' +
        (String.isBlank(practiceArea) ? 'All' : practiceArea) +
        '","' +
        (String.isBlank(officeLocation) ? 'All' : officeLocation) +
        '"'
    );
    csvData.add(
      '"Intake Attorney No Shows",' +
        leadMetrics.intakeAttorneyNoShows +
        ',"' +
        leadMetrics.periodLabel +
        '","' +
        (String.isBlank(practiceArea) ? 'All' : practiceArea) +
        '","' +
        (String.isBlank(officeLocation) ? 'All' : officeLocation) +
        '"'
    );
    csvData.add(
      '"Closed by Intake Spec.",' +
        leadMetrics.totalClosedByIS +
        ',"' +
        leadMetrics.periodLabel +
        '","' +
        (String.isBlank(practiceArea) ? 'All' : practiceArea) +
        '","' +
        (String.isBlank(officeLocation) ? 'All' : officeLocation) +
        '"'
    );
    csvData.add(
      '"Closed by Intake Atty.",' +
        leadMetrics.totalClosedByIA +
        ',"' +
        leadMetrics.periodLabel +
        '","' +
        (String.isBlank(practiceArea) ? 'All' : practiceArea) +
        '","' +
        (String.isBlank(officeLocation) ? 'All' : officeLocation) +
        '"'
    );

    return String.join(csvData, '\n');
  }

  @AuraEnabled
  public static String exportIntakeCompletions(
    String dateFilter,
    String practiceArea,
    String officeLocation,
    String typeOfCivilLaw
  ) {
    DateRange dr = getDateRangeForFilter(dateFilter);
    List<IntakeCompletionSummary> intakeCompletions = getIntakeCompletions(
      dateFilter,
      practiceArea,
      officeLocation,
      typeOfCivilLaw
    );

    List<String> csvData = new List<String>();
    csvData.add(
      'Intake Specialist Name,Intake Count,Period,Category,Office Location,Type of Civil Law'
    );

    for (IntakeCompletionSummary intake : intakeCompletions) {
      csvData.add(
        '"' +
          intake.ownerName +
          '",' +
          intake.intakeCount +
          ',"' +
          dr.label +
          '","' +
          (String.isBlank(practiceArea) ? 'All' : practiceArea) +
          '","' +
          (String.isBlank(officeLocation) ? 'All' : officeLocation) +
          '"'
      );
    }

    return String.join(csvData, '\n');
  }

  @AuraEnabled
  public static String exportCloseRateByAttorney(
    String dateFilter,
    String practiceArea,
    String officeLocation,
    String typeOfCivilLaw
  ) {
    DateRange dr = getDateRangeForFilter(dateFilter);
    List<AttorneyCloseRateSummary> closeRates = getCloseRateByAttorney(
      dateFilter,
      practiceArea,
      officeLocation,
      typeOfCivilLaw
    );

    List<String> csvData = new List<String>();
    csvData.add(
      'Attorney Name,Total Closes,Close Rate (%),Period,Category,Office Location,Type of Civil Law'
    );

    for (AttorneyCloseRateSummary attorney : closeRates) {
      csvData.add(
        '"' +
          attorney.attorneyName +
          '",' +
          attorney.totalClosed +
          ',' +
          attorney.closeRate +
          ',"' +
          dr.label +
          '","' +
          (String.isBlank(practiceArea) ? 'All' : practiceArea) +
          '","' +
          (String.isBlank(officeLocation) ? 'All' : officeLocation) +
          '"'
      );
    }

    return String.join(csvData, '\n');
  }

  @AuraEnabled
  public static String exportIntakeSpecialistCloseRate(
    String dateFilter,
    String practiceArea,
    String officeLocation,
    String typeOfCivilLaw,
    Boolean includeAttorney
  ) {
    DateRange dr = getDateRangeForFilter(dateFilter);
    List<AttorneyCloseRateSummary> closeRates = getIntakeSpecialistCloseRate(
      dateFilter,
      practiceArea,
      officeLocation,
      includeAttorney,
      typeOfCivilLaw
    );

    List<String> csvData = new List<String>();
    csvData.add(
      'Intake Specialist Name,Total Closes,Close Rate (%),Period,Category,Office Location,Type of Civil Law,Include Attorney'
    );

    for (AttorneyCloseRateSummary specialist : closeRates) {
      csvData.add(
        '"' +
          specialist.attorneyName +
          '",' +
          specialist.totalClosed +
          ',' +
          specialist.closeRate +
          ',"' +
          dr.label +
          '","' +
          (String.isBlank(practiceArea) ? 'All' : practiceArea) +
          '","' +
          (String.isBlank(officeLocation) ? 'All' : officeLocation) +
          '","' +
          (includeAttorney != null && includeAttorney ? 'Yes' : 'No') +
          '"'
      );
    }

    return String.join(csvData, '\n');
  }

  @AuraEnabled
  public static String exportLeadConversionBySource(
    String dateFilter,
    String practiceArea,
    String officeLocation,
    String typeOfCivilLaw
  ) {
    DateRange dr = getDateRangeForFilter(dateFilter);
    List<LeadSourceConversionSummary> conversions = getLeadConversionBySource(
      dateFilter,
      practiceArea,
      officeLocation,
      typeOfCivilLaw
    );

    List<String> csvData = new List<String>();
    csvData.add(
      'Source,Conversion Rate (%),Period,Category,Office Location,Type of Civil Law'
    );

    for (LeadSourceConversionSummary conversion : conversions) {
      csvData.add(
        '"' +
          conversion.source +
          '",' +
          conversion.conversionRate +
          ',"' +
          dr.label +
          '","' +
          (String.isBlank(practiceArea) ? 'All' : practiceArea) +
          '","' +
          (String.isBlank(officeLocation) ? 'All' : officeLocation) +
          '"'
      );
    }

    return String.join(csvData, '\n');
  }

  @AuraEnabled
  public static String exportTotalLeadsBySource(
    String dateFilter,
    String practiceArea,
    String officeLocation,
    String typeOfCivilLaw
  ) {
    DateRange dr = getDateRangeForFilter(dateFilter);
    List<LeadSourceCountSummary> leadSources = getTotalLeadsBySource(
      dateFilter,
      practiceArea,
      officeLocation,
      typeOfCivilLaw
    );

    List<String> csvData = new List<String>();
    csvData.add(
      'Source,Lead Count,Period,Category,Office Location,Type of Civil Law'
    );

    for (LeadSourceCountSummary source : leadSources) {
      csvData.add(
        '"' +
          source.source +
          '",' +
          source.leadCount +
          ',"' +
          dr.label +
          '","' +
          (String.isBlank(practiceArea) ? 'All' : practiceArea) +
          '","' +
          (String.isBlank(officeLocation) ? 'All' : officeLocation) +
          '"'
      );
    }

    return String.join(csvData, '\n');
  }

  @AuraEnabled
  public static String exportLeadsByLandingPage(
    String dateFilter,
    String practiceArea,
    String officeLocation,
    String typeOfCivilLaw
  ) {
    DateRange dr = getDateRangeForFilter(dateFilter);
    List<LandingPageLeadSummary> landingPages = getLeadsByLandingPage(
      dateFilter,
      practiceArea,
      officeLocation,
      typeOfCivilLaw
    );

    List<String> csvData = new List<String>();
    csvData.add(
      'Landing Page,Lead Count,Period,Category,Office Location,Type of Civil Law'
    );

    for (LandingPageLeadSummary page : landingPages) {
      csvData.add(
        '"' +
          page.landingPage +
          '",' +
          page.leadCount +
          ',"' +
          dr.label +
          '","' +
          (String.isBlank(practiceArea) ? 'All' : practiceArea) +
          '","' +
          (String.isBlank(officeLocation) ? 'All' : officeLocation) +
          '"'
      );
    }

    return String.join(csvData, '\n');
  }

  @AuraEnabled
  public static String exportLeadsByPracticeArea(
    String dateFilter,
    String practiceArea,
    String officeLocation,
    String typeOfCivilLaw
  ) {
    DateRange dr = getDateRangeForFilter(dateFilter);
    DateTime startDateTime = DateTime.newInstance(
      dr.startDate,
      Time.newInstance(0, 0, 0, 0)
    );
    DateTime endDateTime = DateTime.newInstance(
      dr.endDate.addDays(1),
      Time.newInstance(0, 0, 0, 0)
    );

    List<String> csvData = new List<String>();
    csvData.add(
      'Created Date,Lead Name,Preferred Office,Intake Specialist,Intake Attorney,Date FA was Signed,Date First Payment Made'
    );

    String query = 'SELECT Id, Name, CreatedDate, Preferred_Office_Location__c, Owner.Name, Intake_Attorney__r.Name, Lead_Completion_Date__c, Date_First_Payment__c FROM Lead WHERE Category__c != null AND CreatedDate >= :startDateTime AND CreatedDate < :endDateTime';

    if (String.isNotBlank(practiceArea)) {
      query += ' AND Category__c = :practiceArea';
    }
    if (String.isNotBlank(officeLocation)) {
      query += ' AND Preferred_Office_Location__c = :officeLocation';
    }

    query += ' ORDER BY CreatedDate DESC';

    for (Lead l : Database.query(query)) {
      csvData.add(
        (l.CreatedDate != null
            ? DateTime.newInstance(l.CreatedDate.getTime()).format('yyyy-MM-dd')
            : '') +
          ',' +
          '"' +
          l.Name +
          '",' +
          '"' +
          (l.Preferred_Office_Location__c != null
            ? l.Preferred_Office_Location__c
            : '') +
          '",' +
          '"' +
          (l.Owner != null ? l.Owner.Name : '') +
          '",' +
          '"' +
          (l.Intake_Attorney__r != null ? l.Intake_Attorney__r.Name : '') +
          '",' +
          (l.Lead_Completion_Date__c != null
            ? String.valueOf(l.Lead_Completion_Date__c)
            : '') +
          ',' +
          (l.Date_First_Payment__c != null
            ? String.valueOf(l.Date_First_Payment__c)
            : '')
      );
    }

    return String.join(csvData, '\n');
  }

  @AuraEnabled
  public static String exportSQLTrend(
    String dateFilter,
    String practiceArea,
    String officeLocation,
    String typeOfCivilLaw
  ) {
    DateRange dr = getDateRangeForFilter(dateFilter);
    List<SQLTrendPoint> sqlTrend = getSQLLeadsTrend(
      dateFilter,
      practiceArea,
      officeLocation,
      typeOfCivilLaw
    );

    List<String> csvData = new List<String>();
    csvData.add(
      'Period,SQL Count,Date,Period Label,Date Filter,Category,Office Location,Type of Civil Law'
    );

    for (SQLTrendPoint point : sqlTrend) {
      csvData.add(
        '"' +
          point.period +
          '",' +
          point.sqlCount +
          ',"' +
          (point.periodDate != null ? point.periodDate.format() : '') +
          '","' +
          point.periodLabel +
          '","' +
          dr.label +
          '","' +
          (String.isBlank(practiceArea) ? 'All' : practiceArea) +
          '","' +
          (String.isBlank(officeLocation) ? 'All' : officeLocation) +
          '"'
      );
    }

    return String.join(csvData, '\n');
  }

  @AuraEnabled(cacheable=true)
  public static List<Lead> getCloseRateLeadRecords(
    String attorneyName,
    String dateFilter,
    String practiceArea,
    String officeLocation,
    String typeOfCivilLaw
  ) {
    try {
      DateRange dr = getDateRangeForFilter(dateFilter);
      Date startDate = dr.startDate;
      Date endDate = dr.endDate;

      String baseWhere = 'Post_Con_Completed_Date__c >= :startDate AND Post_Con_Completed_Date__c <= :endDate';

      if (String.isNotBlank(practiceArea)) {
        baseWhere += ' AND Category__c = :practiceArea';
      }
      if (String.isNotBlank(officeLocation)) {
        baseWhere += ' AND Preferred_Office_Location__c = :officeLocation';
      }
      if (String.isNotBlank(typeOfCivilLaw)) {
        baseWhere += ' AND Type_of_Civil_Law__c = :typeOfCivilLaw';
      }

      // Build query to get leads for the specific attorney (Intake Attorney only)
      // Only include "at bat" leads: Post_Consult_Complete__c = true AND Were_you_able_to_speak_with_client__c != 'No (No Show)'
      String query =
        'SELECT Id, Name, Owner.Name, Intake_Attorney__r.Name, ' +
        'Category__c, Preferred_Office_Location__c, ' +
        'CreatedDate, Date_Signed_Up__c, Lead_Completion_Date__c, ' +
        'Date_First_Payment__c, Post_Con_Completed_Date__c, ' +
        'Matter__r.Date_FA_was_sent__c, Matter__r.Date_First_Payment__c ' +
        'FROM Lead WHERE (' +
        baseWhere +
        ') AND ' +
        'Intake_Attorney__r.Name = :attorneyName AND Post_Consult_Complete__c = true AND Were_you_able_to_speak_with_client__c != \'No (No Show)\' ' +
        'ORDER BY Post_Con_Completed_Date__c DESC';

      return Database.query(query);
    } catch (Exception e) {
      throw new AuraHandledException(
        'Error fetching close rate lead records: ' + e.getMessage()
      );
    }
  }

  @AuraEnabled(cacheable=true)
  public static List<Lead> getIntakeCompletionLeadRecords(
    String ownerName,
    String dateFilter,
    String practiceArea,
    String officeLocation,
    String typeOfCivilLaw
  ) {
    try {
      DateRange dr = getDateRangeForFilter(dateFilter);
      Date startDate = dr.startDate;
      Date endDate = dr.endDate;

      String baseWhere = 'Intake_Completion_Date__c >= :startDate AND Intake_Completion_Date__c <= :endDate';

      if (String.isNotBlank(practiceArea)) {
        baseWhere += ' AND Category__c = :practiceArea';
      }
      if (String.isNotBlank(officeLocation)) {
        baseWhere += ' AND Preferred_Office_Location__c = :officeLocation';
      }
      if (String.isNotBlank(typeOfCivilLaw)) {
        baseWhere += ' AND Type_of_Civil_Law__c = :typeOfCivilLaw';
      }

      // Build query to get leads for the specific owner (Intake Specialist only)
      String query =
        'SELECT Id, Name, Owner.Name, Intake_Attorney__r.Name, ' +
        'Category__c, Preferred_Office_Location__c, ' +
        'Intake_Completion_Date__c, Lead_Completion_Date__c, Date_First_Payment__c ' +
        'FROM Lead WHERE (' +
        baseWhere +
        ') AND ' +
        'Owner.Name = :ownerName ' +
        'ORDER BY Intake_Completion_Date__c DESC';

      return Database.query(query);
    } catch (Exception e) {
      throw new AuraHandledException(
        'Error fetching intake completion lead records: ' + e.getMessage()
      );
    }
  }

  @AuraEnabled(cacheable=true)
  public static List<Lead> getIntakeSpecialistCloseRateLeadRecords(
    String ownerName,
    String dateFilter,
    String practiceArea,
    String officeLocation,
    Boolean includeAttorney,
    String typeOfCivilLaw
  ) {
    try {
      DateRange dr = getDateRangeForFilter(dateFilter);
      Date startDate = dr.startDate;
      Date endDate = dr.endDate;

      String baseWhere = 'Post_Con_Completed_Date__c >= :startDate AND Post_Con_Completed_Date__c <= :endDate';

      if (String.isNotBlank(practiceArea)) {
        baseWhere += ' AND Category__c = :practiceArea';
      }
      if (String.isNotBlank(officeLocation)) {
        baseWhere += ' AND Preferred_Office_Location__c = :officeLocation';
      }
      if (String.isNotBlank(typeOfCivilLaw)) {
        baseWhere += ' AND Type_of_Civil_Law__c = :typeOfCivilLaw';
      }

      // Additional filter based on includeAttorney checkbox
      String attorneyFilter = '';
      if (includeAttorney != null && includeAttorney) {
        attorneyFilter = '';
      } else {
        attorneyFilter = ' AND Intake_Attorney__c = null';
      }

      // Build query to get leads for the specific owner (Lead Owner only)
      // Only include "at bat" leads: Post_Consult_Complete__c = true AND Were_you_able_to_speak_with_client__c != 'No (No Show)'
      String query =
        'SELECT Id, Name, Owner.Name, Intake_Attorney__r.Name, ' +
        'Category__c, Preferred_Office_Location__c, ' +
        'CreatedDate, Date_Signed_Up__c, Lead_Completion_Date__c, ' +
        'Date_First_Payment__c, Post_Con_Completed_Date__c, ' +
        'Matter__r.Date_FA_was_sent__c, Matter__r.Date_First_Payment__c ' +
        'FROM Lead WHERE (' +
        baseWhere +
        ') AND ' +
        'Owner.Name = :ownerName AND Post_Consult_Complete__c = true AND Were_you_able_to_speak_with_client__c != \'No (No Show)\'' +
        attorneyFilter +
        ' ORDER BY Post_Con_Completed_Date__c DESC';

      return Database.query(query);
    } catch (Exception e) {
      throw new AuraHandledException(
        'Error fetching intake specialist close rate lead records: ' +
        e.getMessage()
      );
    }
  }

  // Lead Metrics Modal Data Methods
  @AuraEnabled(cacheable=true)
  public static List<Lead> getNewLeadsRecords(
    String dateFilter,
    String practiceArea,
    String officeLocation,
    String typeOfCivilLaw,
    Boolean firstCallOnly
  ) {
    try {
      DateRange dr = getDateRangeForFilter(dateFilter);
      DateTime startDateTime = DateTime.newInstance(
        dr.startDate,
        Time.newInstance(0, 0, 0, 0)
      );
      DateTime endDateTime = DateTime.newInstance(
        dr.endDate.addDays(1),
        Time.newInstance(0, 0, 0, 0)
      );

      String baseWhere = 'CreatedDate >= :startDateTime AND CreatedDate < :endDateTime';
      if (String.isNotBlank(practiceArea)) {
        baseWhere += ' AND Category__c = :practiceArea';
      }
      if (String.isNotBlank(officeLocation)) {
        baseWhere += ' AND Preferred_Office_Location__c = :officeLocation';
      }
      if (String.isNotBlank(typeOfCivilLaw)) {
        baseWhere += ' AND Type_of_Civil_Law__c = :typeOfCivilLaw';
      }
      if (firstCallOnly != null && firstCallOnly) {
        baseWhere += ' AND First_Call__c = true';
      }

      String query =
        'SELECT Id, Name, Owner.Name, Intake_Attorney__r.Name, ' +
        'Category__c, Preferred_Office_Location__c, ' +
        'CreatedDate, Date_Signed_Up__c, Lead_Completion_Date__c, ' +
        'Date_First_Payment__c, Post_Con_Completed_Date__c, First_Call__c ' +
        'FROM Lead WHERE ' +
        baseWhere +
        ' ORDER BY CreatedDate DESC';

      return Database.query(query);
    } catch (Exception e) {
      throw new AuraHandledException(
        'Error fetching new leads records: ' + e.getMessage()
      );
    }
  }

  @AuraEnabled(cacheable=true)
  public static List<Lead> getIntakeSpecialistCallsRecords(
    String dateFilter,
    String practiceArea,
    String officeLocation,
    String typeOfCivilLaw
  ) {
    try {
      DateRange dr = getDateRangeForFilter(dateFilter);
      Date startDate = dr.startDate;
      Date endDate = dr.endDate;

      String baseWhere = 'Post_Con_Completed_Date__c >= :startDate AND Post_Con_Completed_Date__c <= :endDate';
      if (String.isNotBlank(practiceArea)) {
        baseWhere += ' AND Category__c = :practiceArea';
      }
      if (String.isNotBlank(officeLocation)) {
        baseWhere += ' AND Preferred_Office_Location__c = :officeLocation';
      }
      if (String.isNotBlank(typeOfCivilLaw)) {
        baseWhere += ' AND Type_of_Civil_Law__c = :typeOfCivilLaw';
      }

      String query =
        'SELECT Id, Name, Owner.Name, Intake_Attorney__r.Name, ' +
        'Category__c, Preferred_Office_Location__c, ' +
        'CreatedDate, Date_Signed_Up__c, Lead_Completion_Date__c, ' +
        'Date_First_Payment__c, Post_Con_Completed_Date__c ' +
        'FROM Lead WHERE ' +
        baseWhere +
        ' AND Post_Consult_Complete__c = true AND Intake_Attorney__c = null AND Were_you_able_to_speak_with_client__c != \'No (No Show)\' ' +
        'ORDER BY Post_Con_Completed_Date__c DESC';

      return Database.query(query);
    } catch (Exception e) {
      throw new AuraHandledException(
        'Error fetching intake specialist calls records: ' + e.getMessage()
      );
    }
  }

  @AuraEnabled(cacheable=true)
  public static List<Lead> getIntakeAttorneyCallsRecords(
    String dateFilter,
    String practiceArea,
    String officeLocation,
    String typeOfCivilLaw
  ) {
    try {
      DateRange dr = getDateRangeForFilter(dateFilter);
      Date startDate = dr.startDate;
      Date endDate = dr.endDate;

      String baseWhere = 'Post_Con_Completed_Date__c >= :startDate AND Post_Con_Completed_Date__c <= :endDate';
      if (String.isNotBlank(practiceArea)) {
        baseWhere += ' AND Category__c = :practiceArea';
      }
      if (String.isNotBlank(officeLocation)) {
        baseWhere += ' AND Preferred_Office_Location__c = :officeLocation';
      }
      if (String.isNotBlank(typeOfCivilLaw)) {
        baseWhere += ' AND Type_of_Civil_Law__c = :typeOfCivilLaw';
      }

      String query =
        'SELECT Id, Name, Owner.Name, Intake_Attorney__r.Name, ' +
        'Category__c, Preferred_Office_Location__c, ' +
        'CreatedDate, Date_Signed_Up__c, Lead_Completion_Date__c, ' +
        'Date_First_Payment__c, Post_Con_Completed_Date__c ' +
        'FROM Lead WHERE ' +
        baseWhere +
        ' AND Intake_Attorney__c != null AND Post_Consult_Complete__c = true AND Were_you_able_to_speak_with_client__c != \'No (No Show)\' ' +
        'ORDER BY Post_Con_Completed_Date__c DESC';

      return Database.query(query);
    } catch (Exception e) {
      throw new AuraHandledException(
        'Error fetching intake attorney calls records: ' + e.getMessage()
      );
    }
  }

  @AuraEnabled(cacheable=true)
  public static List<Lead> getIntakeAttorneyNoShowsRecords(
    String dateFilter,
    String practiceArea,
    String officeLocation,
    String typeOfCivilLaw
  ) {
    try {
      DateRange dr = getDateRangeForFilter(dateFilter);
      Date startDate = dr.startDate;
      Date endDate = dr.endDate;

      String baseWhere = 'Post_Con_Completed_Date__c >= :startDate AND Post_Con_Completed_Date__c <= :endDate';
      if (String.isNotBlank(practiceArea)) {
        baseWhere += ' AND Category__c = :practiceArea';
      }
      if (String.isNotBlank(officeLocation)) {
        baseWhere += ' AND Preferred_Office_Location__c = :officeLocation';
      }
      if (String.isNotBlank(typeOfCivilLaw)) {
        baseWhere += ' AND Type_of_Civil_Law__c = :typeOfCivilLaw';
      }

      String query =
        'SELECT Id, Name, Owner.Name, Intake_Attorney__r.Name, ' +
        'Category__c, Preferred_Office_Location__c, ' +
        'CreatedDate, Date_Signed_Up__c, Lead_Completion_Date__c, ' +
        'Date_First_Payment__c, Post_Con_Completed_Date__c ' +
        'FROM Lead WHERE ' +
        baseWhere +
        ' AND Intake_Attorney__c != null AND Were_you_able_to_speak_with_client__c = \'No (No Show)\' AND Post_Consult_Complete__c = true ' +
        'ORDER BY Post_Con_Completed_Date__c DESC';

      return Database.query(query);
    } catch (Exception e) {
      throw new AuraHandledException(
        'Error fetching intake attorney no shows records: ' + e.getMessage()
      );
    }
  }

  @AuraEnabled(cacheable=true)
  public static List<Lead> getTotalClosedByISRecords(
    String dateFilter,
    String practiceArea,
    String officeLocation,
    String typeOfCivilLaw
  ) {
    try {
      DateRange dr = getDateRangeForFilter(dateFilter);
      Date startDate = dr.startDate;
      Date endDate = dr.endDate;

      String baseWhere = 'Matter__r.Date_First_Payment__c >= :startDate AND Matter__r.Date_First_Payment__c <= :endDate';
      if (String.isNotBlank(practiceArea)) {
        baseWhere += ' AND Category__c = :practiceArea';
      }
      if (String.isNotBlank(officeLocation)) {
        baseWhere += ' AND Preferred_Office_Location__c = :officeLocation';
      }
      if (String.isNotBlank(typeOfCivilLaw)) {
        baseWhere += ' AND Type_of_Civil_Law__c = :typeOfCivilLaw';
      }

      String query =
        'SELECT Id, Name, Owner.Name, Intake_Attorney__r.Name, ' +
        'Category__c, Preferred_Office_Location__c, ' +
        'CreatedDate, Date_Signed_Up__c, Lead_Completion_Date__c, ' +
        'Date_First_Payment__c, Post_Con_Completed_Date__c, ' +
        'Matter__r.Date_FA_was_sent__c, Matter__r.Date_First_Payment__c ' +
        'FROM Lead WHERE ' +
        baseWhere +
        ' AND Intake_Attorney__c = null AND Matter__c != null AND Matter__r.Date_FA_was_sent__c != null AND Matter__r.Date_First_Payment__c != null ' +
        'ORDER BY Matter__r.Date_First_Payment__c DESC';

      return Database.query(query);
    } catch (Exception e) {
      throw new AuraHandledException(
        'Error fetching total closed by IS records: ' + e.getMessage()
      );
    }
  }

  @AuraEnabled(cacheable=true)
  public static List<Lead> getTotalClosedByIARecords(
    String dateFilter,
    String practiceArea,
    String officeLocation,
    String typeOfCivilLaw
  ) {
    try {
      DateRange dr = getDateRangeForFilter(dateFilter);
      Date startDate = dr.startDate;
      Date endDate = dr.endDate;

      String baseWhere = 'Matter__r.Date_First_Payment__c >= :startDate AND Matter__r.Date_First_Payment__c <= :endDate';
      if (String.isNotBlank(practiceArea)) {
        baseWhere += ' AND Category__c = :practiceArea';
      }
      if (String.isNotBlank(officeLocation)) {
        baseWhere += ' AND Preferred_Office_Location__c = :officeLocation';
      }
      if (String.isNotBlank(typeOfCivilLaw)) {
        baseWhere += ' AND Type_of_Civil_Law__c = :typeOfCivilLaw';
      }

      String query =
        'SELECT Id, Name, Owner.Name, Intake_Attorney__r.Name, ' +
        'Category__c, Preferred_Office_Location__c, ' +
        'CreatedDate, Date_Signed_Up__c, Lead_Completion_Date__c, ' +
        'Date_First_Payment__c, Post_Con_Completed_Date__c, ' +
        'Matter__r.Date_FA_was_sent__c, Matter__r.Date_First_Payment__c ' +
        'FROM Lead WHERE ' +
        baseWhere +
        ' AND Intake_Attorney__c != null AND Matter__c != null AND Matter__r.Date_FA_was_sent__c != null AND Matter__r.Date_First_Payment__c != null ' +
        'ORDER BY Matter__r.Date_First_Payment__c DESC';

      return Database.query(query);
    } catch (Exception e) {
      throw new AuraHandledException(
        'Error fetching total closed by IA records: ' + e.getMessage()
      );
    }
  }
}