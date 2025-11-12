trigger LeadSourceParseTrigger on Lead(before insert, before update) {
  if (LeadSourceParser.runOnce()) {
    return;
  }

  try {
    for (Lead leadRecord : Trigger.new) {
      Lead oldLead = Trigger.isInsert
        ? null
        : Trigger.oldMap.get(leadRecord.Id);

      if (Trigger.isInsert && String.isNotBlank(leadRecord.Source__c)) {
        continue;
      }

      if (!Trigger.isInsert && oldLead != null) {
        String oldParsed = LeadSourceParser.parse(
          oldLead.Lead_Source_Details__c
        );
        Boolean oldValueManagedByTrigger = oldLead.Source__c == oldParsed;

        if (!oldValueManagedByTrigger && String.isNotBlank(oldLead.Source__c)) {
          continue;
        }

        Boolean userUpdatedSource =
          String.isNotBlank(leadRecord.Source__c) &&
          leadRecord.Source__c != oldLead.Source__c;
        if (userUpdatedSource) {
          continue;
        }
      }

      Boolean detailsChanged =
        Trigger.isInsert ||
        (oldLead != null &&
        leadRecord.Lead_Source_Details__c != oldLead.Lead_Source_Details__c);

      if (!detailsChanged) {
        continue;
      }

      leadRecord.Source__c = LeadSourceParser.parse(
        leadRecord.Lead_Source_Details__c
      );
    }
  } finally {
    LeadSourceParser.release();
  }
}