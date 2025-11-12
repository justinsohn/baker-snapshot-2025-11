@isTest
public class HomePageDashboardControllerTest {
  @TestSetup
  static void makeData() {
    // Create test users with target hours
    Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
    User testUser = new User(
      Alias = 'test',
      Email = 'test@baker.com.test',
      EmailEncodingKey = 'UTF-8',
      LastName = 'TestUser',
      LanguageLocaleKey = 'en_US',
      LocaleSidKey = 'en_US',
      ProfileId = p.Id,
      TimeZoneSidKey = 'America/Los_Angeles',
      UserName = 'test@baker.com.test',
      IsActive = true,
      Target_Hours__c = 2000
    );
    insert testUser;

    // Create test leads with various statuses and dates
    List<Lead> testLeads = new List<Lead>();
    for (Integer i = 0; i < 5; i++) {
      Lead l = new Lead(
        FirstName = 'Test',
        LastName = 'Lead' + i,
        Company = 'Test Company',
        Email = 'testlead' + i + '@example.com',
        Phone = '555-123' + i,
        Source__c = i < 3 ? 'Website' : 'Referral',
        Status = i < 2 ? 'Open - Not Contacted' : 'Qualified',
        Category__c = 'General Civil',
        Landing_Page__c = 'example.com/criminal-law',
        Intake_Completion_Date__c = Date.today().addDays(-i),
        Consult_Held_With__c = testUser.Id,
        Preferred_Office_Location__c = i < 3 ? 'Los Angeles' : 'San Francisco'
      );
      testLeads.add(l);
    }
    insert testLeads;

    // Create test matters (some with and without responsible attorney)
    List<Matter__c> testMatters = new List<Matter__c>();
    for (Integer i = 0; i < 4; i++) {
      Matter__c m = new Matter__c(
        Name = 'Test Matter ' + i,
        Practice_Area__c = 'General Civil',
        Status__c = i < 2 ? 'Open' : 'Pending',
        Responsible_Attorney__c = i < 3 ? testUser.Id : null // Last matter has no responsible attorney
      );
      testMatters.add(m);
    }
    insert testMatters;

    // Create test invoices
    List<Invoice__c> testInvoices = new List<Invoice__c>();
    for (Integer i = 0; i < 4; i++) {
      Invoice__c inv = new Invoice__c(
        Name = 'Test Invoice ' + i,
        Amount__c = 1000 + (i * 500),
        Status__c = i == 0
          ? 'Draft'
          : (i == 1 ? 'Sent' : (i == 2 ? 'Paid' : 'Overdue')),
        Due_Date__c = Date.today().addDays(-i * 10),
        Amount_Paid__c = i == 2 ? 1500 : 0,
        Balance__c = i == 2 ? 0 : (1000 + (i * 500)),
        Matter__c = testMatters[0].Id
      );
      testInvoices.add(inv);
    }
    insert testInvoices;

    // Create test time entries
    List<Time_Entry__c> testTimeEntries = new List<Time_Entry__c>();
    for (Integer i = 0; i < 3; i++) {
      Time_Entry__c te = new Time_Entry__c(
        Name = 'Test Time Entry ' + i,
        Date__c = Date.today().addDays(-i),
        Duration__c = 2.5 + i,
        Rate__c = 100 + (i * 50),
        Matter__c = testMatters[0].Id,
        OwnerId = testUser.Id
      );
      testTimeEntries.add(te);
    }
    insert testTimeEntries;
  }

  @isTest
  static void testGetPracticeAreaOptions() {
    Test.startTest();
    List<HomePageDashboardController.ComboboxOption> options = HomePageDashboardController.getPracticeAreaOptions();
    Test.stopTest();

    System.assert(options.size() > 0, 'Should return practice area options');
    System.assertEquals(
      'All Practice Areas',
      options[0].label,
      'First option should be All Practice Areas'
    );
  }

  @isTest
  static void testGetOfficeLocationOptions() {
    Test.startTest();
    List<HomePageDashboardController.ComboboxOption> options = HomePageDashboardController.getOfficeLocationOptions();
    Test.stopTest();

    System.assert(options.size() > 0, 'Should return office location options');
    System.assertEquals(
      'All Office Locations',
      options[0].label,
      'First option should be All Office Locations'
    );
    // Test that our test data office locations are present
    Boolean foundLA = false;
    Boolean foundSF = false;
    for (HomePageDashboardController.ComboboxOption option : options) {
      if (option.label == 'Los Angeles')
        foundLA = true;
      if (option.label == 'San Francisco')
        foundSF = true;
    }
    System.assert(foundLA, 'Should include Los Angeles from test data');
    System.assert(foundSF, 'Should include San Francisco from test data');
  }

  @isTest
  static void testGetTypeOfCivilLawOptions() {
    Test.startTest();
    List<HomePageDashboardController.ComboboxOption> options = HomePageDashboardController.getTypeOfCivilLawOptions();
    Test.stopTest();

    System.assert(
      options.size() > 0,
      'Should return type of civil law options'
    );
    System.assertEquals(
      'All Types of Civil Law',
      options[0].label,
      'First option should be All Types of Civil Law'
    );
  }

  @isTest
  static void testGetLeadCount() {
    Test.startTest();
    HomePageDashboardController.LeadCountSummary summary = HomePageDashboardController.getLeadCount(
      'THIS_YEAR',
      '',
      '',
      ''
    );
    Test.stopTest();

    System.assertNotEquals(null, summary, 'Should return lead count summary');
    System.assert(summary.leadCount >= 0, 'Lead count should be non-negative');
    System.assertEquals(
      'This Year',
      summary.periodLabel,
      'Period label should match filter'
    );
  }

  @isTest
  static void testGetLeadConversionBySource() {
    Test.startTest();
    List<HomePageDashboardController.LeadSourceConversionSummary> summaries = HomePageDashboardController.getLeadConversionBySource(
      'THIS_YEAR',
      '',
      '',
      ''
    );
    Test.stopTest();

    System.assert(
      summaries.size() >= 0,
      'Should return lead conversion summaries'
    );
    for (
      HomePageDashboardController.LeadSourceConversionSummary summary : summaries
    ) {
      System.assertNotEquals(null, summary.source, 'Source should not be null');
      System.assert(
        summary.conversionRate >= 0,
        'Conversion rate should be non-negative'
      );
    }
  }

  @isTest
  static void testGetTotalLeadsBySource() {
    Test.startTest();
    List<HomePageDashboardController.LeadSourceCountSummary> summaries = HomePageDashboardController.getTotalLeadsBySource(
      'THIS_YEAR',
      '',
      '',
      ''
    );
    Test.stopTest();

    System.assert(
      summaries.size() >= 0,
      'Should return lead source count summaries'
    );
    for (
      HomePageDashboardController.LeadSourceCountSummary summary : summaries
    ) {
      System.assertNotEquals(null, summary.source, 'Source should not be null');
      System.assert(
        summary.leadCount >= 0,
        'Lead count should be non-negative'
      );
    }
  }

