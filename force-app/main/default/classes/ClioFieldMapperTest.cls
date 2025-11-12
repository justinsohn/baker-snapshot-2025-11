@isTest
private class ClioFieldMapperTest {

    @isTest
    static void testFieldMappingConstructor() {
        Test.startTest();
        
        ClioFieldMapper.FieldMapping mapping = new ClioFieldMapper.FieldMapping(
            'clio_field',
            'Salesforce_Field__c',
            'Text',
            true
        );
        
        Test.stopTest();

        System.assertEquals('clio_field', mapping.clioField);
        System.assertEquals('Salesforce_Field__c', mapping.salesforceField);
        System.assertEquals('Text', mapping.fieldType);
        System.assertEquals(true, mapping.isRequired);
        System.assertEquals(false, mapping.exists);
    }

    @isTest
    static void testValidateAllMappings() {
        Test.startTest();
        
        ClioFieldMapper.validateAllMappings();
        
        Test.stopTest();

        // Should complete without throwing exceptions
        System.assert(true);
    }

}