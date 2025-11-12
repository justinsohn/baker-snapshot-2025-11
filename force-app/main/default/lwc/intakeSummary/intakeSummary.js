import { LightningElement, api, wire, track } from 'lwc';
import { getRecord } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getActiveUsers from '@salesforce/apex/IntakeSummaryEmailController.getActiveUsers';
import sendIntakeSummaryEmail from '@salesforce/apex/IntakeSummaryEmailController.sendIntakeSummaryEmail';

const FIELDS = ['Lead.Intake_Form_JSON__c', 'Lead.Name'];

// Import Apex methods to get intake record with additional details
import getIntakesByLead from '@salesforce/apex/ClientIntakeController.getIntakesByLead';
import getFullIntakeRecord from '@salesforce/apex/ClientIntakeController.getFullIntakeRecord';

export default class IntakeSummary extends LightningElement {
    @api recordId;
    
    intakeData = {};
    additionalData = {};
    leadName = '';
    hasData = false;
    error = null;
    
    // Email functionality
    @track showEmailModal = false;
    @track availableUsers = [];
    @track selectedUserIds = [];
    @track emailSubject = '';
    @track emailBody = '';
    @track isEmailLoading = false;

    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    wiredLead({ error, data }) {
        if (data) {
            this.error = null;
            this.leadName = data.fields.Name.value;
            
            if (data.fields.Intake_Form_JSON__c.value) {
                try {
                    this.intakeData = JSON.parse(data.fields.Intake_Form_JSON__c.value);
                    this.hasData = true;
                } catch (e) {
                    this.error = 'Invalid JSON data in intake form';
                    this.hasData = false;
                }
            } else {
                this.hasData = false;
            }
        } else if (error) {
            this.error = 'Error loading lead data: ' + (error.body?.message || error.message);
            this.hasData = false;
        }
        
        // Also load additional intake details if we have data
        if (this.hasData && this.recordId) {
            this.loadAdditionalIntakeData();
        }
    }

    // Load additional intake details from Client_Intake__c
    loadAdditionalIntakeData() {
        // First get the list of intakes to find the most recent one
        getIntakesByLead({ leadId: this.recordId })
            .then(result => {
                if (result && result.length > 0) {
                    // Get the most recent intake record ID
                    const latestIntakeId = result[0].Id;
                    // Now get the full record with JSON field
                    return getFullIntakeRecord({ intakeId: latestIntakeId });
                }
                return null;
            })
            .then(fullIntakeRecord => {
                if (fullIntakeRecord && fullIntakeRecord.Intake_Details_JSON__c) {
                    try {
                        this.additionalData = JSON.parse(fullIntakeRecord.Intake_Details_JSON__c);
                    } catch (e) {
                        console.error('Error parsing additional intake details:', e);
                        this.additionalData = {};
                    }
                }
            })
            .catch(error => {
                console.error('Error loading additional intake data:', error);
                this.additionalData = {};
            });
    }

    // Helper method to get field value from either data source
    getFieldValue(fieldName) {
        return this.intakeData[fieldName] || this.additionalData[fieldName] || '';
    }

    // General Information Getters
    get issueDescription() {
        return this.getFieldValue('Issue_Description__c');
    }

    get desiredOutcome() {
        return this.getFieldValue('Desired_Outcome__c');
    }

    get preferredOfficeLocation() {
        return this.intakeData.Preferred_Office_Location__c || '';
    }

    get accommodationsNeeded() {
        return this.intakeData.Require_Appointment_Accommodations__c === 'Yes' ? 
               (this.intakeData.Appointment_Accommodations_Specify__c || 'Yes') : 'No';
    }

    get availabilityTimes() {
        return this.intakeData.Specific_Availability_Times_Days__c || '';
    }

    get otherPartiesInvolved() {
        return this.intakeData.Other_Parties_Involved__c || '';
    }

    // Additional General Information Fields
    get preferredPronouns() {
        return this.intakeData.Preferred_Pronouns__c || '';
    }

    get canEmailFollowUp() {
        return this.intakeData.Can_Email_Follow_Up__c || '';
    }

    get workPhone() {
        return this.intakeData.Work_Phone_Custom__c || '';
    }

    get canText() {
        return this.intakeData.Can_Text_You__c || '';
    }

    get preferredCommunicationMethod() {
        return this.intakeData.Preferred_Method_Communication__c || '';
    }

    get preferredLanguage() {
        return this.intakeData.Preferred_Language__c || '';
    }

    get dateOfBirth() {
        return this.intakeData.Date_Of_Birth__c || '';
    }

