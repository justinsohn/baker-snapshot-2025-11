@IsTest
private class LeadSourceParserTest {
  @IsTest
  static void testBlankDefaults() {
    Lead testLead = new Lead(LastName = 'Blank', Company = 'Acme');

    insert testLead;

    Lead insertedLead = [SELECT Source__c FROM Lead WHERE Id = :testLead.Id];
    System.assertEquals(
      'No Lead Source',
      insertedLead.Source__c,
      'Blank details should default to No Lead Source'
    );
  }

  @IsTest
  static void testReferralStop() {
    Lead testLead = new Lead(
      LastName = 'Referral',
      Company = 'Acme',
      Lead_Source_Details__c = 'Prefix Source:safe.menlosecurity.comReferral Something'
    );

    insert testLead;

    Lead insertedLead = [SELECT Source__c FROM Lead WHERE Id = :testLead.Id];
    System.assertEquals('safe.menlosecurity.com', insertedLead.Source__c);
  }

  @IsTest
  static void testCampaignStopWithSpacing() {
    Lead testLead = new Lead(
      LastName = 'Campaign',
      Company = 'Acme',
      Lead_Source_Details__c = 'Source: Google AdscpcCampaign:Details'
    );

    insert testLead;

    Lead insertedLead = [SELECT Source__c FROM Lead WHERE Id = :testLead.Id];
    System.assertEquals('Google Ads', insertedLead.Source__c);
  }

  @IsTest
  static void testNoColonNoSpace() {
    Lead testLead = new Lead(
      LastName = 'NoColon',
      Company = 'Acme',
      Lead_Source_Details__c = 'Something SourceGoogle OrganicOrganicCampaign More text'
    );

    insert testLead;

    Lead insertedLead = [SELECT Source__c FROM Lead WHERE Id = :testLead.Id];
    System.assertEquals('Google Organic', insertedLead.Source__c);
  }

  @IsTest
  static void testPageIdStop() {
    Lead testLead = new Lead(
      LastName = 'Page',
      Company = 'Acme',
      Lead_Source_Details__c = 'Source: value   PageId: 123'
    );

    insert testLead;

    Lead insertedLead = [SELECT Source__c FROM Lead WHERE Id = :testLead.Id];
    System.assertEquals('value', insertedLead.Source__c);
  }

  @IsTest
  static void testNoEndTokenTakesRest() {
    Lead testLead = new Lead(
      LastName = 'NoEnd',
      Company = 'Acme',
      Lead_Source_Details__c = 'Source:Zebra Ads'
    );

    insert testLead;

    Lead insertedLead = [SELECT Source__c FROM Lead WHERE Id = :testLead.Id];
    System.assertEquals('Zebra Ads', insertedLead.Source__c);
  }

  @IsTest
  static void testNoSourceReturnsEmpty() {
    Lead testLead = new Lead(
      LastName = 'NoSource',
      Company = 'Acme',
      Lead_Source_Details__c = 'Referral without keyword'
    );

    insert testLead;

    Lead insertedLead = [SELECT Source__c FROM Lead WHERE Id = :testLead.Id];
    System.assertEquals(
      null,
      insertedLead.Source__c,
      'Missing Source token should leave Source__c empty'
    );
  }

  @IsTest
  static void testMixedCaseRobustness() {
    Lead testLead = new Lead(
      LastName = 'Mixed',
      Company = 'Acme',
      Lead_Source_Details__c = 'SoUrCe:  x   ReFeRrAl data'
    );

    insert testLead;

    Lead insertedLead = [SELECT Source__c FROM Lead WHERE Id = :testLead.Id];
    System.assertEquals('x', insertedLead.Source__c);
  }

  @IsTest
  static void testBulkInsert() {
    List<Lead> leadsToInsert = new List<Lead>();
    for (Integer i = 0; i < 200; i++) {
      leadsToInsert.add(
        new Lead(
          LastName = 'Bulk' + i,
          Company = 'Acme',
          Lead_Source_Details__c = 'Source: Value' + i + ' Referral'
        )
      );
    }

    Test.startTest();
    insert leadsToInsert;
    Test.stopTest();

    List<Lead> insertedLeads = [
      SELECT Source__c
      FROM Lead
      WHERE Id IN :leadsToInsert
    ];
    for (Lead insertedLead : insertedLeads) {
      System.assert(
        insertedLead.Source__c.startsWith('Value'),
        'Bulk insert should parse each lead'
      );
    }
  }

  @IsTest
  static void testUpdateOnlyOnChange() {
    Lead testLead = new Lead(
      LastName = 'Update',
      Company = 'Acme',
      Lead_Source_Details__c = 'Source: Original Referral'
    );

    insert testLead;

    Lead insertedLead = [
      SELECT Source__c, Lead_Source_Details__c
      FROM Lead
      WHERE Id = :testLead.Id
    ];
    System.assertEquals('Original', insertedLead.Source__c);

    insertedLead.Company = 'Updated Co';

    update insertedLead;

    Lead postUpdateLead = [SELECT Source__c FROM Lead WHERE Id = :testLead.Id];
    System.assertEquals(
      'Original',
      postUpdateLead.Source__c,
      'Updating unrelated fields should not change parsed value'
    );

    insertedLead.Lead_Source_Details__c = 'Source: New Referral';

    Test.startTest();
    update insertedLead;
    Test.stopTest();

    Lead changedLead = [SELECT Source__c FROM Lead WHERE Id = :testLead.Id];
    System.assertEquals(
      'New',
      changedLead.Source__c,
      'Changing details should reparse value'
    );
  }