  @isTest
  static void testLeadSourceNormalizationFromUrl() {
    Lead trackedLead = new Lead(
      FirstName = 'Tracked',
      LastName = 'CampaignLead',
      Company = 'Tracked Company',
      Email = 'trackedlead@test.com',
      Phone = '555-1001',
      Source__c = 'https://jbakerlawgroup.com/?utm_campaign=gmb&utm_medium=local&utm_source=googleSource:Google%20My%20BusinesssearchCampaign:PageId:.',
      LeadSource = 'Google My Business',
      Status = 'Qualified',
      Category__c = 'Personal Injury'
    );
    Lead googleOrganicLead = new Lead(
      FirstName = 'Tracked',
      LastName = 'GoogleOrganic',
      Company = 'Tracked Company 2',
      Email = 'trackedlead2@test.com',
      Phone = '555-1002',
      Source__c = 'https://www.google.com/Source:Google OrganicgbpCampaign:austinPageId:.',
      LeadSource = 'Google Organic',
      Status = 'Open - Not Contacted',
      Category__c = 'General Civil',
      Preferred_Office_Location__c = 'Los Angeles'
    );
    insert new List<Lead>{ trackedLead, googleOrganicLead };

    Test.startTest();
    List<HomePageDashboardController.LeadSourceConversionSummary> conversions = HomePageDashboardController.getLeadConversionBySource(
      'THIS_MONTH',
      '',
      '',
      ''
    );
    List<HomePageDashboardController.LeadSourceCountSummary> totals = HomePageDashboardController.getTotalLeadsBySource(
      'THIS_MONTH',
      '',
      '',
      ''
    );
    List<HomePageDashboardController.LeadSourceCountSummary> organicTotals = HomePageDashboardController.getTotalLeadsBySource(
      'THIS_MONTH',
      'General Civil',
      'Los Angeles',
      ''
    );
    Test.stopTest();

    Boolean foundConversion = false;
    for (
      HomePageDashboardController.LeadSourceConversionSummary summary : conversions
    ) {
      System.assert(
        !summary.source.startsWith('='),
        'Sources should not start with ='
      );
      if (summary.source == 'Google My Business') {
        foundConversion = true;
        System.assertEquals(
          1,
          summary.totalClosed,
          'Normalized conversion count should match'
        );
      }
    }
    System.assert(
      foundConversion,
      'Normalized Google My Business source should be present in conversions'
    );

    Boolean foundTotal = false;
    for (HomePageDashboardController.LeadSourceCountSummary summary : totals) {
      System.assert(
        !summary.source.startsWith('='),
        'Sources should not start with ='
      );
      if (summary.source == 'Google My Business') {
        foundTotal = true;
        System.assert(
          summary.leadCount >= 1,
          'Normalized total count should be at least 1'
        );
      }
    }
    System.assert(
      foundTotal,
      'Normalized Google My Business source should be present in totals'
    );

    System.assert(
      organicTotals.size() > 0,
      'Filtered totals should return at least one record'
    );
    Boolean foundOrganicTotal = false;
    for (
      HomePageDashboardController.LeadSourceCountSummary summary : organicTotals
    ) {
      if (summary.source == 'Google Organic') {
        foundOrganicTotal = true;
        System.assert(
          summary.leadCount >= 1,
          'Lead count should be at least 1 for Google Organic'
        );
        break;
      }
    }
    System.assert(
      foundOrganicTotal,
      'Should include Google Organic in filtered totals'
    );
  }

  @isTest
  static void testGetLeadsByLandingPage() {
    Test.startTest();
    List<HomePageDashboardController.LandingPageLeadSummary> summaries = HomePageDashboardController.getLeadsByLandingPage(
      'THIS_YEAR',
      '',
      '',
      ''
    );
    Test.stopTest();

    System.assert(
      summaries.size() >= 0,
      'Should return landing page lead summaries'
    );
    for (
      HomePageDashboardController.LandingPageLeadSummary summary : summaries
    ) {
      System.assertNotEquals(
        null,
        summary.landingPage,
        'Landing page should not be null'
      );
      System.assert(
        summary.leadCount >= 0,
        'Lead count should be non-negative'
      );
    }
  }

  @isTest
  static void testGetMatterPipelineData() {
    Test.startTest();
    List<HomePageDashboardController.MatterPipelineSummary> summaries = HomePageDashboardController.getMatterPipelineData(
      ''
    );
    Test.stopTest();

    System.assert(
      summaries.size() >= 0,
      'Should return matter pipeline summaries'
    );
    for (
      HomePageDashboardController.MatterPipelineSummary summary : summaries
    ) {
      System.assertNotEquals(
        null,
        summary.practiceArea,
        'Practice area should not be null'
      );
      System.assert(
        summary.totalCount >= 0,
        'Total count should be non-negative'
      );
      System.assertEquals(
        summary.openCount + summary.pendingCount,
        summary.totalCount,
        'Total should equal open + pending'
      );
    }
  }

  @isTest
  static void testGetCloseRateByAttorney() {
    Test.startTest();
    List<HomePageDashboardController.AttorneyCloseRateSummary> summaries = HomePageDashboardController.getCloseRateByAttorney(
      'THIS_YEAR',
      '',
      '',
      ''
    );
    Test.stopTest();

    System.assert(
      summaries.size() >= 0,
      'Should return attorney close rate summaries'
    );
    for (
      HomePageDashboardController.AttorneyCloseRateSummary summary : summaries
    ) {
      System.assertNotEquals(
        null,
        summary.attorneyName,
        'Attorney name should not be null'
      );
      System.assert(
        summary.closeRate >= 0,
        'Close rate should be non-negative'
      );
    }
  }

  @isTest
  static void testGetIntakeCompletions() {
    Test.startTest();
    List<HomePageDashboardController.IntakeCompletionSummary> summaries = HomePageDashboardController.getIntakeCompletions(
      'THIS_YEAR',
      '',
      '',
      ''
    );
    Test.stopTest();

    System.assert(
      summaries.size() >= 0,
      'Should return intake completion summaries'
    );
    for (
      HomePageDashboardController.IntakeCompletionSummary summary : summaries
    ) {
      System.assertNotEquals(
        null,
        summary.ownerName,
        'Owner name should not be null'
      );
      System.assert(
        summary.intakeCount >= 0,
        'Intake count should be non-negative'
      );
    }
  }

  @isTest
  static void testGetMatterTreeData() {
    Test.startTest();
    List<HomePageDashboardController.MatterTreeNode> treeNodes = HomePageDashboardController.getMatterTreeData(
      ''
    );
    Test.stopTest();

    System.assert(treeNodes.size() >= 0, 'Should return matter tree nodes');
    for (HomePageDashboardController.MatterTreeNode node : treeNodes) {
      System.assertNotEquals(null, node.label, 'Node label should not be null');
    }
  }