    get occupationEmployer() {
        return this.intakeData.Occupation_Employer__c || '';
    }

    get howDidYouHear() {
        return this.intakeData.How_Did_You_Hear__c || '';
    }

    get howHearDetails() {
        const details = [];
        if (this.intakeData.How_Hear_Advertisement_Specify__c) details.push(`Advertisement: ${this.intakeData.How_Hear_Advertisement_Specify__c}`);
        if (this.intakeData.How_Hear_Referral_Specify__c) details.push(`Referral: ${this.intakeData.How_Hear_Referral_Specify__c}`);
        if (this.intakeData.How_Hear_Social_Media_Specify__c) details.push(`Social Media: ${this.intakeData.How_Hear_Social_Media_Specify__c}`);
        if (this.intakeData.How_Hear_Other_Specify__c) details.push(`Other: ${this.intakeData.How_Hear_Other_Specify__c}`);
        return details.join('; ');
    }

    get workedWithUsBefore() {
        return this.intakeData.Worked_With_Us_Before__c || '';
    }

    get previousAttorneyOffice() {
        return this.intakeData.Previous_Attorney_Office__c || '';
    }

    get legalMattersWithPartiesBefore() {
        return this.intakeData.Legal_Matters_With_Parties_Before__c || '';
    }

    get awareOfConflicts() {
        return this.intakeData.Aware_Of_Conflicts__c || '';
    }

    get representedOtherPartiesInCase() {
        return this.intakeData.Represented_Other_Parties_In_Case__c || '';
    }

    get spokenWithOtherAttorneys() {
        return this.intakeData.Spoken_With_Other_Attorneys__c || '';
    }

    get priorAttorneyNameFirm() {
        return this.intakeData.Prior_Attorney_Name_Firm__c || '';
    }

    get reasonNoHirePriorAttorney() {
        return this.intakeData.Reason_No_Hire_Prior_Attorney__c || '';
    }

    get currentlyRepresented() {
        return this.intakeData.Currently_Represented__c || '';
    }

    get reasonSeekingNewAttorney() {
        return this.intakeData.Reason_Seeking_New_Attorney__c || '';
    }

    // Legal Matter Types
    get legalMatterTypes() {
        if (this.intakeData.Legal_Matter_Type__c) {
            if (Array.isArray(this.intakeData.Legal_Matter_Type__c)) {
                return this.intakeData.Legal_Matter_Type__c.join('; ');
            }
            return this.intakeData.Legal_Matter_Type__c;
        }
        return '';
    }

    get hasLegalMatterOther() {
        return this.intakeData.Legal_Matter_Type_Other_Specify__c ? true : false;
    }

    get legalMatterOther() {
        return this.intakeData.Legal_Matter_Type_Other_Specify__c || '';
    }

    // Section Visibility Getters
    get hasGeneralInfo() {
        return this.issueDescription || this.desiredOutcome;
    }

    get hasContactInfo() {
        return this.preferredPronouns || this.workPhone || this.canText || this.preferredCommunicationMethod || 
               this.preferredLanguage || this.canEmailFollowUp;
    }

    get hasPersonalInfo() {
        return this.dateOfBirth || this.occupationEmployer;
    }

    get hasReferralInfo() {
        return this.howDidYouHear || this.howHearDetails || this.workedWithUsBefore || this.previousAttorneyOffice;
    }

    get hasAttorneyHistory() {
        return this.spokenWithOtherAttorneys || this.priorAttorneyNameFirm || this.reasonNoHirePriorAttorney || 
               this.currentlyRepresented || this.reasonSeekingNewAttorney;
    }

    get hasOfficePreferences() {
        return this.preferredOfficeLocation || this.accommodationsNeeded !== 'No' || this.availabilityTimes;
    }

    get hasConflictsInfo() {
        return this.otherPartiesInvolved || this.legalMattersWithPartiesBefore ||
               this.awareOfConflicts || this.representedOtherPartiesInCase;
    }

    // Criminal Law Getters
    get hasCriminalLaw() {
        return this.legalMatterTypes.includes('Criminal Law') && 
               (this.intakeData.CL_Charges_Allegations__c || this.intakeData.CL_Case_Status__c);
    }

    get criminalCharges() {
        return this.intakeData.CL_Charges_Allegations__c || '';
    }

    get criminalCaseStatus() {
        return this.intakeData.CL_Case_Status__c || '';
    }

    // Family Law Getters
    get hasFamilyLaw() {
        return this.legalMatterTypes.includes('Family Law');
    }

    get familyRelationshipStatus() {
        return this.getFieldValue('FL_Relationship_Status__c');
    }