  @IsTest
  static void testManualSourceOnInsertNotOverwritten() {
    Lead testLead = new Lead(
      LastName = 'ManualInsert',
      Company = 'Acme',
      Lead_Source_Details__c = 'Source: ShouldNotParse Referral',
      Source__c = 'Manually Provided'
    );

    insert testLead;

    Lead insertedLead = [SELECT Source__c FROM Lead WHERE Id = :testLead.Id];
    System.assertEquals(
      'Manually Provided',
      insertedLead.Source__c,
      'Trigger should respect manual value on insert'
    );
  }

  @IsTest
  static void testManualSourceOnUpdateNotOverwritten() {
    Lead testLead = new Lead(
      LastName = 'ManualUpdate',
      Company = 'Acme',
      Lead_Source_Details__c = 'Source: Auto Referral'
    );

    insert testLead;

    Lead insertedLead = [
      SELECT Source__c, Lead_Source_Details__c
      FROM Lead
      WHERE Id = :testLead.Id
    ];
    System.assertEquals(
      'Auto',
      insertedLead.Source__c,
      'Initial insert should parse value'
    );

    insertedLead.Source__c = 'Manual Override';

    update insertedLead;

    Lead manualLead = [
      SELECT Source__c, Lead_Source_Details__c
      FROM Lead
      WHERE Id = :testLead.Id
    ];
    System.assertEquals(
      'Manual Override',
      manualLead.Source__c,
      'Manual override should persist'
    );

    manualLead.Lead_Source_Details__c = 'Source: Should Not Change Referral';

    update manualLead;

    Lead finalLead = [SELECT Source__c FROM Lead WHERE Id = :testLead.Id];
    System.assertEquals(
      'Manual Override',
      finalLead.Source__c,
      'Manual value should remain after details change'
    );
  }

  @IsTest
  static void testDelayedDetailsPopulation() {
    Lead testLead = new Lead(LastName = 'Delayed', Company = 'Acme');

    insert testLead;

    Lead insertedLead = [
      SELECT Source__c, Lead_Source_Details__c
      FROM Lead
      WHERE Id = :testLead.Id
    ];
    System.assertEquals(
      'No Lead Source',
      insertedLead.Source__c,
      'Blank details should set default'
    );

    insertedLead.Lead_Source_Details__c = 'Source: Later Referral';

    update insertedLead;

    Lead updatedLead = [SELECT Source__c FROM Lead WHERE Id = :testLead.Id];
    System.assertEquals(
      'Later',
      updatedLead.Source__c,
      'First-time details population should parse value even after default'
    );
  }

  @IsTest
  static void testGoogleMyBusinessNormalization() {
    Lead testLead = new Lead(
      LastName = 'Business',
      Company = 'Acme',
      Lead_Source_Details__c = 'https://www.google.com/Source:Google My BusinesslocalCampaign:gbpPageId:'
    );

    insert testLead;

    Lead insertedLead = [SELECT Source__c FROM Lead WHERE Id = :testLead.Id];
    System.assertEquals('Google My Business', insertedLead.Source__c);
  }

  @IsTest
  static void testTrailingCpcRemoved() {
    Lead testLead = new Lead(
      LastName = 'Cpc',
      Company = 'Acme',
      Lead_Source_Details__c = 'Source: Paid Search cpcReferral'
    );

    insert testLead;

    Lead insertedLead = [SELECT Source__c FROM Lead WHERE Id = :testLead.Id];
    System.assertEquals('Paid Search', insertedLead.Source__c);
  }

  @IsTest
  static void testSearchCampaignTrimmed() {
    Lead testLead = new Lead(
      LastName = 'SearchCampaign',
      Company = 'Acme',
      Lead_Source_Details__c = 'https://www.google.com/Source:Google My BusinesssearchCampaign:PageId:'
    );

    insert testLead;

    Lead insertedLead = [SELECT Source__c FROM Lead WHERE Id = :testLead.Id];
    System.assertEquals('Google My Business', insertedLead.Source__c);
  }

  @IsTest
  static void testPoolCpcNormalization() {
    Lead testLead = new Lead(
      LastName = 'PoolCpc',
      Company = 'Acme',
      Lead_Source_Details__c = 'Source:Website PoolCPCCampaign:'
    );

    insert testLead;

    Lead insertedLead = [SELECT Source__c FROM Lead WHERE Id = :testLead.Id];
    System.assertEquals('Website', insertedLead.Source__c);
  }

  @IsTest
  static void testAdExtensionNormalization() {
    Lead testLead = new Lead(
      LastName = 'AdExtension',
      Company = 'Acme',
      Lead_Source_Details__c = 'Source:Google Ad ExtensioncpcCampaign:'
    );

    insert testLead;

    Lead insertedLead = [SELECT Source__c FROM Lead WHERE Id = :testLead.Id];
    System.assertEquals('Google Ad', insertedLead.Source__c);
  }

  @IsTest
  static void testEmptyParsedValueClearsSource() {
    Lead testLead = new Lead(
      LastName = 'EmptySource',
      Company = 'Acme',
      Lead_Source_Details__c = 'https://syndicatedsearch.goog/Source:Campaign:PageId:'
    );

    insert testLead;

    Lead insertedLead = [SELECT Source__c FROM Lead WHERE Id = :testLead.Id];
    System.assertEquals(
      'No Lead Source',
      insertedLead.Source__c,
      'Should fall back to No Lead Source when no value between Source and next token'
    );
  }

  @IsTest
  static void testReferralCampaignCutOff() {
    Lead testLead = new Lead(
      LastName = 'ReferralCampaign',
      Company = 'Acme',
      Lead_Source_Details__c = 'https://copilot.microsoft.com/Source:copilot.microsoft.comReferralCampaign:PageId:'
    );

    insert testLead;

    Lead insertedLead = [SELECT Source__c FROM Lead WHERE Id = :testLead.Id];
    System.assertEquals('copilot.microsoft.com', insertedLead.Source__c);
  }
}