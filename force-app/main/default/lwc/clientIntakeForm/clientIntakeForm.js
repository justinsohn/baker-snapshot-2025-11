import { LightningElement, track, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import saveIntakeRecord from '@salesforce/apex/ClientIntakeController.saveIntakeRecord';
import getFullIntakeRecord from '@salesforce/apex/ClientIntakeController.getFullIntakeRecord';
import createNewIntakeForLead from '@salesforce/apex/ClientIntakeController.createNewIntakeForLead';

export default class ClientIntakeForm extends LightningElement {
    @api recordId; // If editing existing intake
    @api leadId; // Parent Lead ID
    
    @track intakeRecord = {};
    @track selectedLegalMatterTypes = [];
    @track selectedCaseInvolvementTypes = [];
    @track selectedAbuseTypes = [];
    @track selectedSupportServices = [];
    @track selectedDamagesSought = [];
    @track selectedEPDocuments = [];
    @track selectedBusinessInclusions = [];
    @track selectedStatementContentTypes = [];
    @track selectedReputationEffects = [];
    @track selectedResponseActions = [];
    @track selectedConstructionDefects = [];
    @track selectedGCAssistanceTypes = [];
    @track selectedGCInvolvementTypes = [];
    @track selectedAdditionalContacts = []; // ADDED: for new multi-select
    
    @track progressValue = 0;
    @track progressPercentageText = '0% Complete';
    @track isFormLaunched = false;
    @track isLoading = false;
    @track currentSection = 1;
    @track totalSections = 15; // Including closing questions

    connectedCallback() {
        this.initializeRecord();
        if (this.recordId) {
            this.loadExistingRecord();
        } else if (this.leadId) {
            this.createNewIntake();
        }
    }

    initializeRecord() {
        // Initialize all fields with empty values
        this.intakeRecord = {
            Lead__c: this.leadId,
            // Section 1: General Information
            Preferred_Pronouns__c: '',
            Mailing_Address_Different__c: '',
            Can_Email_Follow_Up__c: '',
            Work_Phone_Custom__c: '',
            Can_Text_You__c: '',
            Preferred_Method_Communication__c: '',
            Preferred_Language__c: '',
            Date_Of_Birth__c: null,
            Occupation_Employer__c: '',
            How_Did_You_Hear__c: '',
            How_Hear_Advertisement_Specify__c: '',
            How_Hear_Referral_Specify__c: '',
            How_Hear_Social_Media_Specify__c: '',
            How_Hear_Other_Specify__c: '',
            Worked_With_Us_Before__c: '',
            Previous_Attorney_Office__c: '',
            Preferred_Office_Location__c: '',
            Require_Appointment_Accommodations__c: '',
            Appointment_Accommodations_Specify__c: '',
            Specific_Availability_Times_Days__c: '',
            Other_Parties_Involved__c: '',
            Legal_Matters_With_Parties_Before__c: '',
            Aware_Of_Conflicts__c: '',
            Represented_Other_Parties_In_Case__c: '',
            Spoken_With_Other_Attorneys__c: '',
            Prior_Attorney_Name_Firm__c: '',
            Reason_No_Hire_Prior_Attorney__c: '',
            Prior_Attorney_Cost_Specify__c: '',
            Prior_Attorney_Reason_Other_Specify__c: '',
            Currently_Represented__c: '',
            Reason_Seeking_New_Attorney__c: '',
            Legal_Matter_Type__c: '',
            Legal_Matter_Type_Other_Specify__c: '',
            Issue_Description__c: '',
            Desired_Outcome__c: '',
            
            // Section 2: Criminal Law
            CL_Charges_Allegations__c: '',
            CL_Charge_Classification__c: '',
            CL_Incident_Location_City_County__c: '',
            CL_Incident_Location_State__c: '',
            CL_Incident_Date__c: null,
            CL_Investigating_Agency__c: '',
            CL_Agency_Police_Specify__c: '',
            CL_Agency_Other_Specify__c: '',
            CL_Case_Filed__c: '',
            CL_Case_Number__c: '',
            CL_Court_Location__c: '',
            CL_Under_Investigation__c: '',
            CL_Case_Status__c: '',
            CL_Case_Status_Other_Specify__c: '',
            CL_In_Custody__c: '',
            CL_Needs_Bail_Bond_Help__c: '',
            CL_Case_Involvement_Types__c: '',
            CL_Case_Involvement_Other_Specify__c: '',
            
            // DUI/DWI
            CL_DUI_Pulled_Over_Reason__c: '',
            CL_DUI_Pulled_Over_Other_Specify__c: '',
            CL_DUI_Tests_Conducted__c: '',
            CL_DUI_Test_Results__c: '',
            CL_DUI_Prior_Convictions__c: '',
            CL_DUI_Prior_Convictions_Details__c: '',
            
            // Record Sealing
            CL_Charges_To_Seal__c: '',
            CL_Case_Dismissed_Acquitted__c: '',
            CL_Completed_Court_Conditions__c: '',
            
            // Domestic Violence
            DV_Physically_Harmed__c: '',
            DV_Recent_Incident_Date__c: null,
            DV_Recent_Incident_Location__c: '',
            DV_Recent_Incident_Description__c: '',
            DV_Violence_Occurred_Before__c: '',
            DV_Violence_Frequency__c: '',
            DV_Violence_Past_Or_Ongoing__c: '',
            DV_Ongoing_Violence_Situation__c: '',
            DV_Types_Of_Abuse__c: '',
            DV_Abuse_Type_Other_Specify__c: '',
            DV_Perpetrator_Identity__c: '',
            DV_Perpetrator_Identity_Other__c: '',
            DV_Relationship_To_Perpetrator__c: '',
            DV_Perpetrator_Family_Specify__c: '',
            DV_Rel_To_Perpetrator_Other_Specify__c: '',
            DV_Abuser_Lives_With_You__c: '',
            DV_Abuser_Contact_Frequency__c: '',
            DV_Have_Children__c: '',
            DV_Children_Witness_Abuse_Details__c: '',
            DV_Abuser_Threatened_Harm__c: '',
            DV_Abuser_Threat_Details__c: '',
            DV_Immediate_Danger__c: '',
            DV_Injured_From_Abuse__c: '',
            DV_Injury_Details_Medical_Attention__c: '',
            DV_Abuser_Threatened_Weapon__c: '',
            DV_Abuser_Weapon_Situation__c: '',
            DV_Firearms_Present__c: '',
            DV_Firearm_Types__c: '',
            DV_Contacted_Law_Enforcement__c: '',
            DV_Law_Enforcement_Outcome__c: '',
            DV_Sought_Protection_Order__c: '',
            DV_Protection_Order_Granted__c: '',
            DV_Current_Protection_Order__c: '',
            DV_Involved_In_Criminal_Case__c: '',
            DV_Criminal_Case_Details__c: '',
            DV_Receiving_Support_Services__c: '',
            DV_Support_Services_Other__c: '',
            DV_Safe_Place_To_Stay__c: '',
            DV_Need_Shelter_Assistance__c: '',
            DV_Speak_With_Attorney_Options__c: '',
            DV_Assistance_Filing_Protective_Order__c: '',
            
            // Section 3: Family Law
            FL_Currently_Married__c: '',
            FL_Marriage_Type__c: '',
            FL_Spouse_Children_Together__c: '',
            FL_Previously_Filed_Family_Case__c: '',
            FL_Marriage_Date__c: null,
            FL_Marriage_Location__c: '',
            FL_Seeking_Action__c: '',
            FL_Divorce_Property_Division__c: '',
            FL_Property_Division_Real_Estate__c: '',
            FL_Property_Division_Bank_Accounts__c: '',
            FL_Property_Division_Other_Assets__c: '',
            FL_Divorce_Contested_Status__c: '',
            FL_Children_Involved_Count__c: '',
            FL_Children_Details__c: '',
            FL_Existing_Custody_Orders__c: '',
            FL_Child_Safety_Concerns__c: '',
            
            // Section 4: Probate & Estate Planning
            PE_Deceased_Name__c: '',
            PE_Deceased_Date_Of_Death__c: null,
            PE_Deceased_Location_Of_Death__c: '',
            PE_PC_Relationship_To_Deceased__c: '',
            PE_PC_Relationship_Other_Specify__c: '',
            PE_Deceased_Residence_Location__c: '',
            PE_Deceased_Own_Real_Estate_CO__c: '',
            PE_Jurisdiction_In_Colorado__c: '',
            PE_Real_Estate_Deed_Names__c: '',
            PE_Estate_Value_Estimate__c: '',
            PE_Deceased_Marital_Status__c: '',
            PE_Probate_Estate_Opened__c: '',
            PE_Probate_Case_County__c: '',
            PE_Probate_Case_Number__c: '',
            PE_Personal_Representative_Name__c: '',
            PE_Personal_Rep_Appointment_Date__c: null,
            PE_Probate_Case_Stage__c: '',
            PE_Decedent_Asset_Types__c: '',
            PE_Decedent_Asset_Other_Specify__c: '',
            PE_Real_Estate_Addresses__c: '',
            PE_Other_Unlisted_Assets__c: '',
            PE_Decedent_Had_Children__c: '',
            PE_Decedent_Children_Minors__c: '',
            PE_Decedent_Parents_Living__c: '',
            PE_Decedent_Siblings_Living__c: '',
            EP_Plan_For_Whom__c: '',
            EP_Previous_Estate_Plan__c: '',
            EP_Documents_Needed__c: '',
            EP_Documents_Needed_Other_Specify__c: '',
            
            // Section 5: Real Estate
            RE_Assistance_Type__c: '',
            RE_Assistance_Type_Other_Specify__c: '',
            RE_Your_Role__c: '',
            RE_Property_Street__c: '',
            RE_Property_City__c: '',
            RE_Property_State__c: '',
            RE_Property_ZIP__c: '',
            RE_Property_Type__c: '',
            RE_Property_Under_Contract__c: '',
            RE_Working_With_Realtor__c: '',
            RE_Realtor_Info__c: '',
            RE_Purchase_Sale_Price__c: '',
            RE_Financing_Type__c: '',
            RE_Financing_Type_Other_Specify__c: '',
            RE_Closing_Date__c: null,
            RE_Lease_Type__c: '',
            RE_Lease_Start_Date__c: null,
            RE_Lease_End_Date__c: null,
            RE_Monthly_Rent__c: '',
            RE_Specific_Lease_Terms__c: '',
            RE_Specific_Lease_Terms_Specify__c: '',
            RE_Dispute_Nature__c: '',
            RE_Dispute_Nature_Other_Specify__c: '',
            RE_Dispute_Legal_Action_Taken__c: '',
            RE_Dispute_Legal_Action_Details__c: '',
            RE_Environmental_Zoning_Issues__c: '',
            RE_Env_Zoning_Issues_Details__c: '',
            RE_Property_In_HOA__c: '',
            RE_Access_To_HOA_Docs__c: '',
            
            // Section 6: Personal Injury
            PI_Incident_Description__c: '',
            PI_Incident_Date__c: null,
            PI_Incident_Time__c: '',
            PI_Incident_Location_Address__c: '',
            PI_Incident_Location_City_County_State__c: '',
            PI_Your_Role__c: '',
            PI_Your_Role_Other_Specify__c: '',
            PI_Injuries_Sustained__c: '',
            PI_Received_Medical_Treatment__c: '',
            PI_Medical_Treatment_Details__c: '',
            PI_Currently_Undergoing_Treatment__c: '',
            PI_Records_Medical_Expenses__c: '',
            PI_Incident_Witnesses__c: '',
            PI_Witness_Info__c: '',
            PI_Police_Report_Filed__c: '',
            PI_Police_Report_Details__c: '',
            PI_Has_Documentation__c: '',
            PI_Has_Insurance_Coverage__c: '',
            PI_Your_Insurance_Info__c: '',
            PI_Other_Party_Has_Insurance__c: '',
            PI_Other_Party_Insurance_Info__c: '',
            PI_Damages_Sought__c: '',
            PI_Damages_Sought_Other_Specify__c: '',
            
            // Section 7: Civil Litigation
            CLIT_Dispute_Nature__c: '',
            CLIT_Estimated_Damages_Value__c: '',
            CLIT_Claim_Basis__c: '',
            CLIT_Claim_Basis_Other_Specify__c: '',
            CLIT_Lawsuits_Filed__c: '',
            CLIT_Lawsuit_Details__c: '',
            CLIT_Plaintiff_Or_Defendant__c: '',
            
            // Section 8: Employment Law
            EMPL_Employment_Issue_Type__c: '',
            EMPL_Issue_Other_Specify__c: '',
            EMPL_Issue_Stage__c: '',
            EMPL_Desired_Outcome__c: '',
            EMPL_Desired_Outcome_Other_Specify__c: '',
            
            // Section 9: Landlord/Tenant
            LT_Role__c: '',
            LT_Property_Address__c: '',
            LT_Dispute_Nature__c: '',
            LT_Monthly_Rent_Amount__c: '',
            LT_Lease_Term_Type__c: '',
            LT_Legal_Action_Taken__c: '',
            LT_Legal_Action_Details__c: '',
            
            // Landlord specific fields
            LT_L_Owns_Property__c: '',
            LT_L_Actual_Owner_Name__c: '',
            LT_L_Actual_Owner_Contact__c: '',
            LT_L_Ownership_Duration_Years__c: '',
            LT_L_Number_Of_Units__c: '',
            LT_L_Multi_Unit_Count_Specify__c: '',
            LT_L_Property_Manager__c: '',
            LT_L_Property_Mgmt_Co_Name__c: '',
            LT_L_Has_Property_Insurance__c: '',
            LT_L_Property_Insurance_Provider__c: '',
            LT_L_Past_Property_Issues__c: '',
            LT_L_Past_Property_Issues_Specify__c: '',
            LT_L_Written_Lease_Agreement__c: '',
            LT_L_Lease_Term__c: '',
            LT_L_Lease_Term_Duration_Specify__c: '',
            LT_L_Lease_Term_Other_Specify__c: '',
            LT_L_Monthly_Rent_Amount__c: '',
            LT_L_Security_Deposit_Required__c: '',
            LT_L_Security_Deposit_Amount__c: '',
            LT_L_Rent_Includes__c: '',
            LT_L_Rent_Includes_Utilities_Specify__c: '',
            LT_L_Rent_Includes_Other_Specify__c: '',
            LT_L_Late_Rent_Grace_Period__c: '',
            LT_L_Late_Rent_Grace_Duration__c: '',
            LT_L_Consequence_Late_Rent__c: '',
            LT_L_Consequence_Late_Rent_Other__c: '',
            LT_L_Rent_Increase_Policy__c: '',
            LT_L_Rent_Increase_Conditions__c: '',
            LT_L_Maintenance_Responsibility__c: '',
            LT_L_Maintenance_Request_Method__c: '',
            LT_L_Emergency_Repair_Process__c: '',
            LT_L_Pest_Control_Procedure__c: '',
            LT_L_Pest_Control_Shared_Details__c: '',
            LT_L_Non_Emergency_Repair_Wait__c: '',
            LT_L_Regular_Inspections__c: '',
            LT_L_Regular_Inspections_Frequency__c: '',
            LT_L_Pets_Allowed__c: '',
            LT_L_Pet_Types_Allowed_Specify__c: '',
            LT_L_Noise_Conduct_Restrictions__c: '',
            LT_L_Noise_Conduct_Restrict_Specify__c: '',
            LT_L_Subletting_Guests_Allowed__c: '',
            LT_L_Subletting_Guests_Conditions__c: '',
            LT_L_Smoking_Allowed__c: '',
            LT_L_Move_In_Out_Procedures__c: '',
            LT_L_Tenant_Alterations_Allowed__c: '',
            LT_L_Allowed_Alteration_Types__c: '',
            LT_L_Tenant_Dispute_Handling__c: '',
            LT_L_Initiated_Evictions__c: '',
            LT_L_Eviction_Details__c: '',
            LT_L_Current_Legal_Disputes__c: '',
            LT_L_Current_Disputes_Details__c: '',
            LT_L_Past_Code_Violations__c: '',
            LT_L_Past_Code_Violations_Specify__c: '',
            LT_L_Lease_Renewal_Policy__c: '',
            LT_L_Lease_Renewal_Other_Specify__c: '',
            
            // Tenant specific fields
            LT_T_Has_Written_Lease__c: '',
            LT_T_Lease_Term__c: '',
            LT_T_Lease_Term_Duration_Specify__c: '',
            LT_T_Lease_Term_Other_Specify__c: '',
            LT_T_Monthly_Rent_Amount__c: '',
            LT_T_Rent_Includes_Utilities__c: '',
            LT_T_Rent_Inclusives_Specify__c: '',
            LT_T_Paid_Security_Deposit__c: '',
            LT_T_Security_Deposit_Amount__c: '',
            LT_T_Late_Fees_For_Rent__c: '',
            LT_T_Late_Fee_Terms_Specify__c: '',
            LT_T_Rent_Increases_During_Lease__c: '',
            LT_T_Rent_Increase_Terms_Specify__c: '',
            LT_T_Property_Condition_Move_In__c: '',
            LT_T_Requested_Repairs__c: '',
            LT_T_Repairs_Satisfactory__c: '',
            LT_T_Repair_Request_Process__c: '',
            LT_T_Repair_Request_Process_Specify__c: '',
            LT_T_Typical_Repair_Time__c: '',
            LT_T_Recurring_Maintenance_Issues__c: '',
            LT_T_Recurring_Issues_Specify__c: '',
            LT_T_Property_Cleanliness_Safety__c: '',
            LT_T_Property_Unsafe_Details__c: '',
            LT_T_Pets_Allowed_In_Unit__c: '',
            LT_T_Neighbor_Noise_Issues__c: '',
            LT_T_Neighbor_Noise_Issues_Details__c: '',
            LT_T_Sublet_Extended_Guests__c: '',
            LT_T_Sublet_Guest_Approved__c: '',
            LT_T_Received_Landlord_Notices__c: '',
            LT_T_Landlord_Notice_Reason__c: '',
            LT_T_Concerning_Lease_Clauses__c: '',
            LT_T_Concerning_Clauses_Specify__c: '',
            LT_T_Designated_Parking__c: '',
            LT_T_Parking_Location_Specify__c: '',
            LT_T_Involved_In_Eviction__c: '',
            LT_T_Eviction_Details__c: '',
            LT_T_Current_Disputes_With_Landlord__c: '',
            LT_T_Current_Dispute_Details__c: '',
            LT_T_Has_Renters_Insurance__c: '',
            LT_T_Renters_Insurance_Details__c: '',
            LT_T_Informed_Of_Tenant_Rights__c: '',
            LT_T_Informed_Of_Rights_By_Whom__c: '',
            
            // Section 10: Defamation
            DEF_Status__c: '',
            DEF_Statement_Maker_Name__c: '',
            DEF_Statement_Maker_Occupation__c: '',
            DEF_Statement_Maker_Relationship__c: '',
            DEF_Your_Relationship_To_Maker__c: '',
            DEF_Your_Relationship_Other_Specify__c: '',
            DEF_Statement_Content_Types__c: '',
            DEF_Statement_Content_Other_Specify__c: '',
            DEF_Statement_Context__c: '',
            DEF_Statements_In_Writing__c: '',
            DEF_Written_Publication_Location__c: '',
            DEF_Written_Medium__c: '',
            DEF_Written_Audience_Recipients__c: '',
            DEF_Written_Number_Exposed__c: '',
            DEF_Statements_Spoken__c: '',
            DEF_Spoken_Location__c: '',
            DEF_Spoken_Setting__c: '',
            DEF_Spoken_Audience__c: '',
            DEF_Spoken_Number_Exposed__c: '',
            DEF_Is_Public_Figure__c: '',
            DEF_Statements_By_Business_Rep__c: '',
            DEF_Business_Rep_Employer_Name__c: '',
            DEF_Damaged_By_Statements__c: '',
            DEF_Can_Estimate_Damages__c: '',
            DEF_Estimated_Financial_Losses__c: '',
            DEF_Damage_To_Personal_Reputation__c: '',
            DEF_Damage_To_Prof_Reputation__c: '',
            DEF_Emotional_Distress_Details__c: '',
            
            // Plaintiff specific
            DEF_P_Suffered_Financial_Damages__c: '',
            DEF_P_Financial_Loss_Amount__c: '',
            DEF_P_Reputation_Affected_How__c: '',
            DEF_P_Reputation_Affected_Other__c: '',
            DEF_P_Able_To_Repair_Reputation__c: '',
            DEF_P_Steps_To_Repair_Reputation__c: '',
            DEF_P_Actions_In_Response__c: '',
            DEF_P_Actions_Response_Other__c: '',
            DEF_P_Received_Compensation__c: '',
            DEF_P_Compensation_Form__c: '',
            
            // Defendant specific
            DEF_D_Made_Statements__c: '',
            DEF_D_Did_Not_Make_Explain__c: '',
            DEF_D_Intention_Making_Statements__c: '',
            DEF_D_Intention_Other_Specify__c: '',
            DEF_D_Believed_True_At_Time__c: '',
            DEF_D_Aware_Of_Potential_Harm__c: '',
            DEF_D_Statement_Context__c: '',
            DEF_D_Statement_Context_Other__c: '',
            DEF_D_Statement_Capacity__c: '',
            DEF_D_Verified_Truth_Before__c: '',
            DEF_D_Verification_Steps__c: '',
            DEF_D_Believe_Statements_True__c: '',
            DEF_D_Why_Made_If_Not_True__c: '',
            DEF_D_Made_Public_Apology__c: '',
            DEF_D_Apology_Form__c: '',
            DEF_D_Legal_Protections_Apply__c: '',
            DEF_D_Legal_Privilege_Description__c: '',
            DEF_D_Statement_Under_Legal_Privilege__c: '',
            
            // Legal and Financial Damages
            DEF_LFD_Plaintiff_Sought_Damages__c: '',
            DEF_LFD_Amount_Claimed__c: '',
            DEF_LFD_Claim_Reasonable__c: '',
            DEF_LFD_Claim_Not_Reasonable_Why__c: '',
            DEF_LFD_Settlement_Steps__c: '',
            DEF_LFD_Settlement_Steps_Other__c: '',
            DEF_LFD_Settlement_Appropriate__c: '',
            DEF_LFD_Proposed_Settlement_Terms__c: '',
            
            // Section 11: HOA
            HOA_Your_Address__c: '',
            HOA_Name__c: '',
            HOA_Can_Send_Org_Docs__c: '',
            HOA_Is_Board_Member__c: '',
            HOA_Nature_Of_Issue__c: '',
            HOA_Parties_Involved__c: '',
            HOA_Lawsuit_Filed_On_Issue__c: '',
            HOA_Lawsuit_Court__c: '',
            HOA_Lawsuit_County__c: '',
            HOA_Lawsuit_State__c: '',
            HOA_Lawsuit_Case_Number__c: '',
            
            // Section 12: Construction
            CONST_Project_Address__c: '',
            CONST_Construction_Type__c: '',
            CONST_Construction_Type_Other__c: '',
            CONST_Project_Scope__c: '',
            CONST_Project_Scope_Other__c: '',
            CONST_Project_Owner_Name__c: '',
            CONST_Project_Owner_Contact__c: '',
            CONST_Primary_Contractors__c: '',
            CONST_Primary_Subcontractors__c: '',
            CONST_Primary_Architect_Designer__c: '',
            CONST_Primary_Engineer__c: '',
            CONST_Issue_Nature__c: '',
            CONST_Issue_Nature_Other__c: '',
            CONST_Defect_Types__c: '',
            CONST_Defect_Types_Other__c: '',
            CONST_Defect_Apparent_Date__c: null,
            CONST_Defect_Severity__c: '',
            CONST_Inspections_Conducted__c: '',
            CONST_Defects_Communicated__c: '',
            CONST_Contractor_Response__c: '',
            CONST_Contractor_Agreed_Repairs__c: '',
            CONST_Contractor_Refusal_Desc__c: '',
            CONST_Formal_Contract_Signed__c: '',
            CONST_Has_Contract_Copy__c: '',
            CONST_Lawsuit_Initiated__c: '',
            CONST_Lawsuit_Filed_Location__c: '',
            CONST_Lawsuit_Case_Number__c: '',
            CONST_Construction_Lien_Involved__c: '',
            CONST_Lien_Details__c: '',
            CONST_Warranties_Exist__c: '',
            CONST_Warranties_Coverage__c: '',
            CONST_Project_Total_Value__c: '',
            CONST_Payment_Made_To_Contractor__c: '',
            CONST_Amount_Paid_To_Contractor__c: '',
            CONST_Outstanding_Balance_Amount__c: '',
            CONST_Unpaid_Invoices_Exist__c: '',
            CONST_Unpaid_Invoices_Details__c: '',
            
            // Section 13: Business
            BUS_Assistance_Type__c: '',
            BUS_Partner_Dispute_Nature__c: '',
            BUS_Partner_Dispute_Has_Gov_Doc__c: '',
            BUS_Partner_Dispute_Assistance__c: '',
            BUS_Partner_Dispute_Docs_To_Review__c: '',
            BUS_Contract_Draft_Business_Nature__c: '',
            BUS_Contract_Draft_Type__c: '',
            BUS_Contract_Draft_Type_Other__c: '',
            BUS_Contract_Draft_Has_Revision__c: '',
            BUS_Create_Business_Type__c: '',
            BUS_Create_People_Involved_Count__c: '',
            BUS_Create_Desired_Name__c: '',
            BUS_Dissolve_Business_Name__c: '',
            BUS_Dissolve_People_Involved_Count__c: '',
            BUS_Dissolve_Reason__c: '',
            BUS_Dissolve_Assets__c: '',
            BUS_Doc_Review_Types__c: '',
            BUS_Doc_Review_Page_Count__c: '',
            BUS_Gen_Contract_Review_Contracts__c: '',
            BUS_Gen_Contract_Review_Page_Count__c: '',
            BUS_Purchase_Or_Sale__c: '',
            BUS_Purchase_Sale_Contract_Status__c: '',
            BUS_Purchase_Sale_Business_Name_Type__c: '',
            BUS_Purchase_Sale_Price__c: '',
            BUS_Purchase_Sale_Inclusions__c: '',
            BUS_Purchase_Sale_Inclusions_Other__c: '',
            
            // Section 14: Guardianship/Conservatorship
            GC_Involvement_Type__c: '',
            GC_Specific_Legal_Assistance__c: '',
            GC_Ward_Full_Name__c: '',
            GC_Ward_Incapacity_Reason__c: '',
            GC_Ward_Formally_Diagnosed__c: '',
            GC_Ward_Diagnosing_Professional__c: '',
            GC_Ward_Diagnosis_Date__c: null,
            GC_Is_Emergency_Situation__c: '',
            GC_Emergency_Reason__c: '',
            GC_Your_Relationship_To_Ward__c: '',
            GC_Ward_Lives_In_CO__c: '',
            GC_Ward_Owns_Real_Estate_CO__c: '',
            GC_Ward_Real_Estate_Addresses__c: '',
            GC_Ward_Real_Estate_Type__c: '',
            GC_Ward_Real_Estate_Value__c: '',
            GC_Ward_Has_Income_Source__c: '',
            GC_Ward_Income_Source_Specify__c: '',
            GC_Ward_Has_Cash_Assets__c: '',
            GC_Ward_Bank_Accounts_Details__c: '',
            GC_Ward_Retirement_Accounts_Details__c: '',
            GC_Ward_Investments_Other_Assets__c: '',
            GC_Ward_Has_Liabilities__c: '',
            GC_Ward_Liability_Types__c: '',
            GC_Ward_Total_Estimated_Debt__c: '',
            GC_Respondent_In_Existing_Proceedings__c: '',
            GC_Existing_Proceedings_Jurisdiction__c: '',
            GC_Existing_Proceedings_Case_Number__c: '',
            GC_Respondent_Prev_Appointed_Other_State__c: '',
            GC_Transfer_To_Colorado__c: '',
            GC_Ward_Has_Children__c: '',
            GC_Ward_Children_Minors__c: '',
            GC_Ward_Parents_Living__c: '',
            GC_Ward_Living_Siblings__c: '',
            GC_Ward_Siblings_Contact_Optional__c: '',
            GC_Assistance_Needed_Types__c: '',
            GC_Assistance_Needed_Other_Specify__c: '',
            
            // Section 15: Closing Questions
            CQ_Docs_For_Review__c: '',
            CQ_Docs_For_Review_Specify__c: '',
            CQ_Docs_For_Review_Pages__c: '',
            CQ_Total_Damages_Amount__c: '',
            Nature_of_Matter__c: '',
            Additional_Contacts__c: ''
        };
    }

    async createNewIntake() {
        this.isLoading = true;
        try {
            this.intakeRecord = await createNewIntakeForLead({ leadId: this.leadId });
        } catch (error) {
            this.showToast('Error', 'Failed to create new intake: ' + error.body.message, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async loadExistingRecord() {
        this.isLoading = true;
        try {
            const record = await getFullIntakeRecord({ intakeId: this.recordId });
            this.intakeRecord = { ...record };
            
            // Parse multi-select picklist values
            if (record.Legal_Matter_Type__c) {
                this.selectedLegalMatterTypes = record.Legal_Matter_Type__c.split(';');
            }
            if (record.CL_Case_Involvement_Types__c) {
                this.selectedCaseInvolvementTypes = record.CL_Case_Involvement_Types__c.split(';');
            }
            if (record.DV_Types_Of_Abuse__c) {
                this.selectedAbuseTypes = record.DV_Types_Of_Abuse__c.split(';');
            }
            if (record.DV_Receiving_Support_Services__c) {
                this.selectedSupportServices = record.DV_Receiving_Support_Services__c.split(';');
            }
            if (record.PI_Damages_Sought__c) {
                this.selectedDamagesSought = record.PI_Damages_Sought__c.split(';');
            }
            if (record.EP_Documents_Needed__c) {
                this.selectedEPDocuments = record.EP_Documents_Needed__c.split(';');
            }
            if (record.BUS_Purchase_Sale_Inclusions__c) {
                this.selectedBusinessInclusions = record.BUS_Purchase_Sale_Inclusions__c.split(';');
            }
            if (record.DEF_Statement_Content_Types__c) {
                this.selectedStatementContentTypes = record.DEF_Statement_Content_Types__c.split(';');
            }
            if (record.DEF_P_Reputation_Affected_How__c) {
                this.selectedReputationEffects = record.DEF_P_Reputation_Affected_How__c.split(';');
            }
            if (record.DEF_P_Actions_In_Response__c) {
                this.selectedResponseActions = record.DEF_P_Actions_In_Response__c.split(';');
            }
            if (record.CONST_Defect_Types__c) {
                this.selectedConstructionDefects = record.CONST_Defect_Types__c.split(';');
            }
            if (record.GC_Assistance_Needed_Types__c) {
                this.selectedGCAssistanceTypes = record.GC_Assistance_Needed_Types__c.split(';');
            }
            if (record.GC_Involvement_Type__c) {
                this.selectedGCInvolvementTypes = record.GC_Involvement_Type__c.split(';');
            }
            if (record.Additional_Contacts__c) { // ADDED
                this.selectedAdditionalContacts = record.Additional_Contacts__c.split(';');
            }
            
            this.updateProgress();
        } catch (error) {
            this.showToast('Error', 'Failed to load intake record: ' + error.body.message, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    // --- Navigation Methods ---
    get showPreviousButton() {
        return this.currentSection > 1;
    }

    get showNextButton() {
        return this.currentSection < this.totalSections;
    }

    get currentSectionName() {
        const sectionNames = {
            1: 'General Information',
            2: 'Criminal Law',
            3: 'Family Law',
            4: 'Probate & Estate Planning',
            5: 'Real Estate',
            6: 'Personal Injury',
            7: 'Civil Litigation',
            8: 'Employment Law',
            9: 'Landlord/Tenant',
            10: 'Defamation',
            11: 'HOA',
            12: 'Construction',
            13: 'Business',
            14: 'Guardianship/Conservatorship',
            15: 'Closing Questions'
        };
        return sectionNames[this.currentSection];
    }

    handlePreviousSection() {
        if (this.currentSection > 1) {
            this.currentSection--;
            window.scrollTo(0, 0);
        }
    }

    handleNextSection() {
        if (this.currentSection < this.totalSections) {
            this.currentSection++;
            window.scrollTo(0, 0);
        }
    }

    // --- Visibility Getters ---
    get launchButtonLabel() {
        return this.isFormLaunched ? 'Hide Intake Form' : 'Launch Intake Form';
    }

    get launchButtonIcon() {
        return this.isFormLaunched ? 'utility:chevrondown' : 'utility:chevronright';
    }

    // Section visibility
    get showSection1() { return this.isFormLaunched && this.currentSection === 1; }
    get showSection2() { return this.isFormLaunched && this.currentSection === 2; }
    get showSection3() { return this.isFormLaunched && this.currentSection === 3; }
    get showSection4() { return this.isFormLaunched && this.currentSection === 4; }
    get showSection5() { return this.isFormLaunched && this.currentSection === 5; }
    get showSection6() { return this.isFormLaunched && this.currentSection === 6; }
    get showSection7() { return this.isFormLaunched && this.currentSection === 7; }
    get showSection8() { return this.isFormLaunched && this.currentSection === 8; }
    get showSection9() { return this.isFormLaunched && this.currentSection === 9; }
    get showSection10() { return this.isFormLaunched && this.currentSection === 10; }
    get showSection11() { return this.isFormLaunched && this.currentSection === 11; }
    get showSection12() { return this.isFormLaunched && this.currentSection === 12; }
    get showSection13() { return this.isFormLaunched && this.currentSection === 13; }
    get showSection14() { return this.isFormLaunched && this.currentSection === 14; }
    get showSection15() { return this.isFormLaunched && this.currentSection === 15; }

    // Legal matter type visibility
    get showCriminalLawSection() {
        return this.selectedLegalMatterTypes && this.selectedLegalMatterTypes.includes('Criminal Law');
    }

    get showFamilyLawSection() {
        return this.selectedLegalMatterTypes && this.selectedLegalMatterTypes.includes('Family Law');
    }

    get showProbateSection() {
        return this.selectedLegalMatterTypes && this.selectedLegalMatterTypes.includes('Probate/Estate Planning');
    }

    get showRealEstateSection() {
        return this.selectedLegalMatterTypes && this.selectedLegalMatterTypes.includes('Real Estate');
    }

    get showPersonalInjurySection() {
        return this.selectedLegalMatterTypes && this.selectedLegalMatterTypes.includes('Personal Injury');
    }

    get showCivilLitigationSection() {
        return this.selectedLegalMatterTypes && this.selectedLegalMatterTypes.includes('Civil Litigation');
    }

    get showEmploymentLawSection() {
        return this.selectedLegalMatterTypes && this.selectedLegalMatterTypes.includes('Employment Law');
    }

    get showLandlordTenantSection() {
        return this.selectedLegalMatterTypes && this.selectedLegalMatterTypes.includes('Landlord-Tenant Dispute');
    }

    get showBusinessLawSection() {
        return this.selectedLegalMatterTypes && this.selectedLegalMatterTypes.includes('Business Law');
    }

    get showDefamationSection() {
        return this.selectedLegalMatterTypes && this.selectedLegalMatterTypes.includes('Defamation');
    }

    get showHOASection() {
        return this.selectedLegalMatterTypes && this.selectedLegalMatterTypes.includes('HOA');
    }

    get showConstructionSection() {
        return this.selectedLegalMatterTypes && this.selectedLegalMatterTypes.includes('Construction');
    }

    get showGuardianshipSection() {
        return this.selectedLegalMatterTypes && this.selectedLegalMatterTypes.includes('Guardianship/Conservatorship');
    }

    // All conditional field getters
    get showLegalMatterOtherSpecify() {
        return this.selectedLegalMatterTypes && this.selectedLegalMatterTypes.includes('Other');
    }

    get showHowHearAdvertisementSpecify() {
        return this.intakeRecord.How_Did_You_Hear__c === 'Advertisement';
    }

    get showHowHearReferralSpecify() {
        return this.intakeRecord.How_Did_You_Hear__c === 'Referral';
    }

    get showHowHearSocialMediaSpecify() {
        return this.intakeRecord.How_Did_You_Hear__c === 'Social Media';
    }

    get showHowHearOtherSpecify() {
        return this.intakeRecord.How_Did_You_Hear__c === 'Other';
    }

    get showAccommodationsSpecify() {
        return this.intakeRecord.Require_Appointment_Accommodations__c === 'Yes';
    }

    get showPriorAttorneyDetails() {
        return this.intakeRecord.Spoken_With_Other_Attorneys__c === 'Yes';
    }

    get showPriorAttorneyCostSpecify() {
        return this.intakeRecord.Reason_No_Hire_Prior_Attorney__c === 'Cost';
    }

    get showPriorAttorneyOtherSpecify() {
        return this.intakeRecord.Reason_No_Hire_Prior_Attorney__c === 'Other';
    }

    get showCurrentlyRepresentedDetails() {
        return this.intakeRecord.Currently_Represented__c === 'Yes';
    }

    get showPreviousAttorneyOffice() {
        return this.intakeRecord.Worked_With_Us_Before__c === 'Yes';
    }

    // Criminal Law conditional fields
    get showAgencyPoliceSpecify() {
        return this.intakeRecord.CL_Investigating_Agency__c === 'Police Department';
    }

    get showAgencyOtherSpecify() {
        return this.intakeRecord.CL_Investigating_Agency__c === 'Other';
    }

    get showCaseFiledDetails() {
        return this.intakeRecord.CL_Case_Filed__c === 'Yes';
    }

    get showMatterUnderInvestigation() {
        return this.intakeRecord.CL_Case_Filed__c === 'No';
    }

    get showCaseStatusOtherSpecify() {
        return this.intakeRecord.CL_Case_Status__c === 'Other';
    }

    get showCaseInvolvementOtherSpecify() {
        return this.selectedCaseInvolvementTypes && this.selectedCaseInvolvementTypes.includes('Other');
    }

    get showDUIDWISection() {
        return this.showCriminalLawSection && this.selectedCaseInvolvementTypes &&
               (this.selectedCaseInvolvementTypes.includes('Drug Offense') || 
                this.selectedCaseInvolvementTypes.includes('DUI/DWI'));
    }

    get showRecordSealingSection() {
        return this.showCriminalLawSection && this.intakeRecord.CL_Case_Status__c === 'Record Sealing';
    }

    get showDUIPulledOverOtherSpecify() {
        return this.intakeRecord.CL_DUI_Pulled_Over_Reason__c === 'Other';
    }

    get showDUIPriorConvictionsDetails() {
        return this.intakeRecord.CL_DUI_Prior_Convictions__c === 'Yes';
    }

    get showDomesticViolenceSection() {
        return this.showCriminalLawSection && this.selectedCaseInvolvementTypes && 
               this.selectedCaseInvolvementTypes.includes('Domestic Violence');
    }

    get showDVRecentIncidentDetails() {
        return this.showDomesticViolenceSection && this.intakeRecord.DV_Physically_Harmed__c === 'Yes';
    }

    get showDVAbuseTypeOther() {
        return this.selectedAbuseTypes && this.selectedAbuseTypes.includes('Other');
    }

    get showDVPerpetratorOther() {
        return this.intakeRecord.DV_Perpetrator_Identity__c === 'Other';
    }

    get showDVPerpetratorFamily() {
        return this.intakeRecord.DV_Perpetrator_Identity__c === 'Family member';
    }

    get showDVRelationshipOther() {
        return this.intakeRecord.DV_Relationship_To_Perpetrator__c === 'Other';
    }

    get showDVAbuserContactFrequency() {
        return this.intakeRecord.DV_Abuser_Lives_With_You__c === 'No';
    }

    get showDVChildrenDetails() {
        return this.intakeRecord.DV_Have_Children__c === 'Yes';
    }

    get showDVThreatDetails() {
        return this.intakeRecord.DV_Abuser_Threatened_Harm__c === 'Yes';
    }

    get showDVInjuryDetails() {
        return this.intakeRecord.DV_Injured_From_Abuse__c === 'Yes';
    }

    get showDVWeaponDetails() {
        return this.intakeRecord.DV_Abuser_Threatened_Weapon__c === 'Yes';
    }

    get showDVFirearmTypes() {
        return this.intakeRecord.DV_Firearms_Present__c === 'Yes';
    }

    get showDVLawEnforcementDetails() {
        return this.intakeRecord.DV_Contacted_Law_Enforcement__c === 'Yes';
    }

    get showDVProtectionOrderDetails() {
        return this.intakeRecord.DV_Sought_Protection_Order__c === 'Yes';
    }

    get showDVCriminalCaseDetails() {
        return this.intakeRecord.DV_Involved_In_Criminal_Case__c === 'Yes';
    }

    get showDVSupportServicesOther() {
        return this.selectedSupportServices && this.selectedSupportServices.includes('Other');
    }

    get showDVNeedShelter() {
        return this.intakeRecord.DV_Safe_Place_To_Stay__c === 'No';
    }

    // Family Law conditional fields
    get showMarriageDetails() {
        return this.intakeRecord.FL_Currently_Married__c === 'Yes';
    }

    get showPropertyDivisionDetails() {
        return this.intakeRecord.FL_Divorce_Property_Division__c === 'Yes';
    }

    get showChildrenDetails() {
        return this.intakeRecord.FL_Spouse_Children_Together__c === 'Yes';
    }

    // Probate conditional fields
    get showPERelationshipOther() {
        return this.intakeRecord.PE_PC_Relationship_To_Deceased__c === 'Other';
    }

    get showProbateOpenedDetails() {
        return this.intakeRecord.PE_Probate_Estate_Opened__c === 'Yes';
    }

    get showAssetTypeOther() {
        return this.intakeRecord.PE_Decedent_Asset_Types__c && 
               this.intakeRecord.PE_Decedent_Asset_Types__c.includes('Other');
    }

    get showEPDocumentsOther() {
        return this.selectedEPDocuments && this.selectedEPDocuments.includes('Other');
    }

    // Real Estate conditional fields
    get showREAssistanceOther() {
        return this.intakeRecord.RE_Assistance_Type__c === 'Other';
    }

    get showREPurchaseSaleDetails() {
        return this.intakeRecord.RE_Assistance_Type__c === 'Purchase' || 
               this.intakeRecord.RE_Assistance_Type__c === 'Sale';
    }

    get showRELeaseDetails() {
        return this.intakeRecord.RE_Assistance_Type__c === 'Lease';
    }

    get showREDisputeDetails() {
        return this.intakeRecord.RE_Assistance_Type__c === 'Dispute Resolution';
    }

    get showRERealtorInfo() {
        return this.intakeRecord.RE_Working_With_Realtor__c === 'Yes';
    }

    get showREFinancingOther() {
        return this.intakeRecord.RE_Financing_Type__c === 'Other';
    }

    get showRELeaseTermsSpecify() {
        return this.intakeRecord.RE_Specific_Lease_Terms__c === 'Yes';
    }

    get showREDisputeOther() {
        return this.intakeRecord.RE_Dispute_Nature__c === 'Other';
    }

    get showRELegalActionDetails() {
        return this.intakeRecord.RE_Dispute_Legal_Action_Taken__c === 'Yes';
    }

    get showREZoningDetails() {
        return this.intakeRecord.RE_Environmental_Zoning_Issues__c === 'Yes';
    }

    get showREHOADocs() {
        return this.intakeRecord.RE_Property_In_HOA__c === 'Yes';
    }

    // Personal Injury conditional fields
    get showPIRoleOther() {
        return this.intakeRecord.PI_Your_Role__c === 'Other';
    }

    get showPIMedicalDetails() {
        return this.intakeRecord.PI_Received_Medical_Treatment__c === 'Yes';
    }

    get showPIWitnessDetails() {
        return this.intakeRecord.PI_Incident_Witnesses__c === 'Yes';
    }

    get showPIPoliceDetails() {
        return this.intakeRecord.PI_Police_Report_Filed__c === 'Yes';
    }

    get showPIInsuranceDetails() {
        return this.intakeRecord.PI_Has_Insurance_Coverage__c === 'Yes';
    }

    get showPIOtherPartyInsurance() {
        return this.intakeRecord.PI_Other_Party_Has_Insurance__c === 'Yes';
    }

    get showPIDamagesOther() {
        return this.selectedDamagesSought && this.selectedDamagesSought.includes('Other');
    }

    // Civil Litigation conditional fields
    get showCLITClaimBasisOther() {
        return this.intakeRecord.CLIT_Claim_Basis__c === 'Other';
    }

    get showCLITLawsuitDetails() {
        return this.intakeRecord.CLIT_Lawsuits_Filed__c === 'Yes';
    }

    // Employment Law conditional fields
    get showEMPLIssueOther() {
        return this.intakeRecord.EMPL_Employment_Issue_Type__c === 'Other';
    }

    get showEMPLOutcomeOther() {
        return this.intakeRecord.EMPL_Desired_Outcome__c === 'Other';
    }

    // Landlord/Tenant conditional fields
    get showLandlordQuestions() {
        return this.intakeRecord.LT_Role__c === 'Landlord';
    }

    get showTenantQuestions() {
        return this.intakeRecord.LT_Role__c === 'Tenant';
    }

    get showLTLegalActionDetails() {
        return this.intakeRecord.LT_Legal_Action_Taken__c === 'Yes';
    }

    // Landlord specific conditionals
    get showLTLOwnerDetails() {
        return this.intakeRecord.LT_L_Owns_Property__c === 'No';
    }

    get showLTLMultiUnitCount() {
        return this.intakeRecord.LT_L_Number_Of_Units__c === 'Multi-unit';
    }

    get showLTLPropertyMgmtName() {
        return this.intakeRecord.LT_L_Property_Manager__c === 'Property Management Company';
    }

    get showLTLInsuranceProvider() {
        return this.intakeRecord.LT_L_Has_Property_Insurance__c === 'Yes';
    }

    get showLTLPastIssuesDetails() {
        return this.intakeRecord.LT_L_Past_Property_Issues__c === 'Yes';
    }

    get showLTLLeaseTermDuration() {
        return this.intakeRecord.LT_L_Lease_Term__c === 'Fixed-term';
    }

    get showLTLLeaseTermOther() {
        return this.intakeRecord.LT_L_Lease_Term__c === 'Other';
    }

    get showLTLSecurityDepositAmount() {
        return this.intakeRecord.LT_L_Security_Deposit_Required__c === 'Yes';
    }

    get showLTLRentIncludesUtilities() {
        return this.intakeRecord.LT_L_Rent_Includes__c && 
               this.intakeRecord.LT_L_Rent_Includes__c.includes('Utilities');
    }

    get showLTLRentIncludesOther() {
        return this.intakeRecord.LT_L_Rent_Includes__c && 
               this.intakeRecord.LT_L_Rent_Includes__c.includes('Other');
    }

    get showLTLGracePeriodDuration() {
        return this.intakeRecord.LT_L_Late_Rent_Grace_Period__c === 'Yes';
    }

    get showLTLConsequenceOther() {
        return this.intakeRecord.LT_L_Consequence_Late_Rent__c === 'Other';
    }

    get showLTLRentIncreaseConditions() {
        return this.intakeRecord.LT_L_Rent_Increase_Policy__c === 'Yes';
    }

    get showLTLPestControlShared() {
        return this.intakeRecord.LT_L_Pest_Control_Procedure__c === 'Shared responsibility';
    }

    get showLTLInspectionFrequency() {
        return this.intakeRecord.LT_L_Regular_Inspections__c === 'Yes';
    }

    get showLTLPetTypesAllowed() {
        return this.intakeRecord.LT_L_Pets_Allowed__c === 'Yes';
    }

    get showLTLNoiseRestrictionsDetails() {
        return this.intakeRecord.LT_L_Noise_Conduct_Restrictions__c === 'Yes';
    }

    get showLTLSublettingConditions() {
        return this.intakeRecord.LT_L_Subletting_Guests_Allowed__c === 'Yes';
    }

    get showLTLAlterationTypes() {
        return this.intakeRecord.LT_L_Tenant_Alterations_Allowed__c === 'Yes';
    }

    get showLTLEvictionDetails() {
        return this.intakeRecord.LT_L_Initiated_Evictions__c === 'Yes';
    }

    get showLTLCurrentDisputeDetails() {
        return this.intakeRecord.LT_L_Current_Legal_Disputes__c === 'Yes';
    }

    get showLTLCodeViolationDetails() {
        return this.intakeRecord.LT_L_Past_Code_Violations__c === 'Yes';
    }

    get showLTLRenewalOther() {
        return this.intakeRecord.LT_L_Lease_Renewal_Policy__c === 'Other';
    }

    // Tenant specific conditionals
    get showLTTLeaseTermDuration() {
        return this.intakeRecord.LT_T_Lease_Term__c === 'Fixed-term';
    }

    get showLTTLeaseTermOther() {
        return this.intakeRecord.LT_T_Lease_Term__c === 'Other';
    }

    get showLTTRentInclusives() {
        return this.intakeRecord.LT_T_Rent_Includes_Utilities__c === 'Yes';
    }

    get showLTTSecurityDepositAmount() {
        return this.intakeRecord.LT_T_Paid_Security_Deposit__c === 'Yes';
    }

    get showLTTLateFeeTerms() {
        return this.intakeRecord.LT_T_Late_Fees_For_Rent__c === 'Yes';
    }

    get showLTTRentIncreaseTerms() {
        return this.intakeRecord.LT_T_Rent_Increases_During_Lease__c === 'Yes';
    }

    get showLTTRepairDetails() {
        return this.intakeRecord.LT_T_Requested_Repairs__c === 'Yes';
    }

    get showLTTRepairProcessOther() {
        return this.intakeRecord.LT_T_Repair_Request_Process__c === 'Other';
    }

    get showLTTRecurringIssuesDetails() {
        return this.intakeRecord.LT_T_Recurring_Maintenance_Issues__c === 'Yes';
    }

    get showLTTPropertyUnsafeDetails() {
        return this.intakeRecord.LT_T_Property_Cleanliness_Safety__c === 'Unsafe';
    }

    get showLTTNeighborIssuesDetails() {
        return this.intakeRecord.LT_T_Neighbor_Noise_Issues__c === 'Yes';
    }

    get showLTTSubletApprovalDetails() {
        return this.intakeRecord.LT_T_Sublet_Extended_Guests__c === 'Yes';
    }

    get showLTTLandlordNoticeDetails() {
        return this.intakeRecord.LT_T_Received_Landlord_Notices__c === 'Yes';
    }

    get showLTTConcerningClausesDetails() {
        return this.intakeRecord.LT_T_Concerning_Lease_Clauses__c === 'Yes';
    }

    get showLTTParkingLocation() {
        return this.intakeRecord.LT_T_Designated_Parking__c === 'Yes';
    }

    get showLTTEvictionDetails() {
        return this.intakeRecord.LT_T_Involved_In_Eviction__c === 'Yes';
    }

    get showLTTCurrentDisputeDetails() {
        return this.intakeRecord.LT_T_Current_Disputes_With_Landlord__c === 'Yes';
    }

    get showLTTRentersInsuranceDetails() {
        return this.intakeRecord.LT_T_Has_Renters_Insurance__c === 'Yes';
    }

    get showLTTInformedByWhom() {
        return this.intakeRecord.LT_T_Informed_Of_Tenant_Rights__c === 'Yes';
    }

    // Defamation conditional fields
    get showDefRelationshipOther() {
        return this.intakeRecord.DEF_Your_Relationship_To_Maker__c === 'Other';
    }

    get showStatementContentOther() {
        return this.selectedStatementContentTypes && this.selectedStatementContentTypes.includes('Other');
    }

    get showWrittenStatementDetails() {
        return this.intakeRecord.DEF_Statements_In_Writing__c === 'Yes';
    }

    get showSpokenStatementDetails() {
        return this.intakeRecord.DEF_Statements_Spoken__c === 'Yes';
    }

    get showBusinessRepDetails() {
        return this.intakeRecord.DEF_Statements_By_Business_Rep__c === 'Yes';
    }

    get showDamageEstimates() {
        return this.intakeRecord.DEF_Can_Estimate_Damages__c === 'Yes';
    }

    get showDefamationPlaintiffQuestions() {
        return this.intakeRecord.DEF_Status__c === 'Victim of defamation';
    }

    get showDefamationDefendantQuestions() {
        return this.intakeRecord.DEF_Status__c === 'Accused of defaming others';
    }

    get showPlaintiffFinancialDetails() {
        return this.intakeRecord.DEF_P_Suffered_Financial_Damages__c === 'Yes';
    }

    get showReputationOther() {
        return this.selectedReputationEffects && this.selectedReputationEffects.includes('Other');
    }

    get showRepairSteps() {
        return this.intakeRecord.DEF_P_Able_To_Repair_Reputation__c === 'Yes';
    }

    get showResponseActionOther() {
        return this.selectedResponseActions && this.selectedResponseActions.includes('Other');
    }

    get showCompensationDetails() {
        return this.intakeRecord.DEF_P_Received_Compensation__c === 'Yes';
    }

    get showDefendantDidNotMake() {
        return this.intakeRecord.DEF_D_Made_Statements__c === 'No';
    }

    get showIntentionOther() {
        return this.intakeRecord.DEF_D_Intention_Making_Statements__c === 'Other';
    }

    get showStatementContextOther() {
        return this.intakeRecord.DEF_D_Statement_Context__c === 'Other';
    }

    get showVerificationSteps() {
        return this.intakeRecord.DEF_D_Verified_Truth_Before__c === 'Yes';
    }

    get showWhyMadeIfNotTrue() {
        return this.intakeRecord.DEF_D_Believe_Statements_True__c === 'No';
    }

    get showApologyDetails() {
        return this.intakeRecord.DEF_D_Made_Public_Apology__c === 'Yes';
    }

    get showLegalProtectionDetails() {
        return this.intakeRecord.DEF_D_Legal_Protections_Apply__c === 'Yes';
    }

    get showPlaintiffDamageDetails() {
        return this.intakeRecord.DEF_LFD_Plaintiff_Sought_Damages__c === 'Yes';
    }

    get showClaimNotReasonableDetails() {
        return this.intakeRecord.DEF_LFD_Claim_Reasonable__c === 'No';
    }

    get showSettlementStepsOther() {
        return this.intakeRecord.DEF_LFD_Settlement_Steps__c === 'Other';
    }

    get showSettlementTerms() {
        return this.intakeRecord.DEF_LFD_Settlement_Appropriate__c === 'Yes';
    }

    // HOA conditional fields
    get showHOALawsuitDetails() {
        return this.intakeRecord.HOA_Lawsuit_Filed_On_Issue__c === 'Yes';
    }

    // Construction conditional fields
    get showConstructionTypeOther() {
        return this.intakeRecord.CONST_Construction_Type__c === 'Other';
    }

    get showProjectScopeOther() {
        return this.intakeRecord.CONST_Project_Scope__c === 'Other';
    }

    get showIssueNatureOther() {
        return this.intakeRecord.CONST_Issue_Nature__c === 'Other';
    }

    get showDefectTypesOther() {
        return this.selectedConstructionDefects && this.selectedConstructionDefects.includes('Other');
    }

    get showInspectionDetails() {
        return this.intakeRecord.CONST_Inspections_Conducted__c === 'Yes';
    }

    get showContractorResponseDetails() {
        return this.intakeRecord.CONST_Defects_Communicated__c === 'Yes';
    }

    get showContractorRefusalDetails() {
        return this.intakeRecord.CONST_Contractor_Agreed_Repairs__c === 'No';
    }

    get showContractCopy() {
        return this.intakeRecord.CONST_Formal_Contract_Signed__c === 'Yes';
    }

    get showLawsuitDetails() {
        return this.intakeRecord.CONST_Lawsuit_Initiated__c === 'Yes';
    }

    get showLienDetails() {
        return this.intakeRecord.CONST_Construction_Lien_Involved__c === 'Yes';
    }

    get showWarrantyDetails() {
        return this.intakeRecord.CONST_Warranties_Exist__c === 'Yes';
    }

    get showPaymentDetails() {
        return this.intakeRecord.CONST_Payment_Made_To_Contractor__c === 'Yes';
    }

    get showUnpaidInvoiceDetails() {
        return this.intakeRecord.CONST_Unpaid_Invoices_Exist__c === 'Yes';
    }

    // Business Law conditional fields
    get showBusinessDisputeDetails() {
        return this.intakeRecord.BUS_Assistance_Type__c === 'Business Partner Dispute';
    }

    get showContractDraftingDetails() {
        return this.intakeRecord.BUS_Assistance_Type__c === 'Contract Drafting';
    }

    get showBusinessCreationDetails() {
        return this.intakeRecord.BUS_Assistance_Type__c === 'Creation of Business';
    }

    get showBusinessDissolutionDetails() {
        return this.intakeRecord.BUS_Assistance_Type__c === 'Dissolution of Business';
    }

    get showDocumentReviewDetails() {
        return this.intakeRecord.BUS_Assistance_Type__c === 'Document Review';
    }

    get showGeneralContractReviewDetails() {
        return this.intakeRecord.BUS_Assistance_Type__c === 'General Contract Review';
    }

    get showBusinessPurchaseSaleDetails() {
        return this.intakeRecord.BUS_Assistance_Type__c === 'Purchase/Sale of Business';
    }

    get showContractDraftingOther() {
        return this.intakeRecord.BUS_Contract_Draft_Type__c === 'Other';
    }

    get showPurchaseSaleInclusionsOther() {
        return this.selectedBusinessInclusions && this.selectedBusinessInclusions.includes('Other');
    }

    // Guardianship/Conservatorship conditional fields
    get showGCSpecificAssistance() {
        return this.selectedGCInvolvementTypes && 
               (this.selectedGCInvolvementTypes.includes('Already appointed as a Guardian') ||
                this.selectedGCInvolvementTypes.includes('Already appointed as a Conservator') ||
                this.selectedGCInvolvementTypes.includes('Already appointed as both a Guardian and Conservator'));
    }

    get showGCDiagnosisDetails() {
        return this.intakeRecord.GC_Ward_Formally_Diagnosed__c === 'Yes';
    }

    get showGCEmergencyDetails() {
        return this.intakeRecord.GC_Is_Emergency_Situation__c === 'Yes';
    }

    get showGCRealEstateDetails() {
        return this.intakeRecord.GC_Ward_Owns_Real_Estate_CO__c === 'Yes';
    }

    get showGCIncomeDetails() {
        return this.intakeRecord.GC_Ward_Has_Income_Source__c === 'Yes';
    }

    get showGCCashAssetDetails() {
        return this.intakeRecord.GC_Ward_Has_Cash_Assets__c === 'Yes';
    }

    get showGCLiabilityDetails() {
        return this.intakeRecord.GC_Ward_Has_Liabilities__c === 'Yes';
    }

    get showGCExistingProceedingsDetails() {
        return this.intakeRecord.GC_Respondent_In_Existing_Proceedings__c === 'Yes';
    }

    get showGCTransferQuestion() {
        return this.intakeRecord.GC_Respondent_Prev_Appointed_Other_State__c === 'Yes';
    }

    get showGCChildrenMinors() {
        return this.intakeRecord.GC_Ward_Has_Children__c === 'Yes';
    }

    get showGCSiblingContact() {
        return this.intakeRecord.GC_Ward_Living_Siblings__c === 'Yes';
    }

    get showGCAssistanceOther() {
        return this.selectedGCAssistanceTypes && this.selectedGCAssistanceTypes.includes('Other');
    }

    // Closing Questions conditional fields
    get showDocumentReviewSpecify() {
        return this.intakeRecord.CQ_Docs_For_Review__c === 'Yes';
    }

    // --- Picklist Options ---
    get yesNoOptions() {
        return [
            { label: 'Yes', value: 'Yes' },
            { label: 'No', value: 'No' }
        ];
    }

    get legalMatterTypeOptions() {
        return [
            { label: 'Criminal Law', value: 'Criminal Law' },
            { label: 'Family Law', value: 'Family Law' },
            { label: 'Probate/Estate Planning', value: 'Probate/Estate Planning' },
            { label: 'Real Estate', value: 'Real Estate' },
            { label: 'Personal Injury', value: 'Personal Injury' },
            { label: 'Civil Litigation', value: 'Civil Litigation' },
            { label: 'Employment Law', value: 'Employment Law' },
            { label: 'Business Law', value: 'Business Law' },
            { label: 'Landlord-Tenant Dispute', value: 'Landlord-Tenant Dispute' },
            { label: 'Defamation', value: 'Defamation' },
            { label: 'HOA', value: 'HOA' },
            { label: 'Construction', value: 'Construction' },
            { label: 'Guardianship/Conservatorship', value: 'Guardianship/Conservatorship' },
            { label: 'Other', value: 'Other' }
        ];
    }

    get preferredCommunicationOptions() {
        return [
            { label: 'Email', value: 'Email' },
            { label: 'Phone', value: 'Phone' },
            { label: 'Text', value: 'Text' }
        ];
    }

    get howDidYouHearOptions() {
        return [
            { label: 'Google Search', value: 'Google Search' },
            { label: 'Advertisement', value: 'Advertisement' },
            { label: 'Referral', value: 'Referral' },
            { label: 'Social Media', value: 'Social Media' },
            { label: 'Other', value: 'Other' }
        ];
    }

    get reasonNoHireOptions() {
        return [
            { label: 'Cost', value: 'Cost' },
            { label: 'Lack of experience in this area of law', value: 'Lack of experience' },
            { label: 'Poor communication', value: 'Poor communication' },
            { label: 'Other', value: 'Other' }
        ];
    }

    // Criminal Law options
    get chargeClassificationOptions() {
        return [
            { label: 'Felony', value: 'Felony' },
            { label: 'Misdemeanor', value: 'Misdemeanor' },
            { label: 'Traffic Infraction', value: 'Traffic Infraction' }
        ];
    }

    get investigatingAgencyOptions() {
        return [
            { label: 'Police Department', value: 'Police Department' },
            { label: 'District Attorney\'s Office', value: 'District Attorney\'s Office' },
            { label: 'Other', value: 'Other' }
        ];
    }

    get caseStatusOptions() {
        return [
            { label: 'Pending Charges', value: 'Pending Charges' },
            { label: 'Probation Revocation', value: 'Probation Revocation' },
            { label: 'Appeal', value: 'Appeal' },
            { label: 'Record Sealing', value: 'Record Sealing' },
            { label: 'Other', value: 'Other' }
        ];
    }

    get caseInvolvementTypeOptions() {
        return [
            { label: 'Domestic Violence', value: 'Domestic Violence' },
            { label: 'Juvenile Offense', value: 'Juvenile Offense' },
            { label: 'Sex Offense', value: 'Sex Offense' },
            { label: 'Drug Offense', value: 'Drug Offense' },
            { label: 'DUI/DWI', value: 'DUI/DWI' },
            { label: 'Death or Serious Bodily Injury', value: 'Death or Serious Bodily Injury' },
            { label: 'Other', value: 'Other' }
        ];
    }

    get duiPulledOverReasonOptions() {
        return [
            { label: 'Speeding', value: 'Speeding' },
            { label: 'Reckless Driving', value: 'Reckless Driving' },
            { label: 'Other', value: 'Other' }
        ];
    }

    // Domestic Violence options
    get abuseTypeOptions() {
        return [
            { label: 'Physical abuse', value: 'Physical abuse' },
            { label: 'Emotional or psychological abuse', value: 'Emotional or psychological abuse' },
            { label: 'Verbal abuse', value: 'Verbal abuse' },
            { label: 'Sexual abuse or assault', value: 'Sexual abuse or assault' },
            { label: 'Financial abuse', value: 'Financial abuse' },
            { label: 'Stalking or harassment', value: 'Stalking or harassment' },
            { label: 'Other', value: 'Other' }
        ];
    }

    get perpetratorIdentityOptions() {
        return [
            { label: 'Current spouse/partner', value: 'Current spouse/partner' },
            { label: 'Former spouse/partner', value: 'Former spouse/partner' },
            { label: 'Family member', value: 'Family member' },
            { label: 'Friend', value: 'Friend' },
            { label: 'Other', value: 'Other' }
        ];
    }

    get relationshipToPerpetratorOptions() {
        return [
            { label: 'Partner/spouse', value: 'Partner/spouse' },
            { label: 'Ex-partner/spouse', value: 'Ex-partner/spouse' },
            { label: 'Family member', value: 'Family member' },
            { label: 'Other', value: 'Other' }
        ];
    }

    get violencePastOngoingOptions() {
        return [
            { label: 'Past', value: 'Past' },
            { label: 'Ongoing', value: 'Ongoing' }
        ];
    }

    get supportServicesOptions() {
        return [
            { label: 'Domestic violence shelter', value: 'Domestic violence shelter' },
            { label: 'Therapy or counseling', value: 'Therapy or counseling' },
            { label: 'Legal aid services', value: 'Legal aid services' },
            { label: 'Medical treatment or health services', value: 'Medical treatment or health services' },
            { label: 'Child protection services', value: 'Child protection services' },
            { label: 'Other', value: 'Other' }
        ];
    }

    // Family Law options
    get marriageTypeOptions() {
        return [
            { label: 'Traditional', value: 'Traditional' },
            { label: 'Common Law', value: 'Common Law' }
        ];
    }

    get seekingActionOptions() {
        return [
            { label: 'Divorce', value: 'Divorce' },
            { label: 'Legal Separation', value: 'Legal Separation' }
        ];
    }

    get divorceContestedOptions() {
        return [
            { label: 'Contested', value: 'Contested' },
            { label: 'Uncontested', value: 'Uncontested' }
        ];
    }

    // Probate options
    get probateCaseStageOptions() {
        return [
            { label: 'Opened', value: 'Opened' },
            { label: 'Petition pending', value: 'Petition pending' },
            { label: 'Administration stage', value: 'Administration stage' },
            { label: 'Distribution stage', value: 'Distribution stage' },
            { label: 'Closed', value: 'Closed' }
        ];
    }

    get decedentAssetTypeOptions() {
        return [
            { label: 'Bank accounts', value: 'Bank accounts' },
            { label: 'Cars/vehicles', value: 'Cars/vehicles' },
            { label: 'Home', value: 'Home' },
            { label: 'Stocks, bonds, annuities', value: 'Stocks, bonds, annuities' },
            { label: 'Trusts', value: 'Trusts' },
            { label: 'Other real estate inside of Colorado', value: 'Other real estate inside of Colorado' },
            { label: 'Other real estate outside of Colorado', value: 'Other real estate outside of Colorado' },
            { label: 'Other', value: 'Other' }
        ];
    }

    get estatePlanDocumentOptions() {
        return [
            { label: 'Will', value: 'Will' },
            { label: 'Trust', value: 'Trust' },
            { label: 'Power of Attorney', value: 'Power of Attorney' },
            { label: 'Other', value: 'Other' }
        ];
    }

    // Real Estate options
    get reAssistanceTypeOptions() {
        return [
            { label: 'Purchase', value: 'Purchase' },
            { label: 'Sale', value: 'Sale' },
            { label: 'Lease', value: 'Lease' },
            { label: 'Document Drafting or Review', value: 'Document Drafting or Review' },
            { label: 'Dispute Resolution', value: 'Dispute Resolution' },
            { label: 'Other', value: 'Other' }
        ];
    }

    get propertyTypeOptions() {
        return [
            { label: 'Residential', value: 'Residential' },
            { label: 'Commercial', value: 'Commercial' },
            { label: 'Vacant Land', value: 'Vacant Land' },
            { label: 'Mixed-Use', value: 'Mixed-Use' }
        ];
    }

    get financingTypeOptions() {
        return [
            { label: 'Cash', value: 'Cash' },
            { label: 'Bank/Mortgage Lender', value: 'Bank/Mortgage Lender' },
            { label: 'Seller Financing', value: 'Seller Financing' },
            { label: 'Other', value: 'Other' }
        ];
    }

    get leaseTypeOptions() {
        return [
            { label: 'Residential Lease', value: 'Residential Lease' },
            { label: 'Commercial Lease', value: 'Commercial Lease' },
            { label: 'Agricultural Lease', value: 'Agricultural Lease' }
        ];
    }

    get disputeNatureOptions() {
        return [
            { label: 'Non-Payment of Rent', value: 'Non-Payment of Rent' },
            { label: 'Lease Violations', value: 'Lease Violations' },
            { label: 'Property Defects', value: 'Property Defects' },
            { label: 'Contract Breach', value: 'Contract Breach' },
            { label: 'Other', value: 'Other' }
        ];
    }

    // Personal Injury options
    get piYourRoleOptions() {
        return [
            { label: 'Driver', value: 'Driver' },
            { label: 'Passenger', value: 'Passenger' },
            { label: 'Pedestrian', value: 'Pedestrian' },
            { label: 'Other', value: 'Other' }
        ];
    }

    get damagesSoughtOptions() {
        return [
            { label: 'Medical Bills', value: 'Medical Bills' },
            { label: 'Lost Wages', value: 'Lost Wages' },
            { label: 'Pain and Suffering', value: 'Pain and Suffering' },
            { label: 'Property Damage', value: 'Property Damage' },
            { label: 'Emotional Distress', value: 'Emotional Distress' },
            { label: 'Other', value: 'Other' }
        ];
    }

    // Civil Litigation options
    get claimBasisOptions() {
        return [
            { label: 'Breach of Contract', value: 'Breach of Contract' },
            { label: 'Property Damage', value: 'Property Damage' },
            { label: 'Civil Theft', value: 'Civil Theft' },
            { label: 'Fraud', value: 'Fraud' },
            { label: 'Other', value: 'Other' }
        ];
    }

    get plaintiffDefendantOptions() {
        return [
            { label: 'Plaintiff', value: 'Plaintiff' },
            { label: 'Defendant', value: 'Defendant' }
        ];
    }

    // Employment Law options
    get employmentIssueTypeOptions() {
        return [
            { label: 'Wrongful Termination', value: 'Wrongful Termination' },
            { label: 'Discrimination', value: 'Discrimination' },
            { label: 'Harassment', value: 'Harassment' },
            { label: 'Retaliation', value: 'Retaliation' },
            { label: 'Wage/Hour Violations', value: 'Wage/Hour Violations' },
            { label: 'Family Medical Leave Act (FMLA) Violations', value: 'FMLA Violations' },
            { label: 'Unsafe Work Conditions', value: 'Unsafe Work Conditions' },
            { label: 'Other', value: 'Other' }
        ];
    }

    get issueStageOptions() {
        return [
            { label: 'Informal Complaint', value: 'Informal Complaint' },
            { label: 'Formal Complaint Filed', value: 'Formal Complaint Filed' },
            { label: 'Negotiations or Settlement Discussions', value: 'Negotiations or Settlement Discussions' },
            { label: 'Lawsuit Filed', value: 'Lawsuit Filed' }
        ];
    }

    get desiredOutcomeOptions() {
        return [
            { label: 'Compensation for Lost Wages', value: 'Compensation for Lost Wages' },
            { label: 'Reinstatement of Position', value: 'Reinstatement of Position' },
            { label: 'Policy Change at the Workplace', value: 'Policy Change at the Workplace' },
            { label: 'Other', value: 'Other' }
        ];
    }

    // Landlord/Tenant options
    get ltRoleOptions() {
        return [
            { label: 'Landlord', value: 'Landlord' },
            { label: 'Tenant', value: 'Tenant' }
        ];
    }

    // ADDED: Options for LT_Lease_Term_Type__c
    get ltLeaseTermTypeOptions() {
        return [
            { label: 'Fixed Term', value: 'Fixed Term' },
            { label: 'Month-to-Month', value: 'Month-to-Month' },
            { label: 'Other', value: 'Other' }
        ];
    }

    // Business options
    get businessAssistanceTypeOptions() {
        return [
            { label: 'Business Partner Dispute', value: 'Business Partner Dispute' },
            { label: 'Contract Drafting', value: 'Contract Drafting' },
            { label: 'Creation of Business', value: 'Creation of Business' },
            { label: 'Dissolution of Business', value: 'Dissolution of Business' },
            { label: 'Document Review', value: 'Document Review' },
            { label: 'General Contract Review', value: 'General Contract Review' },
            { label: 'Purchase/Sale of Business', value: 'Purchase/Sale of Business' }
        ];
    }

    get contractTypeOptions() {
        return [
            { label: 'Services Agreement', value: 'Services Agreement' },
            { label: 'Employment Agreement', value: 'Employment Agreement' },
            { label: 'Settlement Agreement', value: 'Settlement Agreement' },
            { label: 'Other', value: 'Other' }
        ];
    }

    get disputeAssistanceOptions() {
        return [
            { label: 'Demand letter', value: 'Demand letter' },
            { label: 'Substantial document review and correspondence/negotiation', value: 'Document review and negotiation' },
            { label: 'Lawsuit assistance', value: 'Lawsuit assistance' }
        ];
    }

    get purchaseOrSaleOptions() {
        return [
            { label: 'Purchase', value: 'Purchase' },
            { label: 'Sale', value: 'Sale' }
        ];
    }

    get businessInclusionsOptions() {
        return [
            { label: 'Client list', value: 'Client list' },
            { label: 'Equipment/office furnishings', value: 'Equipment/office furnishings' },
            { label: 'Lease take-over', value: 'Lease take-over' },
            { label: 'Other', value: 'Other' }
        ];
    }

    // ADDED: Options for various picklists missing them
    get defamationStatusOptions() {
        return [
            { label: 'Victim of defamation', value: 'Victim of defamation' },
            { label: 'Accused of defaming others', value: 'Accused of defaming others' }
        ];
    }

    get constructionTypeOptions() {
        return [
            { label: 'Residential', value: 'Residential' },
            { label: 'Commercial', value: 'Commercial' },
            { label: 'Other', value: 'Other' }
        ];
    }

    get constructionIssueOptions() {
        return [
            { label: 'Construction Defect', value: 'Construction Defect' },
            { label: 'Contract Dispute', value: 'Contract Dispute' },
            { label: 'Payment Issue', value: 'Payment Issue' },
            { label: 'Other', value: 'Other' }
        ];
    }

    get constructionDefectOptions() {
        return [
            { label: 'Structural', value: 'Structural' },
            { label: 'Mechanical', value: 'Mechanical' },
            { label: 'Electrical', value: 'Electrical' },
            { label: 'Plumbing', value: 'Plumbing' },
            { label: 'Other', value: 'Other' }
        ];
    }
    
    get defectSeverityOptions() {
        return [
            { label: 'Minor', value: 'Minor' },
            { label: 'Moderate', value: 'Moderate' },
            { label: 'Severe', value: 'Severe' }
        ];
    }

    get gcInvolvementOptions() {
        return [
            { label: 'Seeking to become a Guardian', value: 'Seeking to become a Guardian' },
            { label: 'Seeking to become a Conservator', value: 'Seeking to become a Conservator' },
            { label: 'Already appointed as a Guardian', value: 'Already appointed as a Guardian' },
            { label: 'Already appointed as a Conservator', value: 'Already appointed as a Conservator' }
        ];
    }

    get natureOfMatterOptions() {
        return [
            { label: 'Consultation', value: 'Consultation' },
            { label: 'Representation', value: 'Representation' },
            { label: 'Document Review', value: 'Document Review' },
            { label: 'Other', value: 'Other' }
        ];
    }

    get additionalContactsOptions() {
        // This would typically be populated from a data source,
        // but for now, we can use a placeholder or leave it empty.
        return [
            { label: 'Spouse', value: 'Spouse' },
            { label: 'Witness', value: 'Witness' },
            { label: 'Other Party', value: 'Other Party' }
        ];
    }


    // --- Event Handlers ---
    toggleFormVisibility() {
        this.isFormLaunched = !this.isFormLaunched;
        if (this.isFormLaunched) {
            this.currentSection = 1;
        }
        this.updateProgress();
    }

    handleInputChange(event) {
        const fieldName = event.target.name;
        let value = event.target.value;

        if (event.target.type === 'checkbox') {
            value = event.target.checked;
        }
        if (event.detail && typeof event.detail.value !== 'undefined') {
            value = event.detail.value;
        }

        this.intakeRecord = { ...this.intakeRecord, [fieldName]: value };

        // Clear dependent fields based on selections
        this.clearDependentFields(fieldName, value);
        
        if (this.isFormLaunched) {
            this.updateProgress();
        }
    }

    handleLegalMatterChange(event) {
        this.selectedLegalMatterTypes = event.detail.value;
        this.intakeRecord.Legal_Matter_Type__c = this.selectedLegalMatterTypes.join(';');

        // Clear fields for unselected legal matters
        if (!this.selectedLegalMatterTypes.includes('Other')) {
            this.intakeRecord.Legal_Matter_Type_Other_Specify__c = '';
        }
        
        this.updateProgress();
    }

    // Multi-select handlers
    handleCaseInvolvementChange(event) {
        this.handleMultiSelectChange(event, 'CL_Case_Involvement_Types__c', 'selectedCaseInvolvementTypes');
        if (!this.selectedCaseInvolvementTypes.includes('Other')) {
            this.intakeRecord.CL_Case_Involvement_Other_Specify__c = '';
        }
    }

    handleAbuseTypeChange(event) {
        this.handleMultiSelectChange(event, 'DV_Types_Of_Abuse__c', 'selectedAbuseTypes');
        if (!this.selectedAbuseTypes.includes('Other')) {
            this.intakeRecord.DV_Abuse_Type_Other_Specify__c = '';
        }
    }

    handleSupportServicesChange(event) {
        this.handleMultiSelectChange(event, 'DV_Receiving_Support_Services__c', 'selectedSupportServices');
        if (!this.selectedSupportServices.includes('Other')) {
            this.intakeRecord.DV_Support_Services_Other__c = '';
        }
    }

    handleDamagesSoughtChange(event) {
        this.handleMultiSelectChange(event, 'PI_Damages_Sought__c', 'selectedDamagesSought');
        if (!this.selectedDamagesSought.includes('Other')) {
            this.intakeRecord.PI_Damages_Sought_Other_Specify__c = '';
        }
    }

    handleEPDocumentsChange(event) {
        this.handleMultiSelectChange(event, 'EP_Documents_Needed__c', 'selectedEPDocuments');
        if (!this.selectedEPDocuments.includes('Other')) {
            this.intakeRecord.EP_Documents_Needed_Other_Specify__c = '';
        }
    }

    handleBusinessInclusionsChange(event) {
        this.handleMultiSelectChange(event, 'BUS_Purchase_Sale_Inclusions__c', 'selectedBusinessInclusions');
        if (!this.selectedBusinessInclusions.includes('Other')) {
            this.intakeRecord.BUS_Purchase_Sale_Inclusions_Other__c = '';
        }
    }

    handleStatementContentChange(event) {
        this.handleMultiSelectChange(event, 'DEF_Statement_Content_Types__c', 'selectedStatementContentTypes');
        if (!this.selectedStatementContentTypes.includes('Other')) {
            this.intakeRecord.DEF_Statement_Content_Other_Specify__c = '';
        }
    }

    handleReputationEffectChange(event) {
        this.handleMultiSelectChange(event, 'DEF_P_Reputation_Affected_How__c', 'selectedReputationEffects');
        if (!this.selectedReputationEffects.includes('Other')) {
            this.intakeRecord.DEF_P_Reputation_Affected_Other__c = '';
        }
    }

    handleResponseActionChange(event) {
        this.handleMultiSelectChange(event, 'DEF_P_Actions_In_Response__c', 'selectedResponseActions');
        if (!this.selectedResponseActions.includes('Other')) {
            this.intakeRecord.DEF_P_Actions_Response_Other__c = '';
        }
    }

    handleConstructionDefectChange(event) {
        this.handleMultiSelectChange(event, 'CONST_Defect_Types__c', 'selectedConstructionDefects');
        if (!this.selectedConstructionDefects.includes('Other')) {
            this.intakeRecord.CONST_Defect_Types_Other__c = '';
        }
    }

    handleGCAssistanceChange(event) {
        this.handleMultiSelectChange(event, 'GC_Assistance_Needed_Types__c', 'selectedGCAssistanceTypes');
        if (!this.selectedGCAssistanceTypes.includes('Other')) {
            this.intakeRecord.GC_Assistance_Needed_Other_Specify__c = '';
        }
    }

    handleGCInvolvementChange(event) {
        this.handleMultiSelectChange(event, 'GC_Involvement_Type__c', 'selectedGCInvolvementTypes');
    }

    // ADDED: Handler for new multi-select field
    handleAdditionalContactsChange(event) {
        this.handleMultiSelectChange(event, 'Additional_Contacts__c', 'selectedAdditionalContacts');
    }

    handleMultiSelectChange(event, fieldName, trackingProperty) {
        const selectedValues = event.detail.value;
        this[trackingProperty] = selectedValues;
        this.intakeRecord[fieldName] = selectedValues.join(';');
        this.updateProgress();
    }

    clearDependentFields(fieldName, value) {
        // Implement comprehensive field clearing logic
        // This is a simplified version - expand as needed
        const clearingRules = {
            'How_Did_You_Hear__c': {
                'Advertisement': ['How_Hear_Referral_Specify__c', 'How_Hear_Social_Media_Specify__c', 'How_Hear_Other_Specify__c'],
                'Referral': ['How_Hear_Advertisement_Specify__c', 'How_Hear_Social_Media_Specify__c', 'How_Hear_Other_Specify__c'],
                'Social Media': ['How_Hear_Advertisement_Specify__c', 'How_Hear_Referral_Specify__c', 'How_Hear_Other_Specify__c'],
                'Other': ['How_Hear_Advertisement_Specify__c', 'How_Hear_Referral_Specify__c', 'How_Hear_Social_Media_Specify__c'],
                'Google Search': ['How_Hear_Advertisement_Specify__c', 'How_Hear_Referral_Specify__c', 'How_Hear_Social_Media_Specify__c', 'How_Hear_Other_Specify__c']
            }
            // Add more clearing rules as needed
        };

        if (clearingRules[fieldName] && clearingRules[fieldName][value]) {
            clearingRules[fieldName][value].forEach(field => {
                this.intakeRecord[field] = '';
            });
        }
    }

    updateProgress() {
        if (!this.isFormLaunched) {
            this.progressValue = 0;
            this.progressPercentageText = '0% Complete';
            return;
        }

        let totalFields = 0;
        let filledFields = 0;

        // Count all visible fields across all sections
        const visibleFields = this.getVisibleFields();
        totalFields = visibleFields.length;
        
        visibleFields.forEach(fieldName => {
            if (this.isFieldFilled(fieldName)) {
                filledFields++;
            }
        });

        this.progressValue = totalFields > 0 ? Math.round((filledFields / totalFields) * 100) : 0;
        this.progressPercentageText = `${this.progressValue}% Complete`;
    }

    getVisibleFields() {
        let fields = [];

        // Always add Section 1 fields if on that section
        if (this.currentSection === 1) {
            fields.push(...this.getSection1Fields());
        }

        // Add fields for sections 2-15 based on legal matter selection and current section
        if (this.currentSection === 2 && this.showCriminalLawSection) {
            fields.push(...this.getCriminalLawFields());
        }
        if (this.currentSection === 3 && this.showFamilyLawSection) {
            fields.push(...this.getFamilyLawFields());
        }
        if (this.currentSection === 4 && this.showProbateSection) {
            fields.push(...this.getProbateFields());
        }
        if (this.currentSection === 5 && this.showRealEstateSection) {
            fields.push(...this.getRealEstateFields());
        }
        if (this.currentSection === 6 && this.showPersonalInjurySection) {
            fields.push(...this.getPersonalInjuryFields());
        }
        if (this.currentSection === 7 && this.showCivilLitigationSection) {
            fields.push(...this.getCivilLitigationFields());
        }
        if (this.currentSection === 8 && this.showEmploymentLawSection) {
            fields.push(...this.getEmploymentLawFields());
        }
        if (this.currentSection === 9 && this.showLandlordTenantSection) {
            fields.push(...this.getLandlordTenantFields());
        }
        if (this.currentSection === 10 && this.showDefamationSection) {
            fields.push(...this.getDefamationFields());
        }
        if (this.currentSection === 11 && this.showHOASection) {
            fields.push(...this.getHOAFields());
        }
        if (this.currentSection === 12 && this.showConstructionSection) {
            fields.push(...this.getConstructionFields());
        }
        if (this.currentSection === 13 && this.showBusinessLawSection) {
            fields.push(...this.getBusinessFields());
        }
        if (this.currentSection === 14 && this.showGuardianshipSection) {
            fields.push(...this.getGuardianshipFields());
        }
        if (this.currentSection === 15) {
            fields.push(...this.getClosingFields());
        }

        return fields;
    }

    getSection1Fields() {
        let fields = [
            'Preferred_Pronouns__c',
            'Mailing_Address_Different__c',
            'Can_Email_Follow_Up__c',
            'Work_Phone_Custom__c',
            'Can_Text_You__c',
            'Preferred_Method_Communication__c',
            'Preferred_Language__c',
            'Date_Of_Birth__c',
            'Occupation_Employer__c',
            'How_Did_You_Hear__c',
            'Worked_With_Us_Before__c',
            'Preferred_Office_Location__c',
            'Require_Appointment_Accommodations__c',
            'Specific_Availability_Times_Days__c',
            'Other_Parties_Involved__c',
            'Legal_Matters_With_Parties_Before__c',
            'Aware_Of_Conflicts__c',
            'Represented_Other_Parties_In_Case__c',
            'Spoken_With_Other_Attorneys__c',
            'Currently_Represented__c',
            'Legal_Matter_Type__c',
            'Issue_Description__c',
            'Desired_Outcome__c'
        ];

        // Add conditional fields
        if (this.showHowHearAdvertisementSpecify) fields.push('How_Hear_Advertisement_Specify__c');
        if (this.showHowHearReferralSpecify) fields.push('How_Hear_Referral_Specify__c');
        if (this.showHowHearSocialMediaSpecify) fields.push('How_Hear_Social_Media_Specify__c');
        if (this.showHowHearOtherSpecify) fields.push('How_Hear_Other_Specify__c');
        if (this.showPreviousAttorneyOffice) fields.push('Previous_Attorney_Office__c');
        if (this.showAccommodationsSpecify) fields.push('Appointment_Accommodations_Specify__c');
        if (this.showPriorAttorneyDetails) {
            fields.push('Prior_Attorney_Name_Firm__c', 'Reason_No_Hire_Prior_Attorney__c');
            if (this.showPriorAttorneyCostSpecify) fields.push('Prior_Attorney_Cost_Specify__c');
            if (this.showPriorAttorneyOtherSpecify) fields.push('Prior_Attorney_Reason_Other_Specify__c');
        }
        if (this.showCurrentlyRepresentedDetails) fields.push('Reason_Seeking_New_Attorney__c');
        if (this.showLegalMatterOtherSpecify) fields.push('Legal_Matter_Type_Other_Specify__c');

        return fields;
    }

    // Add methods for each section's fields...
    getCriminalLawFields() {
        let fields = [
            'CL_Charges_Allegations__c',
            'CL_Charge_Classification__c',
            'CL_Incident_Location_City_County__c',
            'CL_Incident_Location_State__c',
            'CL_Incident_Date__c',
            'CL_Investigating_Agency__c',
            'CL_Case_Filed__c',
            'CL_Case_Status__c',
            'CL_In_Custody__c',
            'CL_Needs_Bail_Bond_Help__c',
            'CL_Case_Involvement_Types__c'
        ];

        // Add conditional fields
        if (this.showAgencyPoliceSpecify) fields.push('CL_Agency_Police_Specify__c');
        if (this.showAgencyOtherSpecify) fields.push('CL_Agency_Other_Specify__c');
        if (this.showCaseFiledDetails) {
            fields.push('CL_Case_Number__c', 'CL_Court_Location__c');
        }
        if (this.showMatterUnderInvestigation) fields.push('CL_Under_Investigation__c');
        if (this.showCaseStatusOtherSpecify) fields.push('CL_Case_Status_Other_Specify__c');
        if (this.showCaseInvolvementOtherSpecify) fields.push('CL_Case_Involvement_Other_Specify__c');

        // DUI/DWI fields
        if (this.showDUIDWISection) {
            fields.push(
                'CL_DUI_Pulled_Over_Reason__c',
                'CL_DUI_Tests_Conducted__c',
                'CL_DUI_Test_Results__c',
                'CL_DUI_Prior_Convictions__c'
            );
            if (this.showDUIPulledOverOtherSpecify) fields.push('CL_DUI_Pulled_Over_Other_Specify__c');
            if (this.showDUIPriorConvictionsDetails) fields.push('CL_DUI_Prior_Convictions_Details__c');
        }

        // Record Sealing fields
        if (this.showRecordSealingSection) {
            fields.push(
                'CL_Charges_To_Seal__c',
                'CL_Case_Dismissed_Acquitted__c',
                'CL_Completed_Court_Conditions__c'
            );
        }

        // Domestic Violence fields
        if (this.showDomesticViolenceSection) {
            fields.push('DV_Physically_Harmed__c');
            if (this.showDVRecentIncidentDetails) {
                fields.push(
                    'DV_Recent_Incident_Date__c',
                    'DV_Recent_Incident_Location__c',
                    'DV_Recent_Incident_Description__c'
                );
            }
            // Add all other DV fields based on conditionals...
        }

        return fields;
    }

    // Continue with similar methods for all other sections...

    isFieldFilled(fieldName) {
        const value = this.intakeRecord[fieldName];
        if (Array.isArray(value)) return value.length > 0;
        if (fieldName.includes('__c') && fieldName.includes('Date')) {
            return value !== null && value !== undefined && value !== '';
        }
        return value !== null && value !== undefined && value !== '' && value !== false;
    }

    async handleSave() {
        this.isLoading = true;
        try {
            // Validate required fields
            if (!this.validateRequiredFields()) {
                this.isLoading = false;
                return;
            }

            // Prepare record for save
            const recordToSave = { ...this.intakeRecord };
            
            // Ensure Lead__c is set
            if (!recordToSave.Lead__c && this.leadId) {
                recordToSave.Lead__c = this.leadId;
            }
            
            // Save the record
            const savedId = await saveIntakeRecord({ intakeRecord: recordToSave });
            
            this.showToast('Success', 'Intake record saved successfully', 'success');
            
            // Fire event to parent component
            const savedEvent = new CustomEvent('intakesaved', {
                detail: { intakeId: savedId }
            });
            this.dispatchEvent(savedEvent);
            
        } catch (error) {
            console.error('Save error:', error);
            this.showToast('Error', 'Error saving intake: ' + (error.body ? error.body.message : error.message), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    validateRequiredFields() {
        const errors = [];
        
        // Always required
        if (!this.selectedLegalMatterTypes || this.selectedLegalMatterTypes.length === 0) {
            errors.push('Please select at least one legal matter type');
        }
        
        if (!this.intakeRecord.Issue_Description__c) {
            errors.push('Please provide a description of the issue');
        }
        
        // Section-specific validations
        if (this.showBusinessLawSection && this.currentSection === 13 && !this.intakeRecord.BUS_Assistance_Type__c) {
            errors.push('Please select the type of business assistance needed');
        }
        
        if (errors.length > 0) {
            this.showToast('Validation Error', errors.join('. '), 'error');
            return false;
        }
        
        return true;
    }

    showToast(title, message, variant) {
        const evt = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        });
        this.dispatchEvent(evt);
    }
}