    get familyChildrenInvolved() {
        return this.getFieldValue('FL_Children_Involved__c');
    }

    // Additional Family Law Fields
    get familyCurrentlyMarried() {
        return this.intakeData.FL_Currently_Married__c || '';
    }

    get familyMarriageDate() {
        return this.intakeData.FL_Marriage_Date__c || '';
    }

    get familyMarriageLocation() {
        return this.intakeData.FL_Marriage_Location__c || '';
    }

    get familySpouseChildrenTogether() {
        return this.intakeData.FL_Spouse_Children_Together__c || '';
    }

    get familyPreviouslyFiledCase() {
        return this.intakeData.FL_Previously_Filed_Family_Case__c || '';
    }

    get familySeekingAction() {
        return this.getFormattedArrayField('FL_Seeking_Action__c');
    }

    get familyPropertyDivision() {
        return this.intakeData.FL_Divorce_Property_Division__c || '';
    }

    get familyPropertyDivisionRealEstate() {
        return this.intakeData.FL_Property_Division_Real_Estate__c || '';
    }

    get familyPropertyDivisionBankAccounts() {
        return this.intakeData.FL_Property_Division_Bank_Accounts__c || '';
    }

    get familyPropertyDivisionOtherAssets() {
        return this.intakeData.FL_Property_Division_Other_Assets__c || '';
    }

    get familyDivorceContestedStatus() {
        return this.intakeData.FL_Divorce_Contested_Status__c || '';
    }

    get familyChildrenDetails() {
        return this.intakeData.FL_Children_Details__c || '';
    }

    get familyExistingCustodyOrders() {
        return this.intakeData.FL_Existing_Custody_Orders__c || '';
    }

    get familyChildSafetyConcerns() {
        return this.intakeData.FL_Child_Safety_Concerns__c || '';
    }

    get familyCPSReportsMade() {
        return this.intakeData.FL_CPS_Reports_Made__c || '';
    }

    get familyCPSReportsDetails() {
        return this.intakeData.FL_CPS_Reports_Details__c || '';
    }

    get familyNeedMediationPrep() {
        return this.intakeData.FL_Need_Mediation_Prep__c || '';
    }

    get familyPreparedForMediation() {
        return this.intakeData.FL_Prepared_For_Mediation__c || '';
    }

    // Employment Law Getters
    get hasEmploymentLaw() {
        return this.legalMatterTypes.includes('Employment Law') && 
               (this.getFieldValue('EMPL_Issue_Type__c') || this.getFieldValue('EMPL_Current_Status__c'));
    }

    get employmentIssueType() {
        return this.getFieldValue('EMPL_Issue_Type__c');
    }

    get employmentCurrentStatus() {
        return this.getFieldValue('EMPL_Current_Status__c');
    }

    // Real Estate Getters
    get hasRealEstate() {
        return this.legalMatterTypes.includes('Real Estate') && 
               (this.getFieldValue('RE_Property_Address__c') || this.getFieldValue('RE_Transaction_Type__c'));
    }

    get realEstateProperty() {
        return this.getFieldValue('RE_Property_Address__c');
    }

    get realEstateTransactionType() {
        return this.getFieldValue('RE_Transaction_Type__c');
    }

    // Business Law Getters
    get hasBusinessLaw() {
        return this.legalMatterTypes.includes('Business Law') && 
               (this.getFieldValue('BUS_Business_Name__c') || this.getFieldValue('BUS_Issue_Type__c'));
    }

    get businessName() {
        return this.getFieldValue('BUS_Business_Name__c');
    }

    get businessIssueType() {
        return this.getFieldValue('BUS_Issue_Type__c');
    }

    // Construction & Construction Defect Getters
    get hasConstruction() {
        return this.legalMatterTypes.includes('Construction & Construction Defect') && 
               (this.getFieldValue('CONST_Property_Type__c') || this.getFieldValue('CONST_Issue_Description__c'));
    }

    get constructionPropertyType() {
        return this.getFieldValue('CONST_Property_Type__c');
    }

    get constructionIssueDescription() {
        return this.getFieldValue('CONST_Issue_Description__c');
    }

    // HOA Getters
    get hasHOA() {
        return this.legalMatterTypes.includes('HOA') && 
               (this.getFieldValue('HOA_Property_Address__c') || this.getFieldValue('HOA_Issue_Type__c'));
    }

    get hoaPropertyAddress() {
        return this.getFieldValue('HOA_Property_Address__c');
    }

    get hoaIssueType() {
        return this.getFieldValue('HOA_Issue_Type__c');
    }