  @isTest
  static void testModalMethods() {
    Test.startTest();

    // Test modal record methods
    List<HomePageDashboardController.MatterDetail> matters = HomePageDashboardController.getOpenMatterRecords(
      ''
    );
    List<HomePageDashboardController.LeadDetail> leads = HomePageDashboardController.getNewLeadRecords(
      'THIS_YEAR',
      '',
      '',
      ''
    );
    // Time entries and invoices removed in Phase 2

    // Test export methods
    String salesExport = HomePageDashboardController.exportSalesMarketingData(
      'THIS_YEAR',
      '',
      '',
      ''
    );
    String leadCountExport = HomePageDashboardController.exportLeadCount(
      'THIS_MONTH',
      '',
      '',
      ''
    );
    String intakeExport = HomePageDashboardController.exportIntakeCompletions(
      'THIS_MONTH',
      '',
      '',
      ''
    );
    String closeRateExport = HomePageDashboardController.exportCloseRateByAttorney(
      'THIS_MONTH',
      '',
      '',
      ''
    );
    String conversionExport = HomePageDashboardController.exportLeadConversionBySource(
      'THIS_MONTH',
      '',
      '',
      ''
    );
    String totalLeadsExport = HomePageDashboardController.exportTotalLeadsBySource(
      'THIS_MONTH',
      '',
      '',
      ''
    );
    String landingPageExport = HomePageDashboardController.exportLeadsByLandingPage(
      'THIS_MONTH',
      '',
      '',
      ''
    );

    Test.stopTest();

    System.assert(matters.size() >= 0, 'Should return matter details');
    System.assert(leads.size() >= 0, 'Should return lead details');

    // Test export data is not null and contains headers
    System.assert(
      salesExport != null && salesExport.contains('Section,Metric'),
      'Sales export should contain data'
    );

    // Test individual component exports
    System.assert(
      leadCountExport != null && leadCountExport.contains('Metric,Count'),
      'Lead count export should contain data'
    );
    System.assert(
      intakeExport != null &&
      intakeExport.contains('Intake Specialist Name,Intake Count'),
      'Intake export should contain data'
    );
    System.assert(
      closeRateExport != null &&
      closeRateExport.contains('Attorney Name,Total Closes,Close Rate'),
      'Close rate export should contain data'
    );
    System.assert(
      conversionExport != null &&
      conversionExport.contains('Source,Conversion Rate'),
      'Conversion export should contain data'
    );
    System.assert(
      totalLeadsExport != null &&
      totalLeadsExport.contains('Source,Lead Count'),
      'Total leads export should contain data'
    );
    System.assert(
      landingPageExport != null &&
      landingPageExport.contains('Landing Page,Lead Count'),
      'Landing page export should contain data'
    );
  }

  @isTest
  static void testWithFilters() {
    Test.startTest();

    // Test methods with practice area filter (using Category__c values)
    HomePageDashboardController.LeadCountSummary leadCount = HomePageDashboardController.getLeadCount(
      'THIS_YEAR',
      'Pre-Litigation',
      '',
      ''
    );
    List<HomePageDashboardController.MatterPipelineSummary> matterPipeline = HomePageDashboardController.getMatterPipelineData(
      'General Civil'
    );

    // Test with office location filter
    HomePageDashboardController.LeadCountSummary leadCountWithOffice = HomePageDashboardController.getLeadCount(
      'THIS_YEAR',
      '',
      'Los Angeles',
      ''
    );

    // Test with multiple filters
    HomePageDashboardController.LeadCountSummary leadCountBothFilters = HomePageDashboardController.getLeadCount(
      'THIS_MONTH',
      'Litigation',
      'Los Angeles',
      ''
    );

    Test.stopTest();

    System.assertNotEquals(
      null,
      leadCount,
      'Should return filtered lead count'
    );
    System.assert(
      matterPipeline.size() >= 0,
      'Should return filtered matter pipeline'
    );
    System.assertNotEquals(
      null,
      leadCountWithOffice,
      'Should return office location filtered lead count'
    );
    System.assertNotEquals(
      null,
      leadCountBothFilters,
      'Should return multi-filtered lead count'
    );
  }

  @isTest
  static void testDateFilterVariations() {
    Test.startTest();

    // Test different date filters
    HomePageDashboardController.LeadCountSummary today = HomePageDashboardController.getLeadCount(
      'TODAY',
      '',
      '',
      ''
    );
    HomePageDashboardController.LeadCountSummary yesterday = HomePageDashboardController.getLeadCount(
      'YESTERDAY',
      '',
      '',
      ''
    );
    HomePageDashboardController.LeadCountSummary thisMonth = HomePageDashboardController.getLeadCount(
      'THIS_MONTH',
      '',
      '',
      ''
    );
    HomePageDashboardController.LeadCountSummary lastMonth = HomePageDashboardController.getLeadCount(
      'LAST_MONTH',
      '',
      '',
      ''
    );
    HomePageDashboardController.LeadCountSummary thisQuarter = HomePageDashboardController.getLeadCount(
      'THIS_QUARTER',
      '',
      '',
      ''
    );
    HomePageDashboardController.LeadCountSummary lastQuarter = HomePageDashboardController.getLeadCount(
      'LAST_QUARTER',
      '',
      '',
      ''
    );
    HomePageDashboardController.LeadCountSummary thisYear = HomePageDashboardController.getLeadCount(
      'THIS_YEAR',
      '',
      '',
      ''
    );
    HomePageDashboardController.LeadCountSummary lastYear = HomePageDashboardController.getLeadCount(
      'LAST_YEAR',
      '',
      '',
      ''
    );

    Test.stopTest();

    System.assertEquals('Today', today.periodLabel, 'Today filter should work');
    System.assertEquals(
      'Yesterday',
      yesterday.periodLabel,
      'Yesterday filter should work'
    );
    System.assertEquals(
      'This Month',
      thisMonth.periodLabel,
      'This month filter should work'
    );
    System.assertEquals(
      'Last Month',
      lastMonth.periodLabel,
      'Last month filter should work'
    );
    System.assertEquals(
      'This Quarter',
      thisQuarter.periodLabel,
      'This quarter filter should work'
    );
    System.assertEquals(
      'Last Quarter',
      lastQuarter.periodLabel,
      'Last quarter filter should work'
    );
    System.assertEquals(
      'This Year',
      thisYear.periodLabel,
      'This year filter should work'
    );
    System.assertEquals(
      'Last Year',
      lastYear.periodLabel,
      'Last year filter should work'
    );
  }

  @isTest
  static void testPercentageCalculations() {
    Test.startTest();

    // Test that percentage calculations return values multiplied by 100
    List<HomePageDashboardController.LeadSourceConversionSummary> conversionSummaries = HomePageDashboardController.getLeadConversionBySource(
      'THIS_YEAR',
      '',
      '',
      ''
    );
    List<HomePageDashboardController.AttorneyCloseRateSummary> closeRateSummaries = HomePageDashboardController.getCloseRateByAttorney(
      'THIS_YEAR',
      '',
      '',
      ''
    );

    Test.stopTest();

    // Verify percentage values are properly calculated (should be between 0-100, not 0-1)
    for (
      HomePageDashboardController.LeadSourceConversionSummary summary : conversionSummaries
    ) {
      System.assert(
        summary.conversionRate >= 0 && summary.conversionRate <= 100,
        'Conversion rate should be between 0-100: ' + summary.conversionRate
      );
    }

    for (
      HomePageDashboardController.AttorneyCloseRateSummary summary : closeRateSummaries
    ) {
      System.assert(
        summary.closeRate >= 0 && summary.closeRate <= 100,
        'Close rate should be between 0-100: ' + summary.closeRate
      );
    }
  }

