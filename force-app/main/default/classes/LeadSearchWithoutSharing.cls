/**
 * @description Helper class to search leads without sharing restrictions for platform license users.
 * This class bypasses sharing rules to allow platform license users to search for leads
 * even when they don't have standard Lead object access.
 */
public without sharing class LeadSearchWithoutSharing {
    
    /**
     * @description Searches leads without sharing restrictions.
     * @param searchTerm The search term to look for in lead fields.
     * @return List<Lead> A list of matching leads with basic information.
     */
    public static List<Lead> searchLeads(String searchTerm) {
        if (String.isBlank(searchTerm) || searchTerm.length() < 2) {
            return new List<Lead>();
        }
        
        String searchPattern = '%' + searchTerm + '%';
        
        return [
            SELECT Id, FirstName, LastName, Email, Phone, Company, CreatedDate
            FROM Lead
            WHERE (FirstName LIKE :searchPattern
                OR LastName LIKE :searchPattern
                OR Email LIKE :searchPattern
                OR Phone LIKE :searchPattern)
            ORDER BY CreatedDate DESC
            LIMIT 50
        ];
    }
    
    /**
     * @description Validates that a Lead record exists with the given ID.
     * @param leadId The Lead ID to validate.
     * @return List<Lead> A list containing the Lead if it exists, empty if not.
     */
    public static List<Lead> validateLeadExists(Id leadId) {
        if (leadId == null) {
            return new List<Lead>();
        }
        
        return [
            SELECT Id
            FROM Lead
            WHERE Id = :leadId
            LIMIT 1
        ];
    }
    
    /**
     * @description Updates a Lead record's JSON field without sharing restrictions.
     * @param leadId The Lead ID to update.
     * @param jsonData The JSON data to store in the Lead record.
     */
    public static void updateLeadJson(Id leadId, String jsonData) {
        if (leadId == null) {
            return;
        }
        
        Lead leadToUpdate = new Lead(
            Id = leadId,
            Intake_Form_JSON__c = jsonData
        );
        
        update leadToUpdate;
    }
}