    // Landlord-Tenant Getters
    get hasLandlordTenant() {
        return this.legalMatterTypes.includes('Landlord-Tenant');
    }

    get landlordTenantRole() {
        return this.intakeData.LT_Role__c || '';
    }

    get landlordTenantProperty() {
        return this.intakeData.LT_Property_Address__c || '';
    }

    get landlordTenantStage() {
        return this.getFieldValue('LT_Stage__c');
    }

    // Additional Landlord-Tenant Fields
    get landlordTenantPartialRentAccepted() {
        return this.intakeData.LT_Partial_Rent_Accepted__c || '';
    }

    get landlordTenantMediationAttempted() {
        return this.intakeData.LT_Mediation_Attempted__c || '';
    }

    get landlordTenantNoticeIssued() {
        return this.intakeData.LT_Notice_Issued__c || '';
    }

    get landlordTenantPreviousEviction() {
        return this.intakeData.LT_Previous_Eviction__c || '';
    }

    get landlordTenantPursueGoal() {
        return this.intakeData.LT_Pursue_Goal__c || '';
    }

    get landlordTenantCaseNumber() {
        return this.intakeData.LT_Case_Number__c || '';
    }

    get landlordTenantFilingCounty() {
        return this.intakeData.LT_Filing_County__c || '';
    }

    get landlordTenantCourtLocation() {
        return this.intakeData.LT_Court_Location__c || '';
    }

    get landlordTenantFilingDate() {
        return this.intakeData.LT_Filing_Date__c || '';
    }

    get landlordTenantNoticeType() {
        return this.intakeData.LT_Notice_Type__c || '';
    }

    get landlordTenantNoticeDate() {
        return this.intakeData.LT_Notice_Date__c || '';
    }

    get landlordTenantNoticeReceivedDate() {
        return this.intakeData.LT_Notice_Received_Date__c || '';
    }

    get landlordTenantServedDate() {
        return this.intakeData.LT_Served_Date__c || '';
    }

    get landlordTenantCurrentStatus() {
        return this.intakeData.LT_Current_Status__c || '';
    }

    get landlordTenantIssueNatureOther() {
        return this.intakeData.LT_Issue_Nature_Other__c || '';
    }

    get landlordTenantMediationOutcome() {
        return this.intakeData.LT_Mediation_Outcome__c || '';
    }

    get landlordTenantPreviousEvictionDetails() {
        return this.intakeData.LT_Previous_Eviction_Details__c || '';
    }

    // Additional missing Landlord-Tenant fields
    get landlordTenantMonthlyRent() {
        return this.getFieldValue('LT_Monthly_Rent_Amount__c');
    }

    get landlordTenantLeaseTermType() {
        return this.getFieldValue('LT_Lease_Term_Type__c');
    }

    get landlordTenantWrittenLease() {
        return this.getFieldValue('LT_Written_Lease__c');
    }

    get landlordTenantPropertyOwnerName() {
        return this.getFieldValue('LT_Property_Owner_Name__c');
    }

    get landlordTenantOwnershipType() {
        return this.getFieldValue('LT_Ownership_Type__c');
    }

    get landlordTenantEntityName() {
        return this.getFieldValue('LT_Entity_Name__c');
    }

    get landlordTenantEntityState() {
        return this.getFieldValue('LT_Entity_State__c');
    }

    get landlordTenantServices() {
        return this.getFormattedArrayField('LT_Landlord_Services__c');
    }

    get landlordTenantIssueNature() {
        return this.getFormattedArrayField('LT_Issue_Nature__c');
    }

    get landlordTenantEvictionFiled() {
        return this.getFieldValue('LT_Eviction_Filed__c');
    }

    get landlordTenantWritRequested() {
        return this.getFieldValue('LT_Writ_Requested__c');
    }

    get landlordTenantCourtRepresentation() {
        return this.getFieldValue('LT_Court_Representation__c');
    }

    get landlordTenantTenantDefenses() {
        return this.getFieldValue('LT_Tenant_Defenses__c');
    }

    get landlordTenantTenantDefensesDetails() {
        return this.getFieldValue('LT_Tenant_Defenses_Details__c');
    }

    get landlordTenantSettlementDiscussion() {
        return this.getFieldValue('LT_Settlement_Discussion__c');
    }

    // Tenant-specific fields
    get landlordTenantTenantLeaseType() {
        return this.getFieldValue('LT_Tenant_Lease_Type__c');
    }

    get landlordTenantTenantLeaseTerm() {
        return this.getFieldValue('LT_Tenant_Lease_Term__c');
    }