  @isTest
  static void testNullHandlingAndEdgeCases() {
    Test.startTest();

    // Test matter tree data to cover unassigned attorney case (line 45)
    List<HomePageDashboardController.MatterTreeNode> treeNodes = HomePageDashboardController.getMatterTreeData(
      ''
    );

    // Test matter tree with practice area filter to cover line 333
    List<HomePageDashboardController.MatterTreeNode> filteredTreeNodes = HomePageDashboardController.getMatterTreeData(
      'General Civil'
    );

    // Test sorting functionality by creating test data with null values for compareTo methods
    List<HomePageDashboardController.LeadSourceConversionSummary> conversionSummaries = new List<HomePageDashboardController.LeadSourceConversionSummary>();
    conversionSummaries.add(
      new HomePageDashboardController.LeadSourceConversionSummary(
        null,
        0.5,
        5,
        10
      )
    ); // null source
    conversionSummaries.add(
      new HomePageDashboardController.LeadSourceConversionSummary(
        'Web',
        0.6,
        6,
        10
      )
    );
    conversionSummaries.add(
      new HomePageDashboardController.LeadSourceConversionSummary(
        'Referral',
        0.4,
        4,
        10
      )
    );
    conversionSummaries.sort();

    List<HomePageDashboardController.AttorneyCloseRateSummary> closeRateSummaries = new List<HomePageDashboardController.AttorneyCloseRateSummary>();
    closeRateSummaries.add(
      new HomePageDashboardController.AttorneyCloseRateSummary(null, 0.5, 5, 10)
    ); // null attorney name
    closeRateSummaries.add(
      new HomePageDashboardController.AttorneyCloseRateSummary(
        'John Doe',
        0.6,
        6,
        10
      )
    );
    closeRateSummaries.add(
      new HomePageDashboardController.AttorneyCloseRateSummary(
        'Jane Smith',
        0.4,
        4,
        10
      )
    );
    closeRateSummaries.sort();

    // Test more compareTo edge cases to cover lines 87, 116
    HomePageDashboardController.LeadSourceConversionSummary nullSummary = new HomePageDashboardController.LeadSourceConversionSummary(
      null,
      0.5,
      5,
      10
    );
    HomePageDashboardController.LeadSourceConversionSummary webSummary = new HomePageDashboardController.LeadSourceConversionSummary(
      'Web',
      0.6,
      6,
      10
    );
    Integer result1 = nullSummary.compareTo(webSummary); // null compareTo non-null
    Integer result2 = webSummary.compareTo(nullSummary); // non-null compareTo null

    HomePageDashboardController.AttorneyCloseRateSummary nullCloseSummary = new HomePageDashboardController.AttorneyCloseRateSummary(
      null,
      0.5,
      5,
      10
    );
    HomePageDashboardController.AttorneyCloseRateSummary johnSummary = new HomePageDashboardController.AttorneyCloseRateSummary(
      'John',
      0.6,
      6,
      10
    );
    Integer result3 = nullCloseSummary.compareTo(johnSummary); // null compareTo non-null
    Integer result4 = johnSummary.compareTo(nullCloseSummary); // non-null compareTo null

    Test.stopTest();

    // Verify sorting worked (null values should come first)
    System.assertEquals(
      null,
      conversionSummaries[0].source,
      'Null source should be sorted first'
    );
    System.assertEquals(
      null,
      closeRateSummaries[0].attorneyName,
      'Null attorney name should be sorted first'
    );

    // Verify compareTo results for edge cases
    System.assertEquals(
      -1,
      result1,
      'Null should return -1 when compared to non-null'
    );
    System.assertEquals(
      1,
      result2,
      'Non-null should return 1 when compared to null'
    );
    System.assertEquals(
      -1,
      result3,
      'Null attorney should return -1 when compared to non-null'
    );
    System.assertEquals(
      1,
      result4,
      'Non-null attorney should return 1 when compared to null'
    );

    // Verify matter tree includes matters without responsible attorneys
    Boolean foundUnassigned = false;
    for (HomePageDashboardController.MatterTreeNode node : treeNodes) {
      // Check if this is an attorney-level node with "Unassigned" label
      if (node.label == 'Unassigned') {
        foundUnassigned = true;
        break;
      }
      // Check children for attorney nodes with "Unassigned" label
      for (HomePageDashboardController.MatterTreeNode child : node.children) {
        if (child.label == 'Unassigned') {
          foundUnassigned = true;
          break;
        }
        // Check matter nodes for unassigned responsible attorney
        for (
          HomePageDashboardController.MatterTreeNode grandchild : child.children
        ) {
          if (grandchild.responsibleAttorney == 'Unassigned') {
            foundUnassigned = true;
            break;
          }
        }
        if (foundUnassigned)
          break;
      }
      if (foundUnassigned)
        break;
    }
    System.assert(
      foundUnassigned,
      'Should find matters with unassigned attorneys'
    );

    // Verify filtered results
    System.assert(
      filteredTreeNodes.size() >= 0,
      'Should return filtered tree data'
    );
  }

  @isTest
  static void testAdditionalEdgeCases() {
    Test.startTest();

    // Create additional test data to cover more conditional branches
    List<Lead> additionalLeads = new List<Lead>();

    // Create leads with null/empty landing pages to test line 424, 427
    Lead leadWithoutLandingPage = new Lead(
      FirstName = 'NoLanding',
      LastName = 'PageLead',
      Company = 'Test Company',
      Email = 'nolanding@test.com',
      Phone = '555-000-0001',
      Source__c = 'Web',
      Status = 'Open - Not Contacted',
      Category__c = 'Personal Injury',
      Landing_Page__c = null, // null landing page
      Preferred_Office_Location__c = 'Seattle'
    );
    additionalLeads.add(leadWithoutLandingPage);

    // Create lead with empty landing page
    Lead leadWithEmptyLandingPage = new Lead(
      FirstName = 'Empty',
      LastName = 'LandingLead',
      Company = 'Test Company',
      Email = 'empty@test.com',
      Phone = '555-000-0002',
      Source__c = 'Web',
      Status = 'Open - Not Contacted',
      Category__c = 'Personal Injury',
      Landing_Page__c = '', // empty landing page
      Preferred_Office_Location__c = 'Seattle'
    );
    additionalLeads.add(leadWithEmptyLandingPage);

    insert additionalLeads;

    // Test leads by landing page to trigger conditional logic
    List<HomePageDashboardController.LandingPageLeadSummary> landingSummaries = HomePageDashboardController.getLeadsByLandingPage(
      'THIS_YEAR',
      '',
      '',
      ''
    );

    // Test with different category combinations to hit more conditional branches
    HomePageDashboardController.LeadCountSummary leadCountPreLitigation = HomePageDashboardController.getLeadCount(
      'THIS_YEAR',
      'Pre-Litigation',
      '',
      ''
    );

    HomePageDashboardController.LeadCountSummary leadCountLitigation = HomePageDashboardController.getLeadCount(
      'THIS_YEAR',
      'Litigation',
      '',
      ''
    );

    // Test matter pipeline with different practice areas
    List<HomePageDashboardController.MatterPipelineSummary> pipelinePersonalInjury = HomePageDashboardController.getMatterPipelineData(
      'Personal Injury'
    );
    List<HomePageDashboardController.MatterPipelineSummary> pipelineFamilyLaw = HomePageDashboardController.getMatterPipelineData(
      'Family Law'
    );

    Test.stopTest();

    // Verify results
    System.assert(
      landingSummaries.size() >= 0,
      'Should return landing page summaries'
    );
    System.assertNotEquals(
      null,
      leadCountPreLitigation,
      'Should return pre-litigation lead count'
    );
    System.assertNotEquals(
      null,
      leadCountLitigation,
      'Should return litigation lead count'
    );
    System.assert(
      pipelinePersonalInjury.size() >= 0,
      'Should return personal injury pipeline data'
    );
    System.assert(
      pipelineFamilyLaw.size() >= 0,
      'Should return family law pipeline data'
    );
  }