    get landlordTenantLeaseAllSigned() {
        return this.getFieldValue('LT_Lease_All_Signed__c');
    }

    get landlordTenantLeaseConcerns() {
        return this.getFieldValue('LT_Lease_Concerns__c');
    }

    get landlordTenantLeaseConcernsDetails() {
        return this.getFieldValue('LT_Lease_Concerns_Details__c');
    }

    get landlordTenantReceivedNotices() {
        return this.getFieldValue('LT_Received_Notices__c');
    }

    get landlordTenantVerbalThreats() {
        return this.getFieldValue('LT_Verbal_Threats__c');
    }

    get landlordTenantNoticeUnjust() {
        return this.getFieldValue('LT_Notice_Unjust__c');
    }

    get landlordTenantNoticeUnjustDetails() {
        return this.getFieldValue('LT_Notice_Unjust_Details__c');
    }

    get landlordTenantHabitabilityIssues() {
        return this.getFieldValue('LT_Habitability_Issues__c');
    }

    get landlordTenantHabitabilityDetails() {
        return this.getFieldValue('LT_Habitability_Details__c');
    }

    get landlordTenantRentWithheld() {
        return this.getFieldValue('LT_Rent_Withheld__c');
    }

    get landlordTenantRepairRequested() {
        return this.getFieldValue('LT_Repair_Requested__c');
    }

    get landlordTenantHarassment() {
        return this.getFieldValue('LT_Harassment__c');
    }

    get landlordTenantHarassmentDetails() {
        return this.getFieldValue('LT_Harassment_Details__c');
    }

    get landlordTenantServedEviction() {
        return this.getFieldValue('LT_Served_Eviction__c');
    }

    // Guardian & Conservatorship Getters
    get hasGuardianConservatorship() {
        return this.legalMatterTypes.includes('Guardian and Conservatorship') && 
               (this.getFieldValue('GC_Ward_Full_Name__c') || this.getFieldValue('GC_Proceeding_Type__c'));
    }

    get guardianWardName() {
        return this.getFieldValue('GC_Ward_Full_Name__c');
    }

    get guardianProceedingType() {
        return this.getFieldValue('GC_Proceeding_Type__c');
    }

    get guardianReason() {
        return this.getFieldValue('GC_Reason__c');
    }

    // Defamation Getters
    get hasDefamation() {
        return this.legalMatterTypes.includes('Defamation') && 
               (this.getFieldValue('DEF_Involvement_Type__c') || this.getFieldValue('DEF_Statement_Maker_Name__c'));
    }

    get defamationInvolvementType() {
        return this.getFieldValue('DEF_Involvement_Type__c');
    }

    get defamationStatementMaker() {
        return this.getFieldValue('DEF_Statement_Maker_Name__c');
    }

    // Utility methods
    formatArrayValue(value) {
        if (Array.isArray(value)) {
            return value.join('; ');
        }
        return value || '';
    }

    // Helper method to get and format array field values from either data source
    getFormattedArrayField(fieldName) {
        const value = this.getFieldValue(fieldName);
        return this.formatArrayValue(value);
    }

    formatYesNo(value) {
        return value === 'Yes' ? 'Yes' : value === 'No' ? 'No' : value || '';
    }

    // Email functionality methods
    handleEmailClick() {
        this.showEmailModal = true;
        this.loadActiveUsers();
        this.generateEmailContent();
    }

    handleCloseEmailModal() {
        this.showEmailModal = false;
        this.selectedUserIds = [];
        this.emailSubject = '';
        this.emailBody = '';
    }

    loadActiveUsers() {
        getActiveUsers()
            .then(result => {
                this.availableUsers = result.map(user => ({
                    label: `${user.Name} (${user.Email})`,
                    value: user.Id
                }));
            })
            .catch(error => {
                this.showToast('Error', 'Failed to load users: ' + error.body.message, 'error');
            });
    }

    handleUserSelection(event) {
        this.selectedUserIds = event.detail.value;
    }

    handleSubjectChange(event) {
        this.emailSubject = event.target.value;
    }

    handleBodyChange(event) {
        this.emailBody = event.target.value;
    }

    generateEmailContent() {
        this.emailSubject = `Intake Form Summary - ${this.leadName}`;
        this.emailBody = this.generateEmailBody();
    }

    generateEmailBody() {
        let emailContent = `<div style="font-family: Arial, sans-serif; max-width: 800px;">`;
        emailContent += `<h2 style="color: #0176d3; border-bottom: 2px solid #0176d3; padding-bottom: 10px;">Intake Form Summary - ${this.leadName}</h2>`;

        // Legal Matter Types
        if (this.legalMatterTypes) {
            emailContent += `<div style="margin-bottom: 20px; border: 1px solid #e5e5e5; border-radius: 5px;">`;
            emailContent += `<h3 style="background-color: #f4f6f9; color: #0176d3; margin: 0; padding: 10px; border-bottom: 1px solid #e5e5e5;">Legal Matter Type(s)</h3>`;
            emailContent += `<div style="padding: 15px;">`;
            emailContent += `<p><strong>Legal Matters:</strong> ${this.legalMatterTypes}</p>`;
            if (this.hasLegalMatterOther) {
                emailContent += `<p><strong>Other:</strong> ${this.legalMatterOther}</p>`;
            }
            emailContent += `</div></div>`;
        }

        // General Information
        if (this.hasGeneralInfo) {
            emailContent += `<div style="margin-bottom: 20px; border: 1px solid #e5e5e5; border-radius: 5px;">`;
            emailContent += `<h3 style="background-color: #f4f6f9; color: #0176d3; margin: 0; padding: 10px; border-bottom: 1px solid #e5e5e5;">General Information</h3>`;
            emailContent += `<div style="padding: 15px;">`;
            if (this.issueDescription) emailContent += `<p><strong>Issue Description:</strong> ${this.issueDescription}</p>`;
            if (this.desiredOutcome) emailContent += `<p><strong>Desired Outcome:</strong> ${this.desiredOutcome}</p>`;
            emailContent += `</div></div>`;
        }

        // Contact & Communication Preferences
        if (this.hasContactInfo) {
            emailContent += this.generateEmailSection('Contact & Communication Preferences', [
                { label: 'Preferred Pronouns', value: this.preferredPronouns },
                { label: 'Work Phone', value: this.workPhone },
                { label: 'Can Text', value: this.canText },
                { label: 'Can Email Follow Up', value: this.canEmailFollowUp },
                { label: 'Preferred Communication Method', value: this.preferredCommunicationMethod },
                { label: 'Preferred Language', value: this.preferredLanguage }
            ]);
        }

        // Personal Information
        if (this.hasPersonalInfo) {
            emailContent += this.generateEmailSection('Personal Information', [
                { label: 'Date of Birth', value: this.dateOfBirth },
                { label: 'Occupation/Employer', value: this.occupationEmployer }
            ]);
        }

        // Referral Information
        if (this.hasReferralInfo) {
            emailContent += this.generateEmailSection('Referral Information', [
                { label: 'How Did You Hear About Us', value: this.howDidYouHear },
                { label: 'Details', value: this.howHearDetails },
                { label: 'Worked With Us Before', value: this.workedWithUsBefore },
                { label: 'Previous Attorney/Office', value: this.previousAttorneyOffice }
            ]);
        }

        // Attorney History
        if (this.hasAttorneyHistory) {
            emailContent += this.generateEmailSection('Attorney History', [
                { label: 'Spoken With Other Attorneys', value: this.spokenWithOtherAttorneys },
                { label: 'Prior Attorney Name/Firm', value: this.priorAttorneyNameFirm },
                { label: 'Reason Not Hired Prior Attorney', value: this.reasonNoHirePriorAttorney },
                { label: 'Currently Represented', value: this.currentlyRepresented },
                { label: 'Reason Seeking New Attorney', value: this.reasonSeekingNewAttorney }
            ]);
        }

        // Conflicts Information
        if (this.hasConflictsInfo) {
            emailContent += this.generateEmailSection('Conflicts & Prior Representation', [
                { label: 'Other Parties Involved', value: this.otherPartiesInvolved },
                { label: 'Previous Legal Matters With Parties', value: this.legalMattersWithPartiesBefore },
                { label: 'Aware of Conflicts', value: this.awareOfConflicts },
                { label: 'Represented Other Parties in Case', value: this.representedOtherPartiesInCase }
            ]);
        }

        // Add other sections based on legal matter types
        if (this.hasCriminalLaw) {
            emailContent += this.generateEmailSection('Criminal Law Details', [
                { label: 'Charges/Allegations', value: this.criminalCharges },
                { label: 'Case Status', value: this.criminalCaseStatus }
            ]);
        }

        if (this.hasFamilyLaw) {
            emailContent += this.generateEmailSection('Family Law Details', [
                { label: 'Currently Married', value: this.familyCurrentlyMarried },
                { label: 'Marriage Date', value: this.familyMarriageDate },
                { label: 'Marriage Location', value: this.familyMarriageLocation },
                { label: 'Relationship Status', value: this.familyRelationshipStatus },
                { label: 'Spouse/Children Together', value: this.familySpouseChildrenTogether },
                { label: 'Previously Filed Family Case', value: this.familyPreviouslyFiledCase },
                { label: 'Seeking Action', value: this.familySeekingAction },
                { label: 'Property Division', value: this.familyPropertyDivision },
                { label: 'Property Division - Real Estate', value: this.familyPropertyDivisionRealEstate },
                { label: 'Property Division - Bank Accounts', value: this.familyPropertyDivisionBankAccounts },
                { label: 'Property Division - Other Assets', value: this.familyPropertyDivisionOtherAssets },
                { label: 'Divorce Contested Status', value: this.familyDivorceContestedStatus },
                { label: 'Children Involved', value: this.familyChildrenInvolved },
                { label: 'Children Details', value: this.familyChildrenDetails },
                { label: 'Existing Custody Orders', value: this.familyExistingCustodyOrders },
                { label: 'Child Safety Concerns', value: this.familyChildSafetyConcerns },
                { label: 'CPS Reports Made', value: this.familyCPSReportsMade },
                { label: 'CPS Reports Details', value: this.familyCPSReportsDetails },
                { label: 'Need Mediation Prep', value: this.familyNeedMediationPrep },
                { label: 'Prepared for Mediation', value: this.familyPreparedForMediation }
            ]);
        }

        if (this.hasEmploymentLaw) {
            emailContent += this.generateEmailSection('Employment Law Details', [
                { label: 'Issue Type', value: this.employmentIssueType },
                { label: 'Current Status', value: this.employmentCurrentStatus }
            ]);
        }

        if (this.hasRealEstate) {
            emailContent += this.generateEmailSection('Real Estate Details', [
                { label: 'Property Address', value: this.realEstateProperty },
                { label: 'Transaction Type', value: this.realEstateTransactionType }
            ]);
        }

        if (this.hasBusinessLaw) {
            emailContent += this.generateEmailSection('Business Law Details', [
                { label: 'Business Name', value: this.businessName },
                { label: 'Issue Type', value: this.businessIssueType }
            ]);
        }

        if (this.hasConstruction) {
            emailContent += this.generateEmailSection('Construction & Construction Defect Details', [
                { label: 'Property Type', value: this.constructionPropertyType },
                { label: 'Issue Description', value: this.constructionIssueDescription }
            ]);
        }

        if (this.hasHOA) {
            emailContent += this.generateEmailSection('HOA Details', [
                { label: 'Property Address', value: this.hoaPropertyAddress },
                { label: 'Issue Type', value: this.hoaIssueType }
            ]);
        }

        if (this.hasLandlordTenant) {
            emailContent += this.generateEmailSection('Landlord-Tenant Details', [
                { label: 'Role', value: this.landlordTenantRole },
                { label: 'Property Address', value: this.landlordTenantProperty },
                { label: 'Stage', value: this.landlordTenantStage },
                { label: 'Monthly Rent Amount', value: this.landlordTenantMonthlyRent },
                { label: 'Lease Term Type', value: this.landlordTenantLeaseTermType },
                { label: 'Written Lease Agreement', value: this.landlordTenantWrittenLease },
                { label: 'Property Owner Name', value: this.landlordTenantPropertyOwnerName },
                { label: 'Property Ownership Type', value: this.landlordTenantOwnershipType },
                { label: 'Entity Name', value: this.landlordTenantEntityName },
                { label: 'Entity State of Formation', value: this.landlordTenantEntityState },
                { label: 'Landlord Services Needed', value: this.landlordTenantServices },
                { label: 'Issue Nature', value: this.landlordTenantIssueNature },
                { label: 'Eviction Action Filed', value: this.landlordTenantEvictionFiled },
                { label: 'Writ of Restitution Requested', value: this.landlordTenantWritRequested },
                { label: 'Court Representation Needed', value: this.landlordTenantCourtRepresentation },
                { label: 'Tenant Asserting Defenses', value: this.landlordTenantTenantDefenses },
                { label: 'Tenant Defense Details', value: this.landlordTenantTenantDefensesDetails },
                { label: 'Settlement Discussion', value: this.landlordTenantSettlementDiscussion },
                { label: 'Partial Rent Accepted', value: this.landlordTenantPartialRentAccepted },
                { label: 'Mediation Attempted', value: this.landlordTenantMediationAttempted },
                { label: 'Notice Issued', value: this.landlordTenantNoticeIssued },
                { label: 'Previous Eviction', value: this.landlordTenantPreviousEviction },
                { label: 'Pursue Goal', value: this.landlordTenantPursueGoal },
                { label: 'Case Number', value: this.landlordTenantCaseNumber },
                { label: 'Filing County', value: this.landlordTenantFilingCounty },
                { label: 'Court Location', value: this.landlordTenantCourtLocation },
                { label: 'Filing Date', value: this.landlordTenantFilingDate },
                { label: 'Notice Type', value: this.landlordTenantNoticeType },
                { label: 'Notice Date', value: this.landlordTenantNoticeDate },
                { label: 'Notice Received Date', value: this.landlordTenantNoticeReceivedDate },
                { label: 'Served Date', value: this.landlordTenantServedDate },
                { label: 'Current Status', value: this.landlordTenantCurrentStatus },
                { label: 'Issue Nature Other', value: this.landlordTenantIssueNatureOther },
                { label: 'Mediation Outcome', value: this.landlordTenantMediationOutcome },
                { label: 'Previous Eviction Details', value: this.landlordTenantPreviousEvictionDetails },
                { label: 'Tenant Lease Type', value: this.landlordTenantTenantLeaseType },
                { label: 'Tenant Lease Term', value: this.landlordTenantTenantLeaseTerm },
                { label: 'Lease Signed by All Adults', value: this.landlordTenantLeaseAllSigned },
                { label: 'Lease Concerns', value: this.landlordTenantLeaseConcerns },
                { label: 'Lease Concerns Details', value: this.landlordTenantLeaseConcernsDetails },
                { label: 'Received Notices from Landlord', value: this.landlordTenantReceivedNotices },
                { label: 'Verbal Threats of Eviction', value: this.landlordTenantVerbalThreats },
                { label: 'Notice Unjust or Retaliatory', value: this.landlordTenantNoticeUnjust },
                { label: 'Notice Unjust Details', value: this.landlordTenantNoticeUnjustDetails },
                { label: 'Habitability Issues', value: this.landlordTenantHabitabilityIssues },
                { label: 'Habitability Details', value: this.landlordTenantHabitabilityDetails },
                { label: 'Rent Withheld', value: this.landlordTenantRentWithheld },
                { label: 'Repair Requested', value: this.landlordTenantRepairRequested },
                { label: 'Harassment/Discrimination', value: this.landlordTenantHarassment },
                { label: 'Harassment Details', value: this.landlordTenantHarassmentDetails },
                { label: 'Served with Eviction', value: this.landlordTenantServedEviction }
            ]);
        }

        if (this.hasGuardianConservatorship) {
            emailContent += this.generateEmailSection('Guardian & Conservatorship Details', [
                { label: 'Proposed Ward', value: this.guardianWardName },
                { label: 'Proceeding Type', value: this.guardianProceedingType },
                { label: 'Reason', value: this.guardianReason }
            ]);
        }

        if (this.hasDefamation) {
            emailContent += this.generateEmailSection('Defamation Details', [
                { label: 'Involvement Type', value: this.defamationInvolvementType },
                { label: 'Statement Maker', value: this.defamationStatementMaker }
            ]);
        }

        emailContent += `</div>`;
        return emailContent;
    }