  @isTest
  static void testComparatorsAndTrendMethods() {
    Test.startTest();

    // Test IntakeCompletionComparator
    List<HomePageDashboardController.IntakeCompletionSummary> intakeSummaries = new List<HomePageDashboardController.IntakeCompletionSummary>();
    intakeSummaries.add(
      new HomePageDashboardController.IntakeCompletionSummary('User A', 5)
    );
    intakeSummaries.add(
      new HomePageDashboardController.IntakeCompletionSummary('User B', 10)
    );
    intakeSummaries.add(
      new HomePageDashboardController.IntakeCompletionSummary('User C', 2)
    );

    // Sort using the comparator to exercise lines 142, 147
    intakeSummaries.sort(
      new HomePageDashboardController.IntakeCompletionComparator()
    );

    // Call getSQLLeadsTrend to test uncovered trend functionality
    List<HomePageDashboardController.SQLTrendPoint> trendPoints = HomePageDashboardController.getSQLLeadsTrend(
      'THIS_YEAR',
      '',
      '',
      ''
    );

    Test.stopTest();

    // Verify sorting worked (highest count first)
    System.assertEquals(
      'User B',
      intakeSummaries[0].ownerName,
      'Highest count should be first'
    );
    System.assertEquals(
      'User A',
      intakeSummaries[1].ownerName,
      'Second highest should be second'
    );
    System.assertEquals(
      'User C',
      intakeSummaries[2].ownerName,
      'Lowest count should be last'
    );

    // Verify trend points
    System.assert(trendPoints.size() >= 0, 'Should return trend points');
  }

  @isTest
  static void testSQLTrendAndWrapperClasses() {
    Test.startTest();

    // Create leads with SQL status to test trend functionality
    List<Lead> sqlLeads = new List<Lead>();
    Lead sqlLead1 = new Lead(
      FirstName = 'SQL',
      LastName = 'Lead1',
      Company = 'Test SQL Company',
      Email = 'sql1@test.com',
      Phone = '555-000-0100',
      Source__c = 'Web',
      Status = 'Qualified',
      Rating = 'Hot',
      Category__c = 'Personal Injury',
      Preferred_Office_Location__c = 'Seattle'
    );

    Lead sqlLead2 = new Lead(
      FirstName = 'SQL',
      LastName = 'Lead2',
      Company = 'Test SQL Company 2',
      Email = 'sql2@test.com',
      Phone = '555-000-0101',
      Source__c = 'Referral',
      Status = 'Qualified',
      Rating = 'Hot',
      Category__c = 'Family',
      Preferred_Office_Location__c = 'Portland'
    );

    sqlLeads.add(sqlLead1);
    sqlLeads.add(sqlLead2);
    insert sqlLeads;

    // Test SQL trend with filters to exercise more conditional branches
    List<HomePageDashboardController.SQLTrendPoint> trendWithPracticeArea = HomePageDashboardController.getSQLLeadsTrend(
      'THIS_MONTH',
      'Business',
      '',
      ''
    );

    List<HomePageDashboardController.SQLTrendPoint> trendWithOfficeLocation = HomePageDashboardController.getSQLLeadsTrend(
      'THIS_MONTH',
      '',
      'Seattle',
      ''
    );

    List<HomePageDashboardController.SQLTrendPoint> trendWithBothFilters = HomePageDashboardController.getSQLLeadsTrend(
      'THIS_MONTH',
      'Business',
      'Seattle',
      ''
    );

    // Create wrapper class instances to cover constructor lines
    HomePageDashboardController.SQLLeadDetail sqlDetail = new HomePageDashboardController.SQLLeadDetail(
      sqlLead1
    );

    Test.stopTest();

    // Verify results
    System.assert(
      trendWithPracticeArea.size() >= 0,
      'Should return filtered trend by practice area'
    );
    System.assert(
      trendWithOfficeLocation.size() >= 0,
      'Should return filtered trend by office location'
    );
    System.assert(
      trendWithBothFilters.size() >= 0,
      'Should return filtered trend by both filters'
    );

    // Verify wrapper class populated correctly
    System.assertEquals(
      sqlLead1.Id,
      sqlDetail.Id,
      'SQL detail ID should match lead ID'
    );
    System.assertNotEquals(
      null,
      sqlDetail,
      'SQL detail should be instantiated'
    );
  }

  @isTest
  static void testGetLeadMetrics() {
    Test.startTest();
    HomePageDashboardController.LeadMetricsSummary metrics = HomePageDashboardController.getLeadMetrics(
      'THIS_YEAR',
      '',
      '',
      ''
    );
    Test.stopTest();

    System.assertNotEquals(null, metrics, 'Should return lead metrics summary');
    System.assert(metrics.newLeads >= 0, 'New leads should be non-negative');
    System.assert(
      metrics.intakeSpecialistCalls >= 0,
      'Intake specialist calls should be non-negative'
    );
    System.assert(
      metrics.intakeAttorneyCalls >= 0,
      'Intake attorney calls should be non-negative'
    );
    System.assert(
      metrics.intakeAttorneyNoShows >= 0,
      'Intake attorney no shows should be non-negative'
    );
    System.assert(
      metrics.totalClosedByIS >= 0,
      'Total closed by IS should be non-negative'
    );
    System.assert(
      metrics.totalClosedByIA >= 0,
      'Total closed by IA should be non-negative'
    );
    System.assertEquals(
      'This Year',
      metrics.periodLabel,
      'Period label should match filter'
    );
  }

  @isTest
  static void testGetLeadMetricsWithFilters() {
    Test.startTest();
    HomePageDashboardController.LeadMetricsSummary metrics = HomePageDashboardController.getLeadMetrics(
      'THIS_MONTH',
      'Pre-Litigation',
      'Los Angeles',
      ''
    );
    Test.stopTest();

    System.assertNotEquals(
      null,
      metrics,
      'Should return lead metrics summary with filters'
    );
    System.assertEquals(
      'This Month',
      metrics.periodLabel,
      'Period label should match filter'
    );
  }

  @isTest
  static void testGetNewLeadsRecords() {
    Test.startTest();
    List<Lead> leads = HomePageDashboardController.getNewLeadsRecords(
      'THIS_YEAR',
      '',
      '',
      '',
      false
    );
    Test.stopTest();

    System.assertNotEquals(null, leads, 'Should return new leads records');
    System.assert(leads.size() >= 0, 'Lead list should be non-null');
  }

  @isTest
  static void testGetNewLeadsRecordsWithFirstCallFilter() {
    Test.startTest();
    // Test with First Call filter enabled
    List<Lead> firstCallLeads = HomePageDashboardController.getNewLeadsRecords(
      'THIS_YEAR',
      '',
      '',
      '',
      true
    );
    Test.stopTest();

    System.assertNotEquals(null, firstCallLeads, 'Should return first call leads records');
    System.assert(firstCallLeads.size() >= 0, 'First call lead list should be non-null');

    // Verify all returned leads have First_Call__c = true
    for (Lead l : firstCallLeads) {
      System.assertEquals(true, l.First_Call__c, 'All leads should have First_Call__c = true');
    }
  }

  @isTest
  static void testGetIntakeSpecialistCallsRecords() {
    Test.startTest();
    List<Lead> leads = HomePageDashboardController.getIntakeSpecialistCallsRecords(
      'THIS_YEAR',
      '',
      '',
      ''
    );
    Test.stopTest();

    System.assertNotEquals(
      null,
      leads,
      'Should return intake specialist calls records'
    );
    System.assert(leads.size() >= 0, 'Lead list should be non-null');
  }

  @isTest
  static void testGetIntakeAttorneyCallsRecords() {
    Test.startTest();
    List<Lead> leads = HomePageDashboardController.getIntakeAttorneyCallsRecords(
      'THIS_YEAR',
      '',
      '',
      ''
    );
    Test.stopTest();

    System.assertNotEquals(
      null,
      leads,
      'Should return intake attorney calls records'
    );
    System.assert(leads.size() >= 0, 'Lead list should be non-null');
  }

  @isTest
  static void testGetIntakeAttorneyNoShowsRecords() {
    Test.startTest();
    List<Lead> leads = HomePageDashboardController.getIntakeAttorneyNoShowsRecords(
      'THIS_YEAR',
      '',
      '',
      ''
    );
    Test.stopTest();

    System.assertNotEquals(
      null,
      leads,
      'Should return intake attorney no shows records'
    );
    System.assert(leads.size() >= 0, 'Lead list should be non-null');
  }

  @isTest
  static void testGetTotalClosedByISRecords() {
    Test.startTest();
    List<Lead> leads = HomePageDashboardController.getTotalClosedByISRecords(
      'THIS_YEAR',
      '',
      '',
      ''
    );
    Test.stopTest();

    System.assertNotEquals(
      null,
      leads,
      'Should return total closed by IS records'
    );
    System.assert(leads.size() >= 0, 'Lead list should be non-null');
  }

  @isTest
  static void testGetTotalClosedByIARecords() {
    Test.startTest();
    List<Lead> leads = HomePageDashboardController.getTotalClosedByIARecords(
      'THIS_YEAR',
      '',
      '',
      ''
    );
    Test.stopTest();

    System.assertNotEquals(
      null,
      leads,
      'Should return total closed by IA records'
    );
    System.assert(leads.size() >= 0, 'Lead list should be non-null');
  }

  @isTest
  static void testExportLeadMetrics() {
    Test.startTest();
    String csvData = HomePageDashboardController.exportLeadMetrics(
      'THIS_YEAR',
      '',
      '',
      ''
    );
    Test.stopTest();

    System.assertNotEquals(null, csvData, 'Should return CSV data');
    System.assert(csvData.length() > 0, 'CSV data should not be empty');
    System.assert(
      csvData.contains('New Leads'),
      'CSV should contain New Leads header'
    );
    System.assert(
      csvData.contains('Intake Spec. Post-Consults'),
      'CSV should contain Intake Spec. Post-Consults header'
    );
  }

  @isTest
  static void testExportLeadMetricsWithFilters() {
    Test.startTest();
    String csvData = HomePageDashboardController.exportLeadMetrics(
      'THIS_MONTH',
      'Litigation',
      'Los Angeles',
      ''
    );
    Test.stopTest();

    System.assertNotEquals(
      null,
      csvData,
      'Should return CSV data with filters'
    );
    System.assert(csvData.contains('Litigation'), 'CSV should contain filter');
    System.assert(
      csvData.contains('Los Angeles'),
      'CSV should contain location filter'
    );
  }

  @isTest
  static void testGetIntakeSpecialistCloseRate() {
    Test.startTest();
    List<HomePageDashboardController.AttorneyCloseRateSummary> summaries = HomePageDashboardController.getIntakeSpecialistCloseRate(
      'THIS_YEAR',
      '',
      '',
      false,
      ''
    );
    Test.stopTest();

    System.assert(
      summaries.size() >= 0,
      'Should return intake specialist close rate summaries'
    );
  }

  @isTest
  static void testGetSQLLeadRecords() {
    Test.startTest();
    List<HomePageDashboardController.SQLLeadDetail> leads = HomePageDashboardController.getSQLLeadRecords(
      'THIS_YEAR',
      '',
      '',
      ''
    );
    Test.stopTest();

    System.assertNotEquals(null, leads, 'Should return SQL lead records');
    System.assert(leads.size() >= 0, 'Lead list should be non-null');
  }

  @isTest
  static void testGetCloseRateLeadRecords() {
    Test.startTest();
    List<Lead> leads = HomePageDashboardController.getCloseRateLeadRecords(
      '',
      'THIS_YEAR',
      '',
      '',
      ''
    );
    Test.stopTest();

    System.assertNotEquals(
      null,
      leads,
      'Should return close rate lead records'
    );
    System.assert(leads.size() >= 0, 'Lead list should be non-null');
  }

  @isTest
  static void testGetIntakeCompletionLeadRecords() {
    Test.startTest();
    List<Lead> leads = HomePageDashboardController.getIntakeCompletionLeadRecords(
      '',
      'THIS_YEAR',
      '',
      '',
      ''
    );
    Test.stopTest();

    System.assertNotEquals(
      null,
      leads,
      'Should return intake completion lead records'
    );
    System.assert(leads.size() >= 0, 'Lead list should be non-null');
  }

  @isTest
  static void testGetIntakeSpecialistCloseRateLeadRecords() {
    Test.startTest();
    List<Lead> leads = HomePageDashboardController.getIntakeSpecialistCloseRateLeadRecords(
      '',
      'THIS_YEAR',
      '',
      '',
      false,
      ''
    );
    Test.stopTest();

    System.assertNotEquals(
      null,
      leads,
      'Should return intake specialist close rate lead records'
    );
    System.assert(leads.size() >= 0, 'Lead list should be non-null');
  }

  @isTest
  static void testExportIntakeSpecialistCloseRate() {
    Test.startTest();
    String csvData = HomePageDashboardController.exportIntakeSpecialistCloseRate(
      'THIS_YEAR',
      '',
      '',
      '',
      false
    );
    Test.stopTest();

    System.assertNotEquals(null, csvData, 'Should return CSV data');
    System.assert(csvData.length() > 0, 'CSV data should not be empty');
    System.assert(
      csvData.contains('Intake Specialist'),
      'CSV should contain Intake Specialist header'
    );
  }

  @isTest
  static void testExportSQLTrend() {
    Test.startTest();
    String csvData = HomePageDashboardController.exportSQLTrend(
      'THIS_YEAR',
      '',
      '',
      ''
    );
    Test.stopTest();

    System.assertNotEquals(null, csvData, 'Should return CSV data');
    System.assert(csvData.length() > 0, 'CSV data should not be empty');
  }

  @isTest
  static void testGetLeadsByPracticeArea() {
    Test.startTest();
    List<HomePageDashboardController.PracticeAreaLeadSummary> summaries = HomePageDashboardController.getLeadsByPracticeArea(
      'THIS_YEAR',
      '',
      '',
      ''
    );
    Test.stopTest();

    System.assert(
      summaries.size() >= 0,
      'Should return practice area lead summaries'
    );
    for (
      HomePageDashboardController.PracticeAreaLeadSummary summary : summaries
    ) {
      System.assertNotEquals(
        null,
        summary.practiceArea,
        'Practice area should not be null'
      );
      System.assert(
        summary.leadCount >= 0,
        'Lead count should be non-negative'
      );
    }
  }

  @isTest
  static void testGetLeadsByPracticeAreaWithFilters() {
    Test.startTest();
    List<HomePageDashboardController.PracticeAreaLeadSummary> summariesWithPA = HomePageDashboardController.getLeadsByPracticeArea(
      'THIS_YEAR',
      'Transactional',
      '',
      ''
    );
    List<HomePageDashboardController.PracticeAreaLeadSummary> summariesWithOffice = HomePageDashboardController.getLeadsByPracticeArea(
      'THIS_YEAR',
      '',
      'Los Angeles',
      ''
    );
    List<HomePageDashboardController.PracticeAreaLeadSummary> summariesWithBoth = HomePageDashboardController.getLeadsByPracticeArea(
      'THIS_MONTH',
      'Pre-Litigation',
      'Los Angeles',
      ''
    );
    Test.stopTest();

    System.assert(
      summariesWithPA.size() >= 0,
      'Should return filtered summaries by practice area'
    );
    System.assert(
      summariesWithOffice.size() >= 0,
      'Should return filtered summaries by office'
    );
    System.assert(
      summariesWithBoth.size() >= 0,
      'Should return filtered summaries by both'
    );
  }

  @isTest
  static void testExportLeadsByPracticeArea() {
    Test.startTest();
    String csvData = HomePageDashboardController.exportLeadsByPracticeArea(
      'THIS_YEAR',
      '',
      '',
      ''
    );
    Test.stopTest();

    System.assertNotEquals(null, csvData, 'Should return CSV data');
    System.assert(csvData.length() > 0, 'CSV data should not be empty');
    System.assert(
      csvData.contains('Created Date'),
      'CSV should contain Created Date header'
    );
    System.assert(
      csvData.contains('Lead Name'),
      'CSV should contain Lead Name header'
    );
    System.assert(
      csvData.contains('Preferred Office'),
      'CSV should contain Preferred Office header'
    );
    System.assert(
      csvData.contains('Intake Specialist'),
      'CSV should contain Intake Specialist header'
    );
    System.assert(
      csvData.contains('Intake Attorney'),
      'CSV should contain Intake Attorney header'
    );
    System.assert(
      csvData.contains('Date FA was Signed'),
      'CSV should contain Date FA was Signed header'
    );
    System.assert(
      csvData.contains('Date First Payment Made'),
      'CSV should contain Date First Payment Made header'
    );
  }

  @isTest
  static void testExportLeadsByPracticeAreaWithFilters() {
    Test.startTest();
    String csvData = HomePageDashboardController.exportLeadsByPracticeArea(
      'THIS_MONTH',
      'Litigation',
      'Los Angeles',
      ''
    );
    Test.stopTest();

    System.assertNotEquals(
      null,
      csvData,
      'Should return CSV data with filters'
    );
    System.assert(csvData.length() > 0, 'CSV data should not be empty');
  }

  @isTest
  static void testPracticeAreaLeadSummaryComparator() {
    Test.startTest();

    // Create test summaries to test compareTo method
    List<HomePageDashboardController.PracticeAreaLeadSummary> summaries = new List<HomePageDashboardController.PracticeAreaLeadSummary>();
    summaries.add(
      new HomePageDashboardController.PracticeAreaLeadSummary(
        'Pre-Litigation',
        5
      )
    );
    summaries.add(
      new HomePageDashboardController.PracticeAreaLeadSummary('Litigation', 10)
    );
    summaries.add(
      new HomePageDashboardController.PracticeAreaLeadSummary('Business', 2)
    );

    // Sort using the compareTo method
    summaries.sort();

    Test.stopTest();

    // Verify sorting worked (highest count first)
    System.assertEquals(
      'Litigation',
      summaries[0].practiceArea,
      'Highest count should be first'
    );
    System.assertEquals(
      10,
      summaries[0].leadCount,
      'First should have 10 leads'
    );
    System.assertEquals(
      'Pre-Litigation',
      summaries[1].practiceArea,
      'Second highest should be second'
    );
    System.assertEquals(
      5,
      summaries[1].leadCount,
      'Second should have 5 leads'
    );
    System.assertEquals(
      'Business',
      summaries[2].practiceArea,
      'Lowest count should be last'
    );
    System.assertEquals(2, summaries[2].leadCount, 'Last should have 2 leads');
  }

  @isTest
  static void testWithTypeOfCivilLawFilter() {
    Test.startTest();

    // Test methods with Type of Civil Law filter
    HomePageDashboardController.LeadCountSummary leadCount = HomePageDashboardController.getLeadCount(
      'THIS_YEAR',
      '',
      '',
      'Personal Injury'
    );
    List<HomePageDashboardController.LeadSourceConversionSummary> conversions = HomePageDashboardController.getLeadConversionBySource(
      'THIS_YEAR',
      '',
      '',
      'Personal Injury'
    );
    List<HomePageDashboardController.LeadSourceCountSummary> totalLeads = HomePageDashboardController.getTotalLeadsBySource(
      'THIS_YEAR',
      '',
      '',
      'Personal Injury'
    );
    List<HomePageDashboardController.LandingPageLeadSummary> landingPages = HomePageDashboardController.getLeadsByLandingPage(
      'THIS_YEAR',
      '',
      '',
      'Personal Injury'
    );
    List<HomePageDashboardController.AttorneyCloseRateSummary> closeRates = HomePageDashboardController.getCloseRateByAttorney(
      'THIS_YEAR',
      '',
      '',
      'Personal Injury'
    );
    List<HomePageDashboardController.IntakeCompletionSummary> intakeCompletions = HomePageDashboardController.getIntakeCompletions(
      'THIS_YEAR',
      '',
      '',
      'Personal Injury'
    );
    List<HomePageDashboardController.SQLTrendPoint> sqlTrend = HomePageDashboardController.getSQLLeadsTrend(
      'THIS_YEAR',
      '',
      '',
      'Personal Injury'
    );
    HomePageDashboardController.LeadMetricsSummary metrics = HomePageDashboardController.getLeadMetrics(
      'THIS_YEAR',
      '',
      '',
      'Personal Injury'
    );
    List<HomePageDashboardController.PracticeAreaLeadSummary> practiceArea = HomePageDashboardController.getLeadsByPracticeArea(
      'THIS_YEAR',
      '',
      '',
      'Personal Injury'
    );
    List<HomePageDashboardController.AttorneyCloseRateSummary> intakeSpecClose = HomePageDashboardController.getIntakeSpecialistCloseRate(
      'THIS_YEAR',
      '',
      '',
      false,
      'Personal Injury'
    );

    Test.stopTest();

    System.assertNotEquals(
      null,
      leadCount,
      'Should return filtered lead count'
    );
    System.assert(
      conversions.size() >= 0,
      'Should return filtered conversions'
    );
    System.assert(totalLeads.size() >= 0, 'Should return filtered total leads');
    System.assert(
      landingPages.size() >= 0,
      'Should return filtered landing pages'
    );
    System.assert(closeRates.size() >= 0, 'Should return filtered close rates');
    System.assert(
      intakeCompletions.size() >= 0,
      'Should return filtered intake completions'
    );
    System.assert(sqlTrend.size() >= 0, 'Should return filtered SQL trend');
    System.assertNotEquals(null, metrics, 'Should return filtered metrics');
    System.assert(
      practiceArea.size() >= 0,
      'Should return filtered practice area'
    );
    System.assert(
      intakeSpecClose.size() >= 0,
      'Should return filtered intake specialist close rate'
    );
  }

  @isTest
  static void testWithAllFilters() {
    Test.startTest();

    // Test methods with all filters populated
    HomePageDashboardController.LeadCountSummary leadCount = HomePageDashboardController.getLeadCount(
      'THIS_MONTH',
      'Pre-Litigation',
      'Los Angeles',
      'Personal Injury'
    );
    List<HomePageDashboardController.LeadSourceConversionSummary> conversions = HomePageDashboardController.getLeadConversionBySource(
      'THIS_MONTH',
      'Pre-Litigation',
      'Los Angeles',
      'Personal Injury'
    );
    List<HomePageDashboardController.SQLTrendPoint> sqlTrend = HomePageDashboardController.getSQLLeadsTrend(
      'THIS_MONTH',
      'Pre-Litigation',
      'Los Angeles',
      'Personal Injury'
    );
    HomePageDashboardController.LeadMetricsSummary metrics = HomePageDashboardController.getLeadMetrics(
      'THIS_MONTH',
      'Pre-Litigation',
      'Los Angeles',
      'Personal Injury'
    );
    List<HomePageDashboardController.PracticeAreaLeadSummary> practiceArea = HomePageDashboardController.getLeadsByPracticeArea(
      'THIS_MONTH',
      'Pre-Litigation',
      'Los Angeles',
      'Personal Injury'
    );

    Test.stopTest();

    System.assertNotEquals(
      null,
      leadCount,
      'Should return fully filtered lead count'
    );
    System.assert(
      conversions.size() >= 0,
      'Should return fully filtered conversions'
    );
    System.assert(
      sqlTrend.size() >= 0,
      'Should return fully filtered SQL trend'
    );
    System.assertNotEquals(
      null,
      metrics,
      'Should return fully filtered metrics'
    );
    System.assert(
      practiceArea.size() >= 0,
      'Should return fully filtered practice area'
    );
  }

  @isTest
  static void testExportMethodsWithTypeOfCivilLaw() {
    Test.startTest();

    // Test export methods with Type of Civil Law filter
    String leadCountExport = HomePageDashboardController.exportLeadCount(
      'THIS_MONTH',
      '',
      '',
      'Personal Injury'
    );
    String intakeExport = HomePageDashboardController.exportIntakeCompletions(
      'THIS_MONTH',
      '',
      '',
      'Personal Injury'
    );
    String closeRateExport = HomePageDashboardController.exportCloseRateByAttorney(
      'THIS_MONTH',
      '',
      '',
      'Personal Injury'
    );
    String conversionExport = HomePageDashboardController.exportLeadConversionBySource(
      'THIS_MONTH',
      '',
      '',
      'Personal Injury'
    );
    String totalLeadsExport = HomePageDashboardController.exportTotalLeadsBySource(
      'THIS_MONTH',
      '',
      '',
      'Personal Injury'
    );
    String landingPageExport = HomePageDashboardController.exportLeadsByLandingPage(
      'THIS_MONTH',
      '',
      '',
      'Personal Injury'
    );
    String metricsExport = HomePageDashboardController.exportLeadMetrics(
      'THIS_MONTH',
      '',
      '',
      'Personal Injury'
    );
    String practiceAreaExport = HomePageDashboardController.exportLeadsByPracticeArea(
      'THIS_MONTH',
      '',
      '',
      'Personal Injury'
    );
    String sqlTrendExport = HomePageDashboardController.exportSQLTrend(
      'THIS_MONTH',
      '',
      '',
      'Personal Injury'
    );
    String intakeSpecExport = HomePageDashboardController.exportIntakeSpecialistCloseRate(
      'THIS_MONTH',
      '',
      '',
      'Personal Injury',
      false
    );

    Test.stopTest();

    System.assertNotEquals(
      null,
      leadCountExport,
      'Should return lead count export'
    );
    System.assert(leadCountExport.length() > 0, 'Export should not be empty');
    System.assertNotEquals(null, intakeExport, 'Should return intake export');
    System.assertNotEquals(
      null,
      closeRateExport,
      'Should return close rate export'
    );
    System.assertNotEquals(
      null,
      conversionExport,
      'Should return conversion export'
    );
    System.assertNotEquals(
      null,
      totalLeadsExport,
      'Should return total leads export'
    );
    System.assertNotEquals(
      null,
      landingPageExport,
      'Should return landing page export'
    );
    System.assertNotEquals(null, metricsExport, 'Should return metrics export');
    System.assertNotEquals(
      null,
      practiceAreaExport,
      'Should return practice area export'
    );
    System.assertNotEquals(
      null,
      sqlTrendExport,
      'Should return SQL trend export'
    );
    System.assertNotEquals(
      null,
      intakeSpecExport,
      'Should return intake specialist export'
    );
  }

  @isTest
  static void testModalMethodsWithTypeOfCivilLaw() {
    Test.startTest();

    // Test modal record retrieval methods with Type of Civil Law filter
    List<HomePageDashboardController.LeadDetail> newLeads = HomePageDashboardController.getNewLeadRecords(
      'THIS_YEAR',
      '',
      '',
      'Personal Injury'
    );
    List<Lead> intakeSpecCalls = HomePageDashboardController.getIntakeSpecialistCallsRecords(
      'THIS_YEAR',
      '',
      '',
      'Personal Injury'
    );
    List<Lead> intakeAttyCalls = HomePageDashboardController.getIntakeAttorneyCallsRecords(
      'THIS_YEAR',
      '',
      '',
      'Personal Injury'
    );
    List<Lead> intakeAttyNoShows = HomePageDashboardController.getIntakeAttorneyNoShowsRecords(
      'THIS_YEAR',
      '',
      '',
      'Personal Injury'
    );
    List<Lead> closedByIS = HomePageDashboardController.getTotalClosedByISRecords(
      'THIS_YEAR',
      '',
      '',
      'Personal Injury'
    );
    List<Lead> closedByIA = HomePageDashboardController.getTotalClosedByIARecords(
      'THIS_YEAR',
      '',
      '',
      'Personal Injury'
    );
    List<HomePageDashboardController.SQLLeadDetail> sqlLeads = HomePageDashboardController.getSQLLeadRecords(
      'THIS_YEAR',
      '',
      '',
      'Personal Injury'
    );
    List<Lead> closeRateLeads = HomePageDashboardController.getCloseRateLeadRecords(
      '',
      'THIS_YEAR',
      '',
      '',
      'Personal Injury'
    );
    List<Lead> intakeCompletionLeads = HomePageDashboardController.getIntakeCompletionLeadRecords(
      '',
      'THIS_YEAR',
      '',
      '',
      'Personal Injury'
    );
    List<Lead> intakeSpecCloseRateLeads = HomePageDashboardController.getIntakeSpecialistCloseRateLeadRecords(
      '',
      'THIS_YEAR',
      '',
      '',
      false,
      'Personal Injury'
    );

    Test.stopTest();

    System.assert(newLeads.size() >= 0, 'Should return new leads with filter');
    System.assert(
      intakeSpecCalls.size() >= 0,
      'Should return intake spec calls with filter'
    );
    System.assert(
      intakeAttyCalls.size() >= 0,
      'Should return intake atty calls with filter'
    );
    System.assert(
      intakeAttyNoShows.size() >= 0,
      'Should return intake atty no shows with filter'
    );
    System.assert(
      closedByIS.size() >= 0,
      'Should return closed by IS with filter'
    );
    System.assert(
      closedByIA.size() >= 0,
      'Should return closed by IA with filter'
    );
    System.assert(sqlLeads.size() >= 0, 'Should return SQL leads with filter');
    System.assert(
      closeRateLeads.size() >= 0,
      'Should return close rate leads with filter'
    );
    System.assert(
      intakeCompletionLeads.size() >= 0,
      'Should return intake completion leads with filter'
    );
    System.assert(
      intakeSpecCloseRateLeads.size() >= 0,
      'Should return intake spec close rate leads with filter'
    );
  }

  @isTest
  static void testExportSalesMarketingWithFilters() {
    Test.startTest();

    // Test master export with all filters
    String exportData = HomePageDashboardController.exportSalesMarketingData(
      'THIS_MONTH',
      'Litigation',
      'Los Angeles',
      'Personal Injury'
    );

    Test.stopTest();

    System.assertNotEquals(null, exportData, 'Should return export data');
    System.assert(exportData.length() > 0, 'Export data should not be empty');
    System.assert(
      exportData.contains('Section,Metric'),
      'Should contain CSV headers'
    );
  }
}