    generateEmailSection(title, fields) {
        let section = `<div style="margin-bottom: 20px; border: 1px solid #e5e5e5; border-radius: 5px;">`;
        section += `<h3 style="background-color: #f4f6f9; color: #0176d3; margin: 0; padding: 10px; border-bottom: 1px solid #e5e5e5;">${title}</h3>`;
        section += `<div style="padding: 15px;">`;
        
        fields.forEach(field => {
            if (field.value) {
                section += `<p><strong>${field.label}:</strong> ${field.value}</p>`;
            }
        });
        
        section += `</div></div>`;
        return section;
    }

    handleSendEmail() {
        if (!this.selectedUserIds || this.selectedUserIds.length === 0) {
            this.showToast('Error', 'Please select at least one user to email.', 'error');
            return;
        }

        if (!this.emailSubject.trim()) {
            this.showToast('Error', 'Please enter an email subject.', 'error');
            return;
        }

        this.isEmailLoading = true;

        sendIntakeSummaryEmail({
            leadId: this.recordId,
            userIds: this.selectedUserIds,
            emailSubject: this.emailSubject,
            emailBody: this.emailBody
        })
        .then(() => {
            this.showToast('Success', 'Email sent successfully!', 'success');
            this.handleCloseEmailModal();
        })
        .catch(error => {
            this.showToast('Error', 'Failed to send email: ' + error.body.message, 'error');
        })
        .finally(() => {
            this.isEmailLoading = false;
        });
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