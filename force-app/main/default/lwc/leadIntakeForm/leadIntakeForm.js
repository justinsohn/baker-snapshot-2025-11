import { LightningElement, api, wire, track } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { NavigationMixin } from "lightning/navigation";
import { refreshApex } from "@salesforce/apex";
import { getRecord } from "lightning/uiRecordApi";

// Schema and API
import CLIENT_INTAKE_OBJECT from "@salesforce/schema/Client_Intake__c";
import { getObjectInfo } from "lightning/uiObjectInfoApi";
import { getPicklistValuesByRecordType } from "lightning/uiObjectInfoApi";

// Apex Methods
import getIntakesByLead from "@salesforce/apex/ClientIntakeController.getIntakesByLead";
import getFullIntakeRecord from "@salesforce/apex/ClientIntakeController.getFullIntakeRecord";
import createNewIntakeForLead from "@salesforce/apex/ClientIntakeController.createNewIntakeForLead";
import saveIntakeRecord from "@salesforce/apex/ClientIntakeController.saveIntakeRecord";
import searchLeads from "@salesforce/apex/ClientIntakeController.searchLeads";
import searchActiveUsers from "@salesforce/apex/ClientIntakeController.searchActiveUsers";
import getLeadIntakeAttorney from "@salesforce/apex/ClientIntakeController.getLeadIntakeAttorney";
import getLeadClient from "@salesforce/apex/ClientIntakeController.getLeadClient";
import getPreferredOfficeLocationValues from "@salesforce/apex/ClientIntakeController.getPreferredOfficeLocationValues";

/**
 * Helper function to safely convert a semicolon-delimited string to an array.
 * Handles null, undefined, or empty strings gracefully by returning an empty array.
 * @param {string} str - The string to convert.
 * @returns {string[]} An array of strings.
 */
const stringToArray = (str) => {
  if (str && typeof str === "string") {
    return str
      .split(";")
      .map((item) => item.trim())
      .filter(Boolean);
  }
  return [];
};

/**
 * A constant list of all API names for fields that are rendered as a lightning-dual-listbox.
 * This provides a reliable way to identify these fields for data processing without depending on the DOM.
 */
const DUAL_LISTBOX_FIELDS = [
  "Legal_Matter_Type__c",
  "CL_Case_Involvement_Types__c",
  "DV_Types_Of_Abuse__c",
  "DV_Receiving_Support_Services__c",
  "PE_Decedent_Asset_Types__c",
  "EP_Documents_Needed__c",
  "BUS_Purchase_Sale_Inclusions__c",
  "CONST_Defect_Types__c",
  "CONST_Issue_Nature__c",
  "CONST_Desired_Outcome__c",
  "EMPL_Current_Benefits__c",
  "EMPL_Work_Environment__c",
  "EMPL_Desired_Outcome__c",
  "HOA_Governing_Documents__c",
  "HOA_Issue_Category__c",
  "HOA_Desired_Outcome__c",
  "DEF_Statement_Types__c",
  "DEF_Harm_Types__c",
  "DEF_Reputation_Impact__c",
  "DEF_Response_Actions__c",
  "DEF_Evidence_Types__c",
  "DEF_Resolution_Efforts__c",
  "FL_Seeking_Action__c",
  "FL_Seeking_Custody_Type__c",
  "FL_Additional_Issues__c",
  "FL_Document_Types_Review__c",
  "FL_Need_Document_Drafting__c",
  "FL_Expert_Types__c",
  "RE_Assistance_Type__c",
  "RE_Your_Role__c",
  "RE_Dispute_Nature__c",
  "RE_Contribution_Types__c",
  "RE_Seeking__c",
  "LT_Landlord_Services__c",
  "LT_Issue_Nature__c",
  "LT_Defenses__c",
  "GC_Asset_Types__c"
];

const DEFAULT_PREFERRED_OFFICE_LOCATIONS = [
  { label: "Austin", value: "Austin" },
  { label: "Colorado Springs", value: "Colorado Springs" },
  { label: "Denver", value: "Denver" },
  { label: "Denver Tech Center", value: "Denver Tech Center" },
  { label: "Fort Collins", value: "Fort Collins" },
  { label: "Las Vegas", value: "Las Vegas" },
  { label: "Northglenn", value: "Northglenn" },
  { label: "Pueblo", value: "Pueblo" }
];

const CATEGORY_DEPENDENCY_MAP = {
  Criminal: [
    "Assault",
    "Domestic Violence",
    "Drug Related",
    "DUI Defense",
    "Economic Crime (Fraud/Laundering)",
    "Expungements",
    "Federal Criminal Defense",
    "Felony",
    "Homicide",
    "Misdemeanor",
    "POA (Limited Scope Criminal Consultation)",
    "Protective Orders",
    "Sex Offense",
    "Theft (Robbery, Shoplifting, Larceny, Burglary)",
    "Traffic Offense (including Hit-and-Run)",
    "White-Collar Crime"
  ],
  Civil: {
    "Pre-Litigation": [
      "Business",
      "Construction",
      "Defamation",
      "Education",
      "Employment",
      "Family",
      "General Civil",
      "HOA",
      "Insurance",
      "Landlord/Tenant",
      "Personal Injury",
      "Real Estate"
    ],
    Litigation: [
      "Business",
      "Civil Rights",
      "Construction",
      "Defamation",
      "Education",
      "Employment",
      "Family",
      "General Civil",
      "Guardianship/Conservatorship",
      "HOA",
      "Immigration",
      "Insurance ",
      "Landlord/Tenant",
      "Personal Injury",
      "Probate",
      "Real Estate"
    ],
    Transactional: [
      "Business",
      "Defamation",
      "Education",
      "Employment",
      "Family",
      "General Civil",
      "Guardianship/Conservatorship",
      "HOA",
      "Immigration",
      "Insurance",
      "Landlord/Tenant",
      "Probate",
      "Real Estate",
      "Trusts and Estates"
    ]
  }
};

const SUBCATEGORY_DEPENDENCY_MAP = {
  PreLitigation: {
    Business: ["Demand Letter", "Cease and Desist", "Other"],
    Construction: ["Demand Letter", "Cease and Desist", "Other"],
    Defamation: ["Demand Letter", "Cease and Desist", "Other"],
    Education: ["Demand Letter", "Cease and Desist", "Other"],
    Employment: ["Demand Letter", "Cease and Desist", "Other"],
    Family: ["Demand Letter (Support)", "Other"],
    "General Civil": [
      "Demand Letter",
      "Small Claims",
      "Cease and Desist",
      "Other"
    ],
    HOA: ["Demand Letter", "Other"],
    Insurance: ["Demand Letter", "Other"],
    "Landlord/Tenant": ["Demand Letter (Rent/Repair)", "Other"],
    "Personal Injury": ["Demand Letter", "Other"],
    "Real Estate": ["Cease and Desist", "Opinion Letter", "Other"]
  },
  Litigation: {
    Business: [
      "General Dispute",
      "Contract Dispute",
      "Mechanic's Lien",
      "Debt/Collections",
      "Partitions",
      "Noncompete",
      "Other"
    ],
    "Civil Rights": [
      "Police Brutality",
      "ADA Violations",
      "Discrimination",
      "Protest Violations",
      "Other"
    ],
    Construction: [
      "Construction Defect",
      "Mechanic's Lien",
      "Breach of Contract",
      "Easement",
      "Other"
    ],
    Defamation: ["Libel/Slander Suit", "Other"],
    Education: ["Title 9", "Other Discrimination", "Other"],
    Employment: [
      "Wage/Hour",
      "Hostile Work Environment",
      "Discrimination",
      "Harassment",
      "Wrongful Discharge",
      "OSHA Violation",
      "Non-Compete/Non-Solicit Dispute",
      "Other"
    ],
    Family: [
      "DHS (Child Protection)",
      "Divorce",
      "Custody",
      "Child Support/Alimony",
      "Asset Division",
      "Mediation/ADR",
      "Other"
    ],
    "General Civil": ["Litigation", "Other"],
    "Guardianship/Conservatorship": ["Contested", "Uncontested", "Other"],
    HOA: ["Foreclosure", "Rule Violations", "Other"],
    Immigration: ["Removal Defense", "Bond Hearings", "Other"],
    "Insurance ": ["Bad Faith Denial", "Other"],
    "Landlord/Tenant": [
      "Eviction",
      "Breach of Lease Agreement",
      "Small Claims",
      "Habitability",
      "Other"
    ],
    "Personal Injury": [
      "Medical Malpractice",
      "Workers Comp",
      "Product Liability",
      "Other"
    ],
    Probate: ["Contested", "Uncontested", "Other"],
    "Real Estate": [
      "Partitions",
      "Foreclosure",
      "Easements",
      "Quiet Title/Boundary",
      "Asset Recovery",
      "Water Law",
      "Other"
    ]
  },
  Transactional: {
    Business: [
      "Contract Drafting",
      "Contract Review",
      "Business Formation",
      "Franchise Agreements",
      "Joint Ventures and Partnerships",
      "Services Agreement",
      "Independent Contractor Agreement",
      "Business Purchase and Sale",
      "Business Transfer/Expansion",
      "Opinion Letter",
      "Business Dissolution",
      "Qualified Subchapter S Elections",
      "Mergers and Acquisitions",
      "Cannabis Law",
      "Psilocybin Regulation",
      "Other"
    ],
    Defamation: ["Retraction", "Settlement", "Documentation Review", "Other"],
    Education: ["Policy Review/Drafting", "Other"],
    Employment: [
      "Employment Agreement",
      "Non-Compete/Non-Solicit Review",
      "Handbook",
      "Review Leave Compliance",
      "Review Wage/Hour Compliance",
      "Other"
    ],
    Family: [
      "Prenuptial/Postnuptial Agreement",
      "Parenting Plan",
      "Unbundled",
      "Other"
    ],
    "General Civil": [
      "Contract Drafting/Review",
      "Settlement Agreement Drafting/Review",
      "Other"
    ],
    "Guardianship/Conservatorship": ["Contested", "Uncontested", "Other"],
    HOA: ["Deed Compliance", "Document Review/Drafting", "Other"],
    Immigration: [
      "Application for Citizenship or Residency",
      "Visa Application",
      "POA (Application Assistance)",
      "Other"
    ],
    Insurance: ["Policy Review", "Other"],
    "Landlord/Tenant": ["Lease Drafting/Review", "Other"],
    "Real Estate": [
      "Contract/Purchase or Sale",
      "Deed",
      "Lease Agreement",
      "Mortgage",
      "Title Transfers",
      "Partitions",
      "Opinion Letter",
      "Other"
    ],
    "Trusts and Estates": [
      "Will",
      "Trust",
      "POA",
      "General Estate Planning",
      "Other"
    ]
  }
};

const MATTER_TYPE_DEPENDENCY_MAP = {
  Assault: "Criminal Law",
  Business: "Business Law",
  "Civil Rights": "Other",
  Construction: "Construction & Construction Defect",
  Defamation: "Defamation",
  "Domestic Violence": "Criminal Law",
  "Drug Related": "Criminal Law",
  "DUI Defense": "Criminal Law",
  "Economic Crime (Fraud/Laundering)": "Criminal Law",
  Education: "Other",
  Employment: "Employment Law",
  Expungements: "Criminal Law",
  Family: "Family Law",
  "Federal Criminal Defense": "Criminal Law",
  Felony: "Criminal Law",
  "General Civil": "Other",
  "Guardianship/Conservatorship": "Guardian and Conservatorship",
  HOA: "HOA",
  Homicide: "Criminal Law",
  Immigration: "Other",
  Insurance: "Other",
  "Landlord/Tenant": "Landlord-Tenant Dispute",
  Misdemeanor: "Criminal Law",
  "Personal Injury": "Personal Injury",
  "POA (Limited Scope Criminal Consultation)": "Criminal Law",
  Probate: "Probate/Estate Planning",
  "Protective Orders": "Criminal Law",
  "Real Estate": "Real Estate",
  "Sex Offense": "Criminal Law",
  "Theft (Robbery, Shoplifting, Larceny, Burglary)": "Criminal Law",
  "Traffic Offense (including Hit-and-Run)": "Criminal Law",
  "Trusts and Estates": "Probate/Estate Planning",
  "White-Collar Crime": "Criminal Law"
};

export default class LeadIntakeForm extends NavigationMixin(LightningElement) {
  @api recordId;

  @track intakeRecord = {};
  @track additionalDetails = {}; // For JSON storage of new fields
  @track existingIntakes = [];
  @track picklistValues = {};
  globalPreferredOfficeLocationValues = [];
  @track showForm = false;
  @track isLoading = true;
  @track formTitle = "";
  @track activeTab = "General";
  @track showLeadSearch = false; // For non-licensed users
  @track searchTerm = "";
  @track searchResults = [];
  @track selectedLeadId = null;
  @track showCivilType = false;
  @track showCategory = false;
  @track showSubcategory = false;

  @track currentLeadId = null;
  attorneyOptions = [];
  attorneyInputValue = "";
  selectedAttorneyId = null;
  selectedAttorneyName = "";
  attorneyDropdownOpen = false;
  attorneySelectionMade = false;
  attorneyLoading = false;
  attorneyInputHasFocus = false;

  selectedClientId = null;

  _wiredIntakesResult;
  _wiredLeadResult;
  defaultRecordTypeId;
  realFieldsCache = new Set(); // Cache of fields that actually exist in Salesforce org

  connectedCallback() {
    if (this.recordId) {
      this.currentLeadId = this.recordId;
    }

    // If no recordId is provided (e.g., on Home page), show lead search
    if (!this.recordId) {
      this.showLeadSearch = true;
      this.isLoading = false;
    }
  }

  /**
   * Cache which fields actually exist in the Salesforce org
   * @param {Object} fields - Field metadata from getObjectInfo
   */
  cacheRealFields(fields) {
    if (!fields) return;

    Object.keys(fields).forEach((fieldName) => {
      this.realFieldsCache.add(fieldName);
    });
  }

  /**
   * Check if a field exists in the Salesforce org
   * @param {string} fieldName - API name of the field
   * @returns {boolean} - True if field exists in org
   */
  isRealField(fieldName) {
    return this.realFieldsCache.has(fieldName);
  }

  @wire(getObjectInfo, { objectApiName: CLIENT_INTAKE_OBJECT })
  objectInfo({ data, error }) {
    if (data) {
      this.defaultRecordTypeId = data.defaultRecordTypeId;
      // Cache which fields exist in the Salesforce org
      this.cacheRealFields(data.fields);
    } else if (error) {
      this.showToast(
        "Error Loading Schema",
        this.reduceErrors(error)[0],
        "error"
      );
    }
  }

  @wire(getPicklistValuesByRecordType, {
    objectApiName: CLIENT_INTAKE_OBJECT,
    recordTypeId: "$defaultRecordTypeId"
  })
  wiredPicklistValues({ data, error }) {
    if (data) {
      this.picklistValues = Object.keys(data.picklistFieldValues).reduce(
        (acc, picklist) => {
          acc[picklist] = data.picklistFieldValues[picklist].values;
          return acc;
        },
        {}
      );
    } else if (error) {
      this.showToast(
        "Error Loading Picklists",
        this.reduceErrors(error)[0],
        "error"
      );
    }
  }

  @wire(getPreferredOfficeLocationValues)
  wiredPreferredOfficeLocations({ data, error }) {
    if (data) {
      this.globalPreferredOfficeLocationValues = data;
    } else if (error) {
      console.error("Error loading preferred office locations:", error);
      // Fall back to default values if there's an error
      this.globalPreferredOfficeLocationValues = [];
    }
  }

  @wire(getRecord, {
    recordId: "$currentLeadId",
    fields: ["Lead.Id", "Lead.Client__c"]
  })
  wiredLead(result) {
    this._wiredLeadResult = result;
  }

  @wire(getIntakesByLead, { leadId: "$currentLeadId" })
  wiredIntakes(result) {
    this.isLoading = false;
    this._wiredIntakesResult = result;
    if (result.data) {
      this.existingIntakes = result.data.map((intake) => {
        const legalMatters = intake.Legal_Matter_Type__c
          ? intake.Legal_Matter_Type__c.replace(/;/g, ", ")
          : "N/A";
        return { ...intake, Legal_Matter_Type__c: legalMatters };
      });
    } else if (result.error) {
      this.showToast(
        "Error Loading Intakes",
        this.reduceErrors(result.error)[0],
        "error"
      );
    }
  }

  // --- UI EVENT HANDLERS ---
  handleCreateNew() {
    this.isLoading = true;
    const leadId = this.currentLeadId || this.recordId || this.selectedLeadId;

    if (!leadId) {
      this.showToast(
        "Error",
        "No lead selected. Please select a lead first.",
        "error"
      );
      this.isLoading = false;
      return;
    }

    this.currentLeadId = leadId;
    this.resetAttorneyField();

    createNewIntakeForLead({ leadId: leadId })
      .then((result) => {
        this.intakeRecord = { ...result, Legal_Matter_Type__c: [] }; // Initialize as array
        this.additionalDetails = {}; // Initialize additional details
        this.formTitle = "Create New Intake";
        this.activeTab = "General";
        this.showForm = true;
        this.initializeAttorneyField(leadId);
        this.initializeClientField(leadId);
      })
      .catch((error) =>
        this.showToast(
          "Error Creating Intake",
          this.reduceErrors(error)[0],
          "error"
        )
      )
      .finally(() => {
        this.isLoading = false;
      });
  }

  /**
   * Corrected handleEdit function.
   * It now processes the record from Apex before assigning it to the tracked property `this.intakeRecord`.
   * This prevents a premature render cycle from passing a string to dual-listbox components.
   */
  handleEdit(event) {
    const intakeId = event.currentTarget.dataset.id;
    this.isLoading = true;
    getFullIntakeRecord({ intakeId })
      .then((result) => {
        // Create a temporary, mutable copy of the record data.
        const processedRecord = { ...result };
        this.currentLeadId = processedRecord.Lead__c;
        this.resetAttorneyField();

        // Parse the JSON field if it exists and merge with record
        if (processedRecord.Intake_Details_JSON__c) {
          try {
            const jsonFieldsData = JSON.parse(
              processedRecord.Intake_Details_JSON__c
            );
            console.log(
              "[INTAKE FORM] Loaded JSON field data:",
              Object.keys(jsonFieldsData).length,
              "fields"
            );
            console.log(
              "[INTAKE FORM] JSON field names:",
              Object.keys(jsonFieldsData)
            );

            // Merge JSON-backed fields into processedRecord
            Object.keys(jsonFieldsData).forEach((fieldName) => {
              processedRecord[fieldName] = jsonFieldsData[fieldName];
            });
            console.log(
              "[INTAKE FORM] Merged JSON fields into processedRecord. Total fields:",
              Object.keys(processedRecord).length
            );

            this.additionalDetails = jsonFieldsData; // Keep for backward compatibility
          } catch (e) {
            console.error(
              "[INTAKE FORM] Error parsing Intake_Details_JSON__c:",
              e
            );
            console.error(
              "[INTAKE FORM] JSON content that failed:",
              processedRecord.Intake_Details_JSON__c
            );
            this.additionalDetails = {};
          }
        } else {
          console.log(
            "[INTAKE FORM] No Intake_Details_JSON__c found on record"
          );
          this.additionalDetails = {};
        }

        // Process the data BEFORE assigning it to the tracked property.
        // Convert semicolon-delimited strings to arrays for ALL dual-listbox fields
        // (whether they came from real Salesforce fields or JSON storage)
        for (const fieldName of DUAL_LISTBOX_FIELDS) {
          if (
            Object.prototype.hasOwnProperty.call(processedRecord, fieldName) &&
            typeof processedRecord[fieldName] === "string"
          ) {
            processedRecord[fieldName] = stringToArray(
              processedRecord[fieldName]
            );
          }
        }

        // Now that the data is in the correct shape, assign it to the tracked property.
        // This will trigger a single, correct re-render.
        this.intakeRecord = processedRecord;
        console.log(
          "[INTAKE FORM] Final intakeRecord assigned with",
          Object.keys(this.intakeRecord).length,
          "fields"
        );
        console.log(
          "[INTAKE FORM] Sample field values - Issue_Description:",
          this.intakeRecord.Issue_Description__c?.substring(0, 50)
        );
        console.log(
          "[INTAKE FORM] Sample JSON field - DEF_Business_Name:",
          this.intakeRecord.DEF_Business_Name__c
        );
        console.log("[INTAKE FORM] RE fields check:", {
          RE_Property_Street: this.intakeRecord.RE_Property_Street__c,
          RE_Property_City: this.intakeRecord.RE_Property_City__c,
          RE_Assistance_Type: this.intakeRecord.RE_Assistance_Type__c,
          RE_Your_Role: this.intakeRecord.RE_Your_Role__c
        });

        this.showCivilType =
          this.intakeRecord.Type_of_Law__c === "Civil" ? true : false;
        this.showCategory =
          this.intakeRecord.Type_of_Law__c === "Criminal" ||
          this.intakeRecord.Type_of_Civil_Law__c
            ? true
            : false;
        this.showSubcategory =
          this.intakeRecord.Type_of_Law__c === "Civil" &&
          this.intakeRecord.Category__c
            ? true
            : false;

        this.formTitle = `Edit Intake: ${this.intakeRecord.Name || "Intake"}`;
        this.activeTab = "General";
        this.showForm = true;
        this.initializeAttorneyField(this.currentLeadId);
        this.initializeClientField(this.currentLeadId);
      })
      .catch((error) =>
        this.showToast(
          "Error Loading Intake",
          this.reduceErrors(error)[0],
          "error"
        )
      )
      .finally(() => {
        this.isLoading = false;
      });
  }

  handleView(event) {
    this[NavigationMixin.Navigate]({
      type: "standard__recordPage",
      attributes: {
        recordId: event.currentTarget.dataset.id,
        objectApiName: "Client_Intake__c",
        actionName: "view"
      }
    });
  }

  handleCancel() {
    this.showForm = false;
    this.intakeRecord = {};
    this.additionalDetails = {};
    this.resetAttorneyField();
  }

  handleFieldChange(event) {
    const fieldName = event.target.dataset.field;
    const value =
      event.target.type === "checkbox"
        ? event.target.checked
        : event.target.value;
    this.intakeRecord = { ...this.intakeRecord, [fieldName]: value };
    if (fieldName === "Type_of_Law__c") {
      this.intakeRecord.Category__c = null;
      this.intakeRecord.Subcategory__c = null;
      this.intakeRecord.Legal_Matter_Type__c = [];
      this.showSubcategory = false;
      if (event.target.value === "Civil") {
        this.showCivilType = true;
        this.showCategory = this.intakeRecord.Type_of_Civil_Law__c
          ? true
          : false;
      } else if (event.target.value === "Criminal") {
        this.intakeRecord.Type_of_Civil_Law__c = null;
        this.showCivilType = false;
        this.showCategory = true;
      } else {
        this.showCivilType = false;
      }
    } else if (fieldName === "Type_of_Civil_Law__c") {
      this.intakeRecord.Category__c = null;
      this.intakeRecord.Subcategory__c = null;
      this.intakeRecord.Legal_Matter_Type__c = [];
      this.showCategory = event.target.value ? true : false;
      this.showSubcategory = false;
    } else if (fieldName === "Category__c") {
      this.intakeRecord.Subcategory__c = null;
      if (this.intakeRecord.Type_of_Law__c === "Civil") {
        this.showSubcategory = event.target.value ? true : false;
      }
      const mappedMatterType = MATTER_TYPE_DEPENDENCY_MAP[value];
      if (value && mappedMatterType) {
        this.intakeRecord.Legal_Matter_Type__c = [mappedMatterType];
      } else {
        this.intakeRecord.Legal_Matter_Type__c = [];
      }
    }
  }

  handleTypeOfLaw(event) {
    this.showCivilType = event.target.value === "Civil" ? true : false;
    this.handleFieldChange(event);
  }

  // --- Intake Attorney Lookup Helpers ---
  resetAttorneyField() {
    this.attorneyOptions = [];
    this.attorneyInputValue = "";
    this.selectedAttorneyId = null;
    this.selectedAttorneyName = "";
    this.attorneyDropdownOpen = false;
    this.attorneySelectionMade = false;
    this.attorneyLoading = false;
    this.attorneyInputHasFocus = false;
    this.clearAttorneyValidation();
  }

  initializeAttorneyField(leadId) {
    if (!leadId) {
      return;
    }
    this.attorneyLoading = true;
    getLeadIntakeAttorney({ leadId })
      .then((result) => {
        if (result && result.Intake_Attorney__c) {
          this.selectedAttorneyId = result.Intake_Attorney__c;
          this.selectedAttorneyName = result.Intake_Attorney__r
            ? result.Intake_Attorney__r.Name
            : "";
          this.attorneyInputValue = this.selectedAttorneyName;
          this.attorneySelectionMade = true;
        } else {
          this.selectedAttorneyId = null;
          this.selectedAttorneyName = "";
          this.attorneyInputValue = "";
          this.attorneySelectionMade = false;
        }
        this.clearAttorneyValidation();
      })
      .catch((error) => {
        console.error("Error retrieving lead intake attorney", error);
      })
      .finally(() => {
        this.attorneyLoading = false;
      });
  }

  handleAttorneyFocus() {
    this.attorneyInputHasFocus = true;
    this.attorneyDropdownOpen = true;
    this.executeAttorneySearch(this.attorneyInputValue || "");
  }

  handleAttorneyKeyUp(event) {
    if (event.key === "Escape") {
      return;
    }
    this.processAttorneyInput(event.target.value);
  }

  handleAttorneyChange(event) {
    const value = event.target.value || "";
    if (this.attorneySelectionMade && value === this.attorneyInputValue) {
      return;
    }
    this.processAttorneyInput(value);
  }

  processAttorneyInput(rawValue) {
    const value = rawValue || "";
    this.attorneyInputValue = value;
    this.selectedAttorneyId = null;
    this.selectedAttorneyName = "";
    this.attorneySelectionMade = false;
    this.attorneyInputHasFocus = true;
    this.attorneyDropdownOpen = true;
    this.executeAttorneySearch(value);
    this.clearAttorneyValidation();
  }

  handleAttorneyKeydown(event) {
    if (event.key === "Escape") {
      this.attorneyDropdownOpen = false;
    }
  }

  handleAttorneyBlur() {
    this.attorneyInputHasFocus = false;
    this.attorneyDropdownOpen = false;
  }

  executeAttorneySearch(searchTerm) {
    const normalizedTerm =
      searchTerm && searchTerm.toLowerCase() !== "none"
        ? searchTerm.trim()
        : "";
    this.attorneyLoading = true;
    searchActiveUsers({ searchTerm: normalizedTerm })
      .then((results) => {
        const noneOption = {
          id: "NONE",
          name: "None",
          subtitle: "Select when the intake specialist handled the matter",
          isNone: true,
          disabled: false,
          className:
            "slds-media slds-listbox__option slds-listbox__option_entity slds-media_center"
        };

        const userOptions = results.map((user) => ({
          id: user.Id,
          name: user.Name,
          subtitle: user.Title,
          isNone: false,
          disabled: false,
          className:
            "slds-media slds-listbox__option slds-listbox__option_entity slds-media_center"
        }));

        const noResultsOption = {
          id: "NO_RESULTS",
          name: "No matching attorneys",
          subtitle: "Adjust your search and try again",
          isNone: false,
          disabled: true,
          className:
            "slds-media slds-listbox__option slds-listbox__option_entity slds-media_center slds-is-disabled"
        };

        this.attorneyOptions = userOptions.length
          ? [noneOption, ...userOptions]
          : [noneOption, noResultsOption];

        this.attorneyDropdownOpen = true;
      })
      .catch((error) => {
        this.showToast(
          "Error Searching Users",
          this.reduceErrors(error)[0],
          "error"
        );
      })
      .finally(() => {
        this.attorneyLoading = false;
      });
  }

  handleAttorneyOptionMouseDown(event) {
    event.preventDefault();
    const optionId = event.currentTarget.dataset.id;
    const optionName = event.currentTarget.dataset.name;
    const isNone = optionId === "NONE";
    const isDisabled = event.currentTarget.dataset.disabled === "true";

    if (isDisabled) {
      return;
    }

    if (isNone) {
      this.selectedAttorneyId = null;
      this.selectedAttorneyName = "None";
      this.attorneyInputValue = "None";
    } else {
      this.selectedAttorneyId = optionId;
      this.selectedAttorneyName = optionName;
      this.attorneyInputValue = optionName;
    }

    this.attorneySelectionMade = true;
    this.attorneyDropdownOpen = false;
    this.attorneyInputHasFocus = false;
    this.validateAttorneySelection();
  }

  validateAttorneySelection() {
    const input = this.template.querySelector(
      '[data-element="intake-attorney"]'
    );
    if (!input) {
      return true;
    }

    if (!this.attorneySelectionMade) {
      input.setCustomValidity("Select an attorney or choose None.");
      input.reportValidity();
      return false;
    }

    input.setCustomValidity("");
    input.reportValidity();
    return true;
  }

  clearAttorneyValidation() {
    Promise.resolve().then(() => {
      const input = this.template.querySelector(
        '[data-element="intake-attorney"]'
      );
      if (input) {
        input.setCustomValidity("");
      }
    });
  }

  // --- Client Lookup Helpers ---
  initializeClientField(leadId) {
    if (!leadId) {
      return;
    }
    getLeadClient({ leadId })
      .then((result) => {
        if (result && result.Client__c) {
          this.selectedClientId = result.Client__c;
        } else {
          this.selectedClientId = null;
        }
      })
      .catch((error) => {
        console.error("Error retrieving lead client", error);
        this.selectedClientId = null;
      });
  }

  handleClientChange(event) {
    // lightning-input-field can return the full value array or just the ID
    const value = event.detail.value;
    // Extract ID if it's an array with objects, otherwise use the value directly
    if (Array.isArray(value) && value.length > 0) {
      this.selectedClientId = value[0];
    } else if (typeof value === "string" || value === null) {
      this.selectedClientId = value;
    } else {
      this.selectedClientId = null;
    }
  }

  resetClientField() {
    this.selectedClientId = null;
  }

  handleSave() {
    const attorneyValid = this.validateAttorneySelection();
    const formElements = [
      ...this.template.querySelectorAll(
        "lightning-input, lightning-combobox, lightning-textarea, lightning-dual-listbox, lightning-radio-group"
      )
    ];

    const allValid = formElements.reduce((validSoFar, inputCmp) => {
      inputCmp.reportValidity();
      return validSoFar && inputCmp.checkValidity();
    }, true);

    const typeOfLawSelected = !!this.intakeRecord.Type_of_Law__c;
    const typeOfLawRadio = this.template.querySelector(
      'lightning-radio-group[data-field="Type_of_Law__c"]'
    );
    if (typeOfLawRadio) {
      typeOfLawRadio.setCustomValidity(
        typeOfLawSelected ? "" : "Select a type of law."
      );
      typeOfLawRadio.reportValidity();
    }

    if (!allValid || !attorneyValid || !typeOfLawSelected) {
      this.showToast(
        "Validation Error",
        "Please review all fields and complete the required ones.",
        "error"
      );
      return;
    }

    this.isLoading = true;
    // Deep copy the record to avoid mutating the tracked property directly before the save is complete.
    const allData = JSON.parse(JSON.stringify(this.intakeRecord));

    console.log(
      "[INTAKE FORM] Saving intake with total fields:",
      Object.keys(allData).length
    );
    console.log(
      "[INTAKE FORM] realFieldsCache size:",
      this.realFieldsCache.size
    );

    // Split data into real Salesforce fields vs JSON-backed fields
    const recordToSave = {}; // Only fields that exist in org
    const jsonFieldsData = {}; // Fields that don't exist in org - will be stored in Intake_Details_JSON__c

    Object.keys(allData).forEach((key) => {
      let value = allData[key];

      // Convert array values from dual-listboxes back to semicolon-delimited strings
      if (Array.isArray(value)) {
        value = value.join("; ");
      }

      // Split based on whether field exists in org
      if (this.isRealField(key)) {
        recordToSave[key] = value;
      } else {
        // Store non-existent fields in JSON
        jsonFieldsData[key] = value;
      }
    });

    console.log(
      "[INTAKE FORM] Split complete - Real fields:",
      Object.keys(recordToSave).length,
      "JSON fields:",
      Object.keys(jsonFieldsData).length
    );
    console.log("[INTAKE FORM] JSON field names:", Object.keys(jsonFieldsData));

    // Store JSON-backed fields in Intake_Details_JSON__c
    if (Object.keys(jsonFieldsData).length > 0) {
      recordToSave.Intake_Details_JSON__c = JSON.stringify(jsonFieldsData);
      console.log(
        "[INTAKE FORM] JSON string length:",
        recordToSave.Intake_Details_JSON__c.length,
        "bytes"
      );
    } else {
      console.log("[INTAKE FORM] No JSON fields to save");
    }

    // Generate the JSON string from the processed record that matches the database state.
    const intakeJson = JSON.stringify({ ...recordToSave, ...jsonFieldsData });

    // Keep additionalDetails for backward compatibility (if used elsewhere)
    const additionalDetailsJson = JSON.stringify(this.additionalDetails);

    recordToSave.sobjectType = "Client_Intake__c";

    // Call the updated Apex method, passing the record, JSON strings
    saveIntakeRecord({
      intakeRecord: recordToSave,
      intakeJson: intakeJson,
      additionalDetailsJson: additionalDetailsJson,
      intakeAttorneyId: this.selectedAttorneyId,
      clientId: this.selectedClientId
    })
      .then(() => {
        this.showToast("Success", "Intake record saved.", "success");
        this.showForm = false;
        this.intakeRecord = {};
        this.resetAttorneyField();
        this.resetClientField();

        // Refresh both the intakes list and the Lead record to update the Client field
        return Promise.all([
          refreshApex(this._wiredIntakesResult),
          refreshApex(this._wiredLeadResult)
        ]);
      })
      .catch((error) =>
        this.showToast(
          "Error Saving Intake",
          this.reduceErrors(error)[0],
          "error"
        )
      )
      .finally(() => {
        this.isLoading = false;
      });
  }

  // --- GETTERS FOR CONDITIONAL VISIBILITY ---
  get hasExistingIntakes() {
    return this.existingIntakes?.length > 0;
  }
  get yesNoOptions() {
    return [
      { label: "Yes", value: "Yes" },
      { label: "No", value: "No" }
    ];
  }

  // This getter is safe because handleEdit ensures Legal_Matter_Type__c is an array.
  get selectedMatterTypes() {
    return this.intakeRecord?.Legal_Matter_Type__c || [];
  }

  // --- Tab Visibility ---
  get showCriminalLaw() {
    return this.selectedMatterTypes.includes("Criminal Law");
  }
  get showFamilyLaw() {
    return this.selectedMatterTypes.includes("Family Law");
  }
  get showProbate() {
    return this.selectedMatterTypes.includes("Probate/Estate Planning");
  }
  get showRealEstate() {
    return this.selectedMatterTypes.includes("Real Estate");
  }
  get showPersonalInjury() {
    return this.selectedMatterTypes.includes("Personal Injury");
  }
  get showCivilLitigation() {
    return this.selectedMatterTypes.includes("Civil Litigation");
  }
  get showEmploymentLaw() {
    return this.selectedMatterTypes.includes("Employment Law");
  }
  get showLandlordTenant() {
    return this.selectedMatterTypes.includes("Landlord-Tenant Dispute");
  }
  get showHOA() {
    return this.selectedMatterTypes.includes("HOA");
  }
  get showConstruction() {
    return this.selectedMatterTypes.includes(
      "Construction & Construction Defect"
    );
  }
  get showBusinessLaw() {
    return this.selectedMatterTypes.includes("Business Law");
  }
  get showGuardianshipConservatorship() {
    return this.selectedMatterTypes.includes("Guardianship/Conservatorship");
  }

  // --- HOA Section ---
  get showHOANotResident() {
    return this.intakeRecord.HOA_Currently_Reside__c === "No";
  }
  get showHOABoardMember() {
    return this.intakeRecord.HOA_Board_Member_Status__c === "Yes";
  }
  get showHOAIssueOther() {
    return this.intakeRecord.HOA_Issue_Category__c?.includes("Other");
  }
  get showHOAResolutionAttempts() {
    return this.intakeRecord.HOA_Resolution_Attempts__c === "Yes";
  }
  get showHOALegalAction() {
    return this.intakeRecord.HOA_Legal_Action_Initiated__c === "Yes";
  }
  get showHOAOutcomeOther() {
    return this.intakeRecord.HOA_Desired_Outcome__c?.includes("Other");
  }

  // --- General Information Section ---
  get showLegalMatterOtherSpecify() {
    return this.selectedMatterTypes.includes("Other");
  }
  get showAccommodations() {
    return this.intakeRecord.Require_Appointment_Accommodations__c === "Yes";
  }
  get showHowHearAdvertisement() {
    return this.intakeRecord.How_Did_You_Hear__c === "Advertisement";
  }
  get showHowHearReferral() {
    return this.intakeRecord.How_Did_You_Hear__c === "Referral";
  }
  get showHowHearSocialMedia() {
    return this.intakeRecord.How_Did_You_Hear__c === "Social Media";
  }
  get showHowHearOther() {
    return this.intakeRecord.How_Did_You_Hear__c === "Other";
  }
  get showWorkedWithUsBefore() {
    return this.intakeRecord.Worked_With_Us_Before__c === "Yes";
  }
  get showPriorAttorneys() {
    return this.intakeRecord.Spoken_With_Other_Attorneys__c === "Yes";
  }
  get showPriorAttorneyCost() {
    return this.intakeRecord.Reason_No_Hire_Prior_Attorney__c === "Cost";
  }
  get showPriorAttorneyOther() {
    return this.intakeRecord.Reason_No_Hire_Prior_Attorney__c === "Other";
  }
  get showCurrentlyRepresented() {
    return this.intakeRecord.Currently_Represented__c === "Yes";
  }

  // --- Criminal Law Section ---
  get showCLInvestigatingAgencyPolice() {
    return this.intakeRecord.CL_Investigating_Agency__c === "Police Department";
  }
  get showCLInvestigatingAgencyOther() {
    return this.intakeRecord.CL_Investigating_Agency__c === "Other";
  }
  get showCLCaseFiled() {
    return this.intakeRecord.CL_Case_Filed__c === "Yes";
  }
  get showCLUnderInvestigation() {
    return this.intakeRecord.CL_Case_Filed__c === "No";
  }
  get showCLCaseStatusOther() {
    return this.intakeRecord.CL_Case_Status__c === "Other";
  }
  get showCLCaseInvolvementOther() {
    return this.intakeRecord.CL_Case_Involvement_Types__c?.includes("Other");
  }
  get showCLDUI() {
    return this.intakeRecord.CL_Case_Involvement_Types__c?.includes("DUI/DWI");
  }
  get showCLDUIPulledOverOther() {
    return this.intakeRecord.CL_DUI_Pulled_Over_Reason__c === "Other";
  }
  get showCLDUIPriorConvictions() {
    return this.intakeRecord.CL_DUI_Prior_Convictions__c === "Yes";
  }
  get showCLRecordSealing() {
    return this.intakeRecord.CL_Case_Involvement_Types__c?.includes(
      "Record Sealing"
    );
  }
  get showCLDomesticViolence() {
    return this.intakeRecord.CL_Case_Involvement_Types__c?.includes(
      "Domestic Violence"
    );
  }
  get showDVAbuseTypeOther() {
    return this.intakeRecord.DV_Types_Of_Abuse__c?.includes("Other");
  }
  get showDVPerpetratorOther() {
    return this.intakeRecord.DV_Perpetrator_Identity__c === "Other";
  }
  get showDVPerpetratorFamily() {
    return (
      this.intakeRecord.DV_Relationship_To_Perpetrator__c === "Family member"
    );
  }
  get showDVRelationshipOther() {
    return this.intakeRecord.DV_Relationship_To_Perpetrator__c === "Other";
  }
  get showDVSupportServicesOther() {
    return this.intakeRecord.DV_Receiving_Support_Services__c?.includes(
      "Other"
    );
  }

  // --- Family Law Section ---
  get showFLPropertyDivision() {
    return this.intakeRecord.FL_Divorce_Property_Division__c === "Yes";
  }

  // --- Probate/Estate Planning Section ---
  get showPERelationshipOther() {
    return this.intakeRecord.PE_PC_Relationship_To_Deceased__c === "Other";
  }
  get showPEProbateOpened() {
    return this.intakeRecord.PE_Probate_Estate_Opened__c === "Yes";
  }
  get showPEAssetOther() {
    return this.intakeRecord.PE_Decedent_Asset_Types__c?.includes("Other");
  }
  get showEPDocumentsOther() {
    return this.intakeRecord.EP_Documents_Needed__c?.includes("Other");
  }

  // --- Real Estate Section ---
  get showRELegalAction() {
    return this.intakeRecord.RE_Dispute_Legal_Action_Taken__c === "Yes";
  }
  get showREEnvZoning() {
    return this.intakeRecord.RE_Environmental_Zoning_Issues__c === "Yes";
  }
  get showREHOA() {
    return this.intakeRecord.RE_Property_In_HOA__c === "Yes";
  }
  get showPIYourRoleOther() {
    return this.intakeRecord.PI_Your_Role__c === "Other";
  }
  get showPIMedicalTreatment() {
    return this.intakeRecord.PI_Received_Medical_Treatment__c === "Yes";
  }
  get showPIWitnesses() {
    return this.intakeRecord.PI_Incident_Witnesses__c === "Yes";
  }
  get showPIPoliceReport() {
    return this.intakeRecord.PI_Police_Report_Filed__c === "Yes";
  }
  get showPIInsurance() {
    return this.intakeRecord.PI_Has_Insurance_Coverage__c === "Yes";
  }
  get showPIOtherInsurance() {
    return this.intakeRecord.PI_Other_Party_Has_Insurance__c === "Yes";
  }
  get showPIDamagesSoughtOther() {
    return this.intakeRecord.PI_Damages_Sought__c === "Other";
  }

  // --- Civil Litigation Section ---
  get showCLITClaimBasisOther() {
    return this.intakeRecord.CLIT_Claim_Basis__c === "Other";
  }
  get showCLITLawsuitsFiled() {
    return this.intakeRecord.CLIT_Lawsuits_Filed__c === "Yes";
  }

  // --- Employment Law Section ---
  get showEMPLIssueOther() {
    return this.intakeRecord.EMPL_Employment_Issue_Type__c === "Other";
  }
  get showEMPLOutcomeOther() {
    return this.intakeRecord.EMPL_Desired_Outcome__c?.includes("Other");
  }
  get showEMPLGovComplaint() {
    return this.intakeRecord.EMPL_Filed_Gov_Complaint__c === "Yes";
  }
  get showEMPLEmployerReason() {
    return this.intakeRecord.EMPL_Employer_Reason_Given__c === "Yes";
  }
  get showEMPLWarnings() {
    return this.intakeRecord.EMPL_Received_Warnings__c === "Yes";
  }
  get showEMPLSeverance() {
    return this.intakeRecord.EMPL_Severance_Offered__c === "Yes";
  }
  get showEMPLUnpaidWages() {
    return this.intakeRecord.EMPL_Unpaid_Wages__c === "Yes";
  }
  get showEMPLReportedMisconduct() {
    return this.intakeRecord.EMPL_Reported_Misconduct__c === "Yes";
  }
  get showEMPLRetaliation() {
    return this.intakeRecord.EMPL_Experienced_Retaliation__c === "Yes";
  }
  get showEMPLSignedAgreements() {
    return this.intakeRecord.EMPL_Signed_Agreements__c === "Yes";
  }
  get showEMPLHasAttorney() {
    return this.intakeRecord.EMPL_Has_Attorney__c === "Yes";
  }
  get showEMPLEEOCComplaint() {
    return this.intakeRecord.EMPL_Filed_EEOC_Complaint__c === "Yes";
  }
  get showEMPLRightToSue() {
    return this.intakeRecord.EMPL_Received_Right_To_Sue__c === "Yes";
  }

  // --- Landlord/Tenant Section ---
  get isLandlord() {
    return this.intakeRecord.LT_Role__c === "Landlord";
  }
  get isTenant() {
    return this.intakeRecord.LT_Role__c === "Tenant";
  }

  // --- Business Law Section ---
  get showBusContractDraftTypeOther() {
    return this.intakeRecord.BUS_Contract_Draft_Type__c === "Other";
  }
  get showBusPurchaseSaleInclusionsOther() {
    return this.intakeRecord.BUS_Purchase_Sale_Inclusions__c?.includes("Other");
  }

  // --- Defamation Section ---
  get isDefamationPlaintiff() {
    return (
      this.intakeRecord.DEF_Involvement_Type__c ===
      "I am the victim of defamatory statements made by someone else (Plaintiff)"
    );
  }
  get isDefamationDefendant() {
    return (
      this.intakeRecord.DEF_Involvement_Type__c ===
      "I am accused of making defamatory statements (Defendant)"
    );
  }
  get showDEFRelationshipOther() {
    return this.intakeRecord.DEF_Relationship_Nature__c === "Other";
  }
  get showDEFStatementTypesOther() {
    return this.intakeRecord.DEF_Statement_Types__c?.includes("Other");
  }
  get showDEFWrittenStatements() {
    return this.intakeRecord.DEF_Written_Statements__c === "Yes";
  }
  get showDEFPublicationMediumOther() {
    return this.intakeRecord.DEF_Publication_Medium__c === "Other";
  }
  get showDEFVerbalStatements() {
    return this.intakeRecord.DEF_Verbal_Statements__c === "Yes";
  }
  get showDEFPublicFigure() {
    return this.intakeRecord.DEF_Public_Figure__c === "Yes";
  }
  get showDEFBusinessCapacity() {
    return this.intakeRecord.DEF_Business_Capacity__c === "Yes";
  }
  get showDEFSufferedHarm() {
    return this.intakeRecord.DEF_Suffered_Harm__c === "Yes";
  }
  get showDEFHarmTypesOther() {
    return this.intakeRecord.DEF_Harm_Types__c?.includes("Other");
  }
  get showDEFCanEstimateLosses() {
    return this.intakeRecord.DEF_Can_Estimate_Losses__c === "Yes";
  }
  get showDEFPlaintiffFinancialLosses() {
    return this.intakeRecord.DEF_Plaintiff_Financial_Losses__c === "Yes";
  }
  get showDEFReputationImpactOther() {
    return this.intakeRecord.DEF_Reputation_Impact__c?.includes("Other");
  }
  get showDEFReputationRepairSteps() {
    return this.intakeRecord.DEF_Reputation_Repair_Steps__c === "Yes";
  }
  get showDEFResponseActionsOther() {
    return this.intakeRecord.DEF_Response_Actions__c?.includes("Other");
  }
  get showDEFReceivedCompensation() {
    return this.intakeRecord.DEF_Received_Compensation__c === "Yes";
  }
  get showDEFHasEvidence() {
    return this.intakeRecord.DEF_Has_Evidence__c === "Yes";
  }
  get showDEFEvidenceTypesOther() {
    return this.intakeRecord.DEF_Evidence_Types__c?.includes("Other");
  }
  get showDEFDefendantDidNotMake() {
    return this.intakeRecord.DEF_Defendant_Made_Statements__c === "No";
  }
  get showDEFDefendantIntentOther() {
    return this.intakeRecord.DEF_Defendant_Intent__c === "Other";
  }
  get showDEFDefendantContextOther() {
    return this.intakeRecord.DEF_Defendant_Context__c === "Other";
  }
  get showDEFDefendantVerifiedFacts() {
    return this.intakeRecord.DEF_Defendant_Verified_Facts__c === "Yes";
  }
  get showDEFDefendantDoesNotBelieve() {
    return this.intakeRecord.DEF_Defendant_Still_Believes__c === "No";
  }
  get showDEFDefendantHasEvidence() {
    return this.intakeRecord.DEF_Defendant_Has_Evidence__c === "Yes";
  }
  get showDEFDefendantMadeRetraction() {
    return this.intakeRecord.DEF_Defendant_Made_Retraction__c === "Yes";
  }
  get showDEFDefendantLegalDefenses() {
    return this.intakeRecord.DEF_Defendant_Legal_Defenses__c === "Yes";
  }
  get showDEFDefendantLegalPrivilege() {
    return this.intakeRecord.DEF_Defendant_Legal_Privilege__c === "Yes";
  }
  get showDEFPlaintiffSeekingDamages() {
    return this.intakeRecord.DEF_Plaintiff_Seeking_Damages__c === "Yes";
  }
  get showDEFDamagesNotReasonable() {
    return this.intakeRecord.DEF_Damages_Claim_Reasonable__c === "No";
  }
  get showDEFResolutionEffortsOther() {
    return this.intakeRecord.DEF_Resolution_Efforts__c?.includes("Other");
  }
  get showDEFOpenToSettlement() {
    return this.intakeRecord.DEF_Open_To_Settlement__c === "Yes";
  }

  // Legacy defamation getters for backward compatibility
  get showDefStatementContentOther() {
    return this.intakeRecord.DEF_Statement_Content_Types__c?.includes("Other");
  }
  get showDefWrittenDetails() {
    return this.intakeRecord.DEF_Statements_In_Writing__c === "Yes";
  }
  get showDefSpokenDetails() {
    return this.intakeRecord.DEF_Statements_Spoken__c === "Yes";
  }

  // --- Construction Section ---
  get showConstTypeOther() {
    return this.intakeRecord.CONST_Construction_Type__c === "Other";
  }
  get showConstScopeOther() {
    return this.intakeRecord.CONST_Project_Scope__c === "Other";
  }
  get showConstIssueNatureOther() {
    return this.intakeRecord.CONST_Issue_Nature__c?.includes("Other");
  }
  get showConstDefectTypesOther() {
    return this.intakeRecord.CONST_Defect_Types__c?.includes("Other");
  }
  get showConstLawsuitDetails() {
    return this.intakeRecord.CONST_Lawsuit_Initiated__c === "Yes";
  }
  get showConstExpertInspection() {
    return this.intakeRecord.CONST_Expert_Inspection__c === "Yes";
  }
  get showConstIssuesCommunicated() {
    return this.intakeRecord.CONST_Issues_Communicated__c === "Yes";
  }
  get showConstCorrectiveWork() {
    return this.intakeRecord.CONST_Corrective_Work_Offered__c === "Yes";
  }
  get showConstCDARANotice() {
    return this.intakeRecord.CONST_CDARA_Notice_Status__c === "Yes";
  }
  get showConstCDARAResponse() {
    return this.intakeRecord.CONST_CDARA_Response_Provided__c === "Yes";
  }
  get showConstWarrantyClause() {
    return this.intakeRecord.CONST_Contract_Has_Warranty_Clause__c === "Yes";
  }
  get showConstConstructionLiens() {
    return this.intakeRecord.CONST_Construction_Liens__c === "Yes";
  }
  get showConstWarrantiesInEffect() {
    return this.intakeRecord.CONST_Warranties_In_Effect__c === "Yes";
  }
  get showConstPaymentClaims() {
    return this.intakeRecord.CONST_Payment_Claims_Filed__c === "Yes";
  }
  get showConstUnpaidInvoices() {
    return this.intakeRecord.CONST_Unpaid_Invoices__c === "Yes";
  }
  get showConstSupportingEvidence() {
    return this.intakeRecord.CONST_Has_Supporting_Evidence__c === "Yes";
  }
  get showConstOutcomeOther() {
    return this.intakeRecord.CONST_Desired_Outcome__c?.includes("Other");
  }

  // --- Guardianship/Conservatorship Section ---
  get showGCAlreadyAppointed() {
    const involvement = this.intakeRecord.GC_Involvement_Type__c || [];
    return (
      involvement.includes("Already appointed as a Guardian") ||
      involvement.includes("Already appointed as a Conservator") ||
      involvement.includes(
        "Already appointed as both a Guardian and Conservator"
      )
    );
  }
  get showGCEmergency() {
    return this.intakeRecord.GC_Is_Emergency_Situation__c === "Yes";
  }
  get showGCRealEstateDetails() {
    return this.intakeRecord.GC_Ward_Owns_Real_Estate_CO__c === "Yes";
  }
  get showGCIncomeSource() {
    return this.intakeRecord.GC_Ward_Has_Income_Source__c === "Yes";
  }
  get showGCLiabilities() {
    return this.intakeRecord.GC_Ward_Has_Liabilities__c === "Yes";
  }
  get showGCExistingProceedings() {
    return this.intakeRecord.GC_Respondent_In_Existing_Proceedings__c === "Yes";
  }
  get showGCTransfer() {
    return (
      this.intakeRecord.GC_Respondent_Prev_Appointed_Other_State__c === "Yes"
    );
  }
  get showGCAssistanceOther() {
    return this.intakeRecord.GC_Assistance_Needed_Types__c?.includes("Other");
  }

  // --- Closing Questions Section ---
  get showCQDocsForReview() {
    return this.intakeRecord.CQ_Docs_For_Review__c === "Yes";
  }

  // --- UTILITY METHODS ---
  reduceErrors = (errors) => {
    if (!Array.isArray(errors)) errors = [errors];
    return errors
      .filter((error) => !!error)
      .map((error) => {
        if (Array.isArray(error.body)) return error.body.map((e) => e.message);
        if (error.body && typeof error.body.message === "string")
          return error.body.message;
        if (typeof error.message === "string") return error.message;
        return error.statusText;
      })
      .reduce((prev, curr) => prev.concat(curr), [])
      .filter((message) => !!message);
  };

  showToast(title, message, variant = "info", mode = "dismissable") {
    this.dispatchEvent(new ShowToastEvent({ title, message, variant, mode }));
  }

  // --- LEAD SEARCH METHODS ---
  handleSearchTermChange(event) {
    this.searchTerm = event.target.value;
  }

  handleSearch() {
    if (this.searchTerm.length < 2) {
      this.showToast(
        "Search Error",
        "Please enter at least 2 characters to search.",
        "error"
      );
      return;
    }

    this.isLoading = true;
    searchLeads({ searchTerm: this.searchTerm })
      .then((result) => {
        this.searchResults = result;
        if (result.length === 0) {
          this.showToast(
            "No Results",
            "No leads found matching your search criteria.",
            "info"
          );
        }
      })
      .catch((error) => {
        this.showToast("Search Error", this.reduceErrors(error)[0], "error");
      })
      .finally(() => {
        this.isLoading = false;
      });
  }

  handleSearchKeyUp(event) {
    // Allow search on Enter key
    if (event.keyCode === 13) {
      this.handleSearch();
    }
  }

  handleLeadSelection(event) {
    const leadId = event.currentTarget.dataset.leadId;
    this.currentLeadId = leadId;
    this.selectedLeadId = leadId;
    this.showLeadSearch = false;

    // Refresh the component with the selected lead
    return refreshApex(this._wiredIntakesResult);
  }

  handleBackToSearch() {
    this.showLeadSearch = true;
    this.showForm = false;
    this.selectedLeadId = null;
    this.currentLeadId = null;
  }

  // --- ADDITIONAL FIELD HANDLERS ---
  handleAdditionalFieldChange(event) {
    const fieldName = event.target.dataset.field;
    const value =
      event.target.type === "checkbox"
        ? event.target.checked
        : event.target.value;
    this.additionalDetails = { ...this.additionalDetails, [fieldName]: value };
  }

  // Getter to check if component is on Home page
  get isHomePage() {
    return !this.recordId && !this.currentLeadId;
  }

  get displayLeadSearch() {
    return this.showLeadSearch && !this.recordId;
  }

  get displayIntakeList() {
    return (
      !this.showLeadSearch &&
      (this.recordId || this.currentLeadId) &&
      !this.showForm
    );
  }

  // Category Options
  get categoryOptions() {
    const typeOfLaw = this.intakeRecord.Type_of_Law__c;
    const typeOfCivilLaw = this.intakeRecord.Type_of_Civil_Law__c;

    let availableCategories = [];

    if (typeOfLaw === "Criminal") {
      availableCategories = CATEGORY_DEPENDENCY_MAP.Criminal;
    } else if (typeOfLaw === "Civil" && typeOfCivilLaw) {
      // Look up the sub-map for Civil law and find the options for the selected civil type
      availableCategories = CATEGORY_DEPENDENCY_MAP.Civil[typeOfCivilLaw] || [];
    }

    // Convert the array of strings into the { label, value } format required by lightning-combobox
    return availableCategories.map((cat) => ({ label: cat, value: cat }));
  }

  get subcategoryOptions() {
    const typeOfCivilLaw = this.intakeRecord.Type_of_Civil_Law__c;
    const category = this.intakeRecord.Category__c;

    let availableCategories = [];

    if (category) {
      if (typeOfCivilLaw === "Pre-Litigation") {
        availableCategories =
          SUBCATEGORY_DEPENDENCY_MAP.PreLitigation[category] || [];
      } else if (typeOfCivilLaw === "Litigation") {
        availableCategories =
          SUBCATEGORY_DEPENDENCY_MAP.Litigation[category] || [];
      } else if (typeOfCivilLaw === "Transactional") {
        availableCategories =
          SUBCATEGORY_DEPENDENCY_MAP.Transactional[category] || [];
      }
    }

    // Convert the array of strings into the { label, value } format required by lightning-combobox
    return availableCategories.map((cat) => ({ label: cat, value: cat }));
  }

  // HOA Options
  get hoaGoverningDocumentsOptions() {
    return (
      this.picklistValues.HOA_Governing_Documents__c || [
        { label: "HOA Declaration (CC&Rs)", value: "HOA Declaration (CC&Rs)" },
        { label: "Bylaws", value: "Bylaws" },
        {
          label: "Articles of Incorporation",
          value: "Articles of Incorporation"
        },
        {
          label: "HOA Rules and Regulations",
          value: "HOA Rules and Regulations"
        },
        { label: "Other", value: "Other" },
        { label: "None", value: "None" }
      ]
    );
  }

  get hoaCanProvideDocumentsOptions() {
    return (
      this.picklistValues.HOA_Can_Provide_Documents__c || [
        { label: "Yes", value: "Yes" },
        { label: "No", value: "No" },
        {
          label: "Will provide upon request",
          value: "Will provide upon request"
        }
      ]
    );
  }

  get hoaBoardMemberStatusOptions() {
    return (
      this.picklistValues.HOA_Board_Member_Status__c || [
        { label: "Yes", value: "Yes" },
        { label: "No", value: "No" },
        { label: "Former Board Member", value: "Former Board Member" }
      ]
    );
  }

  get dvEvidenceOptions() {
    return [
      { label: "Photos of injuries", value: "Photos" },
      { label: "Medical records", value: "Medical" },
      { label: "Text messages", value: "Texts" },
      { label: "Emails", value: "Emails" },
      { label: "Witness statements", value: "Witnesses" },
      { label: "Police reports", value: "Police" },
      { label: "Other", value: "Other" }
    ];
  }

  get flAssetTypesOptions() {
    return [
      { label: "Real estate", value: "RealEstate" },
      { label: "Vehicles", value: "Vehicles" },
      { label: "Bank accounts", value: "BankAccounts" },
      { label: "Retirement accounts", value: "Retirement" },
      { label: "Investments", value: "Investments" },
      { label: "Business interests", value: "Business" },
      { label: "Personal property", value: "Personal" },
      { label: "Debts", value: "Debts" }
    ];
  }

  get custodyOptions() {
    return [
      { label: "Joint custody", value: "Joint" },
      { label: "Sole custody", value: "Sole" },
      { label: "Split custody", value: "Split" },
      { label: "Undecided", value: "Undecided" }
    ];
  }

  get epDocumentsOptions() {
    return [
      { label: "Will", value: "Will" },
      { label: "Living Will", value: "LivingWill" },
      { label: "Power of Attorney", value: "POA" },
      { label: "Healthcare Directive", value: "Healthcare" },
      { label: "Trust", value: "Trust" },
      { label: "Guardianship Documents", value: "Guardianship" }
    ];
  }

  get trustTypeOptions() {
    return [
      { label: "Revocable Living Trust", value: "Revocable" },
      { label: "Irrevocable Trust", value: "Irrevocable" },
      { label: "Special Needs Trust", value: "SpecialNeeds" },
      { label: "Charitable Trust", value: "Charitable" },
      { label: "Not sure", value: "NotSure" }
    ];
  }

  get propertyIssuesOptions() {
    return [
      { label: "Foundation issues", value: "Foundation" },
      { label: "Roof problems", value: "Roof" },
      { label: "Plumbing issues", value: "Plumbing" },
      { label: "Electrical problems", value: "Electrical" },
      { label: "HVAC issues", value: "HVAC" },
      { label: "Water damage", value: "Water" },
      { label: "Pest infestation", value: "Pest" },
      { label: "Environmental hazards", value: "Environmental" }
    ];
  }

  get landlordTenantOptions() {
    return [
      { label: "Landlord", value: "Landlord" },
      { label: "Tenant", value: "Tenant" }
    ];
  }

  get defamationMethodOptions() {
    return [
      { label: "Written (libel)", value: "Written" },
      { label: "Spoken (slander)", value: "Spoken" },
      { label: "Online/Social Media", value: "Online" },
      { label: "Broadcast (TV/Radio)", value: "Broadcast" },
      { label: "Multiple methods", value: "Multiple" }
    ];
  }

  get defamationEvidenceOptions() {
    return [
      { label: "Screenshots", value: "Screenshots" },
      { label: "Recordings", value: "Recordings" },
      { label: "Witness testimony", value: "Witnesses" },
      { label: "Written documents", value: "Documents" },
      { label: "Video evidence", value: "Video" },
      { label: "News articles", value: "NewsArticles" },
      { label: "Social media posts", value: "SocialMedia" }
    ];
  }

  get defamationDamagesOptions() {
    return [
      { label: "Lost employment", value: "LostJob" },
      { label: "Lost business opportunities", value: "LostBusiness" },
      { label: "Emotional distress", value: "Emotional" },
      { label: "Damage to reputation", value: "Reputation" },
      { label: "Loss of clients/customers", value: "LostClients" },
      { label: "Medical expenses", value: "Medical" },
      { label: "Other financial losses", value: "OtherFinancial" }
    ];
  }

  get showDefamation() {
    return (
      this.intakeRecord.Legal_Matter_Type__c &&
      Array.isArray(this.intakeRecord.Legal_Matter_Type__c) &&
      this.intakeRecord.Legal_Matter_Type__c.includes("Defamation")
    );
  }

  // Additional getter methods for fields that need default options
  get hoaIssueCategoryOptions() {
    return (
      this.picklistValues.HOA_Issue_Category__c || [
        { label: "Financial disputes", value: "Financial disputes" },
        { label: "Architectural issues", value: "Architectural issues" },
        { label: "Maintenance problems", value: "Maintenance problems" },
        { label: "Rule violations", value: "Rule violations" },
        { label: "Board disputes", value: "Board disputes" },
        { label: "Assessment issues", value: "Assessment issues" },
        { label: "Other", value: "Other" }
      ]
    );
  }

  get hoaLegalStatusOptions() {
    return (
      this.picklistValues.HOA_Legal_Status__c || [
        { label: "Not filed", value: "Not filed" },
        { label: "Pending", value: "Pending" },
        { label: "In mediation", value: "In mediation" },
        { label: "In litigation", value: "In litigation" },
        { label: "Resolved", value: "Resolved" }
      ]
    );
  }

  get hoaDesiredOutcomeOptions() {
    return (
      this.picklistValues.HOA_Desired_Outcome__c || [
        { label: "Monetary compensation", value: "Monetary compensation" },
        { label: "Stop harassment", value: "Stop harassment" },
        { label: "Board accountability", value: "Board accountability" },
        { label: "Rule enforcement", value: "Rule enforcement" },
        { label: "Assessment adjustment", value: "Assessment adjustment" },
        { label: "Other", value: "Other" }
      ]
    );
  }

  get employmentIssueTypeOptions() {
    return (
      this.picklistValues.EMPL_Employment_Issue_Type__c || [
        { label: "Wrongful termination", value: "Wrongful termination" },
        { label: "Discrimination", value: "Discrimination" },
        { label: "Harassment", value: "Harassment" },
        {
          label: "Wage and hour violations",
          value: "Wage and hour violations"
        },
        { label: "Retaliation", value: "Retaliation" },
        {
          label: "Family/medical leave issues",
          value: "Family/medical leave issues"
        },
        { label: "Other", value: "Other" }
      ]
    );
  }

  get employmentIssueStageOptions() {
    return (
      this.picklistValues.EMPL_Issue_Stage__c || [
        { label: "Recently occurred", value: "Recently occurred" },
        { label: "Ongoing", value: "Ongoing" },
        { label: "Under investigation", value: "Under investigation" },
        { label: "Resolved internally", value: "Resolved internally" },
        { label: "Legal action pending", value: "Legal action pending" }
      ]
    );
  }

  get employmentPayFrequencyOptions() {
    return (
      this.picklistValues.EMPL_Pay_Frequency__c || [
        { label: "Hourly", value: "Hourly" },
        { label: "Weekly", value: "Weekly" },
        { label: "Bi-weekly", value: "Bi-weekly" },
        { label: "Monthly", value: "Monthly" },
        { label: "Annually", value: "Annually" }
      ]
    );
  }

  get employmentOvertimeClassificationOptions() {
    return (
      this.picklistValues.EMPL_Overtime_Classification__c || [
        { label: "Exempt", value: "Exempt" },
        { label: "Non-exempt", value: "Non-exempt" },
        { label: "Not sure", value: "Not sure" }
      ]
    );
  }

  get employmentCurrentBenefitsOptions() {
    return (
      this.picklistValues.EMPL_Current_Benefits__c || [
        { label: "Health insurance", value: "Health insurance" },
        { label: "Dental insurance", value: "Dental insurance" },
        { label: "Vision insurance", value: "Vision insurance" },
        {
          label: "401(k) or retirement plan",
          value: "401(k) or retirement plan"
        },
        { label: "Paid time off", value: "Paid time off" },
        { label: "Life insurance", value: "Life insurance" },
        { label: "Disability insurance", value: "Disability insurance" },
        { label: "Other", value: "Other" }
      ]
    );
  }

  get employmentWorkEnvironmentOptions() {
    return (
      this.picklistValues.EMPL_Work_Environment__c || [
        { label: "Professional", value: "Professional" },
        { label: "Hostile", value: "Hostile" },
        { label: "Discriminatory", value: "Discriminatory" },
        { label: "Harassing", value: "Harassing" },
        { label: "Unsafe", value: "Unsafe" },
        { label: "Supportive", value: "Supportive" },
        { label: "Other", value: "Other" }
      ]
    );
  }

  get employmentFilingAgencyOptions() {
    return (
      this.picklistValues.EMPL_Filing_Agency__c || [
        { label: "EEOC (Federal)", value: "EEOC (Federal)" },
        {
          label: "Colorado Civil Rights Division",
          value: "Colorado Civil Rights Division"
        },
        { label: "Department of Labor", value: "Department of Labor" },
        { label: "Other state agency", value: "Other state agency" },
        { label: "Other federal agency", value: "Other federal agency" }
      ]
    );
  }

  get employmentDesiredOutcomeOptions() {
    return (
      this.picklistValues.EMPL_Desired_Outcome__c || [
        { label: "Monetary compensation", value: "Monetary compensation" },
        { label: "Reinstatement", value: "Reinstatement" },
        { label: "Policy changes", value: "Policy changes" },
        {
          label: "Disciplinary action against wrongdoer",
          value: "Disciplinary action against wrongdoer"
        },
        { label: "Training for management", value: "Training for management" },
        { label: "Accommodation", value: "Accommodation" },
        { label: "Other", value: "Other" }
      ]
    );
  }

  get defamationStatementTypesOptions() {
    return (
      this.picklistValues.DEF_Statement_Types__c || [
        { label: "Written statement", value: "Written statement" },
        { label: "Verbal statement", value: "Verbal statement" },
        { label: "Online post", value: "Online post" },
        { label: "Social media", value: "Social media" },
        { label: "Email", value: "Email" },
        { label: "Text message", value: "Text message" },
        { label: "Published article", value: "Published article" },
        { label: "Broadcast statement", value: "Broadcast statement" }
      ]
    );
  }

  get defamationVerbalSettingOptions() {
    return (
      this.picklistValues.DEF_Verbal_Setting_Type__c || [
        { label: "Private conversation", value: "Private conversation" },
        { label: "Public meeting", value: "Public meeting" },
        { label: "Workplace discussion", value: "Workplace discussion" },
        { label: "Social gathering", value: "Social gathering" },
        { label: "Phone conversation", value: "Phone conversation" },
        { label: "Other", value: "Other" }
      ]
    );
  }

  get defamationHarmTypesOptions() {
    return (
      this.picklistValues.DEF_Harm_Types__c || [
        { label: "Loss of employment", value: "Loss of employment" },
        { label: "Loss of business", value: "Loss of business" },
        { label: "Damage to reputation", value: "Damage to reputation" },
        { label: "Emotional distress", value: "Emotional distress" },
        { label: "Loss of relationships", value: "Loss of relationships" },
        { label: "Financial losses", value: "Financial losses" },
        { label: "Other", value: "Other" }
      ]
    );
  }

  get defamationReputationImpactOptions() {
    return (
      this.picklistValues.DEF_Reputation_Impact__c || [
        {
          label: "Professional reputation damaged",
          value: "Professional reputation damaged"
        },
        {
          label: "Personal reputation damaged",
          value: "Personal reputation damaged"
        },
        {
          label: "Business reputation damaged",
          value: "Business reputation damaged"
        },
        {
          label: "Community standing affected",
          value: "Community standing affected"
        },
        {
          label: "Online reputation damaged",
          value: "Online reputation damaged"
        }
      ]
    );
  }

  get defamationResponseActionsOptions() {
    return (
      this.picklistValues.DEF_Response_Actions__c || [
        {
          label: "Contacted the person directly",
          value: "Contacted the person directly"
        },
        {
          label: "Sent cease and desist letter",
          value: "Sent cease and desist letter"
        },
        {
          label: "Reported to platform/website",
          value: "Reported to platform/website"
        },
        { label: "Consulted with attorney", value: "Consulted with attorney" },
        { label: "Filed police report", value: "Filed police report" },
        {
          label: "Documented the statements",
          value: "Documented the statements"
        },
        { label: "No action taken yet", value: "No action taken yet" }
      ]
    );
  }

  get defamationEvidenceTypesOptions() {
    return (
      this.picklistValues.DEF_Evidence_Types__c || [
        { label: "Screenshots", value: "Screenshots" },
        { label: "Audio recordings", value: "Audio recordings" },
        { label: "Video recordings", value: "Video recordings" },
        { label: "Written documents", value: "Written documents" },
        { label: "Witness statements", value: "Witness statements" },
        { label: "Email communications", value: "Email communications" },
        { label: "Text messages", value: "Text messages" },
        { label: "Social media posts", value: "Social media posts" }
      ]
    );
  }

  get defamationDefendantIntentOptions() {
    return (
      this.picklistValues.DEF_Defendant_Intent__c || [
        { label: "To inform others", value: "To inform others" },
        { label: "To express opinion", value: "To express opinion" },
        { label: "To warn others", value: "To warn others" },
        { label: "In response to question", value: "In response to question" },
        { label: "In jest/humor", value: "In jest/humor" },
        { label: "In anger/frustration", value: "In anger/frustration" },
        { label: "Other", value: "Other" }
      ]
    );
  }

  get defamationDefendantContextOptions() {
    return (
      this.picklistValues.DEF_Defendant_Context__c || [
        { label: "Casual conversation", value: "Casual conversation" },
        { label: "Business discussion", value: "Business discussion" },
        { label: "Online review", value: "Online review" },
        { label: "Social media comment", value: "Social media comment" },
        { label: "Professional evaluation", value: "Professional evaluation" },
        { label: "Legal proceeding", value: "Legal proceeding" },
        { label: "Other", value: "Other" }
      ]
    );
  }

  get defamationDefendantCapacityOptions() {
    return (
      this.picklistValues.DEF_Defendant_Capacity__c || [
        { label: "As a private individual", value: "As a private individual" },
        { label: "As an employee", value: "As an employee" },
        { label: "As a business owner", value: "As a business owner" },
        { label: "As a professional", value: "As a professional" },
        { label: "As a public official", value: "As a public official" },
        {
          label: "As a journalist/reporter",
          value: "As a journalist/reporter"
        },
        { label: "Other", value: "Other" }
      ]
    );
  }

  get defamationResolutionEffortsOptions() {
    return (
      this.picklistValues.DEF_Resolution_Efforts__c || [
        { label: "Direct communication", value: "Direct communication" },
        { label: "Mediation", value: "Mediation" },
        { label: "Arbitration", value: "Arbitration" },
        { label: "Cease and desist letter", value: "Cease and desist letter" },
        { label: "Demand for retraction", value: "Demand for retraction" },
        { label: "No attempts made", value: "No attempts made" },
        { label: "Other", value: "Other" }
      ]
    );
  }

  get constructionPropertyTypeOptions() {
    return (
      this.picklistValues.CONST_Property_Type__c || [
        { label: "Single-family home", value: "Single-family home" },
        { label: "Condominium", value: "Condominium" },
        { label: "Townhome", value: "Townhome" },
        { label: "Commercial building", value: "Commercial building" },
        { label: "Multi-family building", value: "Multi-family building" },
        { label: "Other", value: "Other" }
      ]
    );
  }

  get constructionProjectScopeOptions() {
    return (
      this.picklistValues.CONST_Project_Scope__c || [
        { label: "New construction", value: "New construction" },
        { label: "Addition", value: "Addition" },
        { label: "Renovation", value: "Renovation" },
        { label: "Repair", value: "Repair" },
        { label: "Maintenance", value: "Maintenance" },
        { label: "Other", value: "Other" }
      ]
    );
  }

  get constructionIssueNatureOptions() {
    return (
      this.picklistValues.CONST_Issue_Nature__c || [
        { label: "Construction defects", value: "Construction defects" },
        { label: "Contract disputes", value: "Contract disputes" },
        { label: "Payment disputes", value: "Payment disputes" },
        { label: "Delay issues", value: "Delay issues" },
        { label: "Quality issues", value: "Quality issues" },
        { label: "Safety violations", value: "Safety violations" },
        { label: "Other", value: "Other" }
      ]
    );
  }

  get constructionDefectTypesOptions() {
    return (
      this.picklistValues.CONST_Defect_Types__c || [
        { label: "Structural defects", value: "Structural defects" },
        { label: "Water intrusion", value: "Water intrusion" },
        { label: "Electrical defects", value: "Electrical defects" },
        { label: "Plumbing defects", value: "Plumbing defects" },
        { label: "HVAC defects", value: "HVAC defects" },
        { label: "Insulation defects", value: "Insulation defects" },
        { label: "Exterior defects", value: "Exterior defects" },
        { label: "Other", value: "Other" }
      ]
    );
  }

  get constructionDefectSeverityOptions() {
    return (
      this.picklistValues.CONST_Defect_Severity__c || [
        { label: "Minor", value: "Minor" },
        { label: "Moderate", value: "Moderate" },
        { label: "Major", value: "Major" },
        { label: "Severe", value: "Severe" }
      ]
    );
  }

  get constructionCDARANoticeOptions() {
    return (
      this.picklistValues.CONST_CDARA_Notice_Status__c || [
        { label: "Not applicable", value: "Not applicable" },
        { label: "Planning to serve", value: "Planning to serve" },
        { label: "Served notice", value: "Served notice" },
        { label: "Received notice", value: "Received notice" },
        { label: "Notice period expired", value: "Notice period expired" }
      ]
    );
  }

  get constructionLawsuitStatusOptions() {
    return (
      this.picklistValues.CONST_Lawsuit_Status__c || [
        { label: "No lawsuit filed", value: "No lawsuit filed" },
        { label: "Considering filing", value: "Considering filing" },
        { label: "Lawsuit filed", value: "Lawsuit filed" },
        { label: "In discovery", value: "In discovery" },
        { label: "In trial", value: "In trial" },
        { label: "Settled", value: "Settled" },
        { label: "Judgment entered", value: "Judgment entered" }
      ]
    );
  }

  get constructionDesiredOutcomeOptions() {
    return (
      this.picklistValues.CONST_Desired_Outcome__c || [
        { label: "Monetary compensation", value: "Monetary compensation" },
        { label: "Repair of defects", value: "Repair of defects" },
        { label: "Contract completion", value: "Contract completion" },
        { label: "Contract termination", value: "Contract termination" },
        { label: "Payment recovery", value: "Payment recovery" },
        { label: "Other", value: "Other" }
      ]
    );
  }

  // Family Law getter methods
  get familyLawMarriageTypeOptions() {
    return (
      this.picklistValues.FL_Marriage_Type__c || [
        {
          label: "Traditional (ceremonial)",
          value: "Traditional (ceremonial)"
        },
        {
          label: "Common Law (Colorado recognizes common law marriage)",
          value: "Common Law (Colorado recognizes common law marriage)"
        }
      ]
    );
  }

  get familyLawMaritalStatusOptions() {
    return (
      this.picklistValues.FL_Marital_Status__c || [
        { label: "Divorced", value: "Divorced" },
        { label: "Legally Separated", value: "Legally Separated" },
        { label: "Never Married", value: "Never Married" }
      ]
    );
  }

  get familyLawSeekingActionOptions() {
    return (
      this.picklistValues.FL_Seeking_Action__c || [
        {
          label: "Divorce (Dissolution of Marriage)",
          value: "Divorce (Dissolution of Marriage)"
        },
        { label: "Legal Separation", value: "Legal Separation" },
        {
          label: "Declaration of Invalidity (Annulment)",
          value: "Declaration of Invalidity (Annulment)"
        },
        {
          label: "Allocation of Parental Responsibilities (Custody) only",
          value: "Allocation of Parental Responsibilities (Custody) only"
        },
        {
          label: "Post-Decree Modification (e.g., support, parenting time)",
          value: "Post-Decree Modification (e.g., support, parenting time)"
        },
        { label: "Other", value: "Other" }
      ]
    );
  }

  get familyLawContestedStatusOptions() {
    return (
      this.picklistValues.FL_Divorce_Contested_Status__c || [
        {
          label:
            "Contested – Disagreement over issues such as custody, finances, or property",
          value:
            "Contested – Disagreement over issues such as custody, finances, or property"
        },
        {
          label: "Uncontested – Both parties are in agreement and cooperative",
          value: "Uncontested – Both parties are in agreement and cooperative"
        }
      ]
    );
  }

  get familyLawChildrenCountOptions() {
    return (
      this.picklistValues.FL_Children_Involved_Count__c || [
        { label: "One", value: "One" },
        { label: "Two", value: "Two" },
        { label: "Three or more", value: "Three or more" }
      ]
    );
  }

  get familyLawSeekingCustodyOptions() {
    return (
      this.picklistValues.FL_Seeking_Custody_Type__c || [
        {
          label: "Primary residential custody",
          value: "Primary residential custody"
        },
        {
          label: "Shared or joint parenting time",
          value: "Shared or joint parenting time"
        },
        {
          label: "Sole decision-making authority",
          value: "Sole decision-making authority"
        },
        { label: "Child support", value: "Child support" },
        {
          label: "Modification of current custody or support orders",
          value: "Modification of current custody or support orders"
        },
        {
          label: "Relocation with child(ren)",
          value: "Relocation with child(ren)"
        },
        {
          label: "Emergency motion due to endangerment",
          value: "Emergency motion due to endangerment"
        }
      ]
    );
  }

  get familyLawAdditionalIssuesOptions() {
    return (
      this.picklistValues.FL_Additional_Issues__c || [
        {
          label: "Domestic Violence or Protection Orders",
          value: "Domestic Violence or Protection Orders"
        },
        {
          label: "Substance abuse or addiction concerns",
          value: "Substance abuse or addiction concerns"
        },
        {
          label: "Mental health evaluations or treatment",
          value: "Mental health evaluations or treatment"
        },
        {
          label: "Child abduction or international custody",
          value: "Child abduction or international custody"
        },
        {
          label: "Prenuptial/Postnuptial Agreements",
          value: "Prenuptial/Postnuptial Agreements"
        },
        {
          label: "Guardianship or Third-Party Custody",
          value: "Guardianship or Third-Party Custody"
        },
        {
          label: "Adoption or Termination of Parental Rights",
          value: "Adoption or Termination of Parental Rights"
        },
        { label: "Other", value: "Other" }
      ]
    );
  }

  get familyLawDocumentTypesOptions() {
    return (
      this.picklistValues.FL_Document_Types_Review__c || [
        { label: "Separation Agreement", value: "Separation Agreement" },
        { label: "Parenting Plan", value: "Parenting Plan" },
        {
          label: "Temporary Orders or Proposals",
          value: "Temporary Orders or Proposals"
        },
        {
          label: "Prenuptial/Postnuptial Agreement",
          value: "Prenuptial/Postnuptial Agreement"
        },
        { label: "Other", value: "Other" }
      ]
    );
  }

  get familyLawDraftingDocumentsOptions() {
    return (
      this.picklistValues.FL_Need_Document_Drafting__c || [
        { label: "Parenting Plan", value: "Parenting Plan" },
        { label: "Separation Agreement", value: "Separation Agreement" },
        { label: "Prenuptial Agreement", value: "Prenuptial Agreement" },
        { label: "Postnuptial Agreement", value: "Postnuptial Agreement" },
        {
          label: "Financial Disclosures (e.g., Sworn Financial Statement)",
          value: "Financial Disclosures (e.g., Sworn Financial Statement)"
        },
        { label: "Other", value: "Other" }
      ]
    );
  }

  get familyLawFinancialDocsAccessOptions() {
    return (
      this.picklistValues.FL_Financial_Docs_Access__c || [
        { label: "Yes", value: "Yes" },
        { label: "No", value: "No" },
        { label: "Not sure", value: "Not sure" }
      ]
    );
  }

  get familyLawMediationStatusOptions() {
    return (
      this.picklistValues.FL_Mediation_Proposed__c || [
        { label: "Yes", value: "Yes" },
        { label: "No", value: "No" },
        { label: "Already scheduled", value: "Already scheduled" }
      ]
    );
  }

  get familyLawAttorneyMediationOptions() {
    return (
      this.picklistValues.FL_Attorney_Attend_Mediation__c || [
        { label: "Yes", value: "Yes" },
        { label: "No", value: "No" },
        {
          label: "Possibly, depending on cost",
          value: "Possibly, depending on cost"
        }
      ]
    );
  }

  get familyLawProfessionalsAppointedOptions() {
    return (
      this.picklistValues.FL_Professionals_Appointed__c || [
        { label: "Yes", value: "Yes" },
        { label: "No", value: "No" },
        { label: "Unsure", value: "Unsure" }
      ]
    );
  }

  get familyLawExpertTypesOptions() {
    return (
      this.picklistValues.FL_Expert_Types__c || [
        {
          label: "Child and Family Investigator (CFI)",
          value: "Child and Family Investigator (CFI)"
        },
        {
          label: "Parental Responsibilities Evaluator (PRE)",
          value: "Parental Responsibilities Evaluator (PRE)"
        }
      ]
    );
  }

  get familyLawUnbundledInterestOptions() {
    return (
      this.picklistValues.FL_Unbundled_Interest__c || [
        { label: "Yes", value: "Yes" },
        { label: "No", value: "No" },
        {
          label: "I'm not sure — I'd like to learn more",
          value: "I'm not sure — I'd like to learn more"
        }
      ]
    );
  }

  // Family Law conditional visibility getters
  get showFLCurrentlyMarried() {
    return this.intakeRecord.FL_Currently_Married__c === "Yes";
  }

  get showFLNotMarried() {
    return this.intakeRecord.FL_Currently_Married__c === "No";
  }

  get showFLSpouseChildrenTogether() {
    return this.intakeRecord.FL_Spouse_Children_Together__c === "Yes";
  }

  get showFLPreviouslyFiled() {
    return this.intakeRecord.FL_Previously_Filed_Family_Case__c === "Yes";
  }

  get showFLSeekingActionOther() {
    return (
      this.intakeRecord.FL_Seeking_Action__c &&
      Array.isArray(this.intakeRecord.FL_Seeking_Action__c) &&
      this.intakeRecord.FL_Seeking_Action__c.includes("Other")
    );
  }

  get showFLExistingCustodyOrders() {
    return this.intakeRecord.FL_Existing_Custody_Orders__c === "Yes";
  }

  get showFLChildSafetyConcerns() {
    return this.intakeRecord.FL_Child_Safety_Concerns__c === "Yes";
  }

  get showFLCPSReports() {
    return this.intakeRecord.FL_CPS_Reports_Made__c === "Yes";
  }

  get showFLAdditionalIssuesOther() {
    return (
      this.intakeRecord.FL_Additional_Issues__c &&
      Array.isArray(this.intakeRecord.FL_Additional_Issues__c) &&
      this.intakeRecord.FL_Additional_Issues__c.includes("Other")
    );
  }

  get showFLOtherPartyAttorney() {
    return this.intakeRecord.FL_Other_Party_Has_Attorney__c === "Yes";
  }

  get showFLCurrentlyRepresented() {
    return this.intakeRecord.FL_Currently_Represented__c === "Yes";
  }

  get showFLNeedDocumentReview() {
    return this.intakeRecord.FL_Need_Document_Review__c === "Yes";
  }

  get showFLDocumentTypesOther() {
    return (
      this.intakeRecord.FL_Document_Types_Review__c &&
      Array.isArray(this.intakeRecord.FL_Document_Types_Review__c) &&
      this.intakeRecord.FL_Document_Types_Review__c.includes("Other")
    );
  }

  get showFLNeedDocumentDrafting() {
    return (
      this.intakeRecord.FL_Need_Document_Drafting__c &&
      Array.isArray(this.intakeRecord.FL_Need_Document_Drafting__c) &&
      this.intakeRecord.FL_Need_Document_Drafting__c.length > 0
    );
  }

  get showFLMediationProposed() {
    return (
      this.intakeRecord.FL_Mediation_Proposed__c === "Yes" ||
      this.intakeRecord.FL_Mediation_Proposed__c === "Already scheduled"
    );
  }

  get showFLProfessionalsAppointed() {
    return this.intakeRecord.FL_Professionals_Appointed__c === "Yes";
  }

  get showFLOngoingConcerns() {
    return this.intakeRecord.FL_Ongoing_Concerns__c === "Yes";
  }

  // Real Estate getter methods
  get realEstateAssistanceTypeOptions() {
    return (
      this.picklistValues.RE_Assistance_Type__c || [
        { label: "Purchase", value: "Purchase" },
        { label: "Sale", value: "Sale" },
        { label: "Lease", value: "Lease" },
        {
          label: "Document Drafting or Review",
          value: "Document Drafting or Review"
        },
        { label: "Dispute Resolution", value: "Dispute Resolution" },
        { label: "Partition of Property", value: "Partition of Property" },
        {
          label: "Equity Claim (non-owner contributor)",
          value: "Equity Claim (non-owner contributor)"
        },
        { label: "Other", value: "Other" }
      ]
    );
  }

  get realEstateRoleOptions() {
    return (
      this.picklistValues.RE_Your_Role__c || [
        { label: "Buyer", value: "Buyer" },
        { label: "Seller", value: "Seller" },
        { label: "Tenant", value: "Tenant" },
        { label: "Landlord", value: "Landlord" },
        { label: "Co-Owner", value: "Co-Owner" },
        {
          label: "Non-Titled Partner/Contributor",
          value: "Non-Titled Partner/Contributor"
        },
        { label: "Heir or Beneficiary", value: "Heir or Beneficiary" }
      ]
    );
  }

  get realEstatePropertyTypeOptions() {
    return (
      this.picklistValues.RE_Property_Type__c || [
        { label: "Residential", value: "Residential" },
        { label: "Commercial", value: "Commercial" },
        { label: "Vacant Land", value: "Vacant Land" },
        { label: "Mixed-Use", value: "Mixed-Use" },
        { label: "Agricultural", value: "Agricultural" },
        { label: "Other", value: "Other" }
      ]
    );
  }

  get realEstateFinancingTypeOptions() {
    return (
      this.picklistValues.RE_Financing_Type__c || [
        { label: "Cash", value: "Cash" },
        { label: "Mortgage", value: "Mortgage" },
        { label: "Seller Financing", value: "Seller Financing" },
        { label: "Private Loan", value: "Private Loan" },
        { label: "Other", value: "Other" }
      ]
    );
  }

  get realEstateLeaseTypeOptions() {
    return (
      this.picklistValues.RE_Lease_Type__c || [
        { label: "Residential", value: "Residential" },
        { label: "Commercial", value: "Commercial" },
        { label: "Agricultural", value: "Agricultural" },
        { label: "Other", value: "Other" }
      ]
    );
  }

  get realEstateDisputeNatureOptions() {
    return (
      this.picklistValues.RE_Dispute_Nature__c || [
        { label: "Breach of Contract", value: "Breach of Contract" },
        {
          label: "Title or Ownership Dispute",
          value: "Title or Ownership Dispute"
        },
        {
          label: "Boundary or Easement Dispute",
          value: "Boundary or Easement Dispute"
        },
        { label: "Non-Payment of Rent", value: "Non-Payment of Rent" },
        { label: "Lease Violations", value: "Lease Violations" },
        {
          label: "Property Defects / Misrepresentation",
          value: "Property Defects / Misrepresentation"
        },
        { label: "Failure to Disclose", value: "Failure to Disclose" },
        { label: "Partition Action", value: "Partition Action" },
        {
          label: "Constructive Trust / Equitable Ownership Claim",
          value: "Constructive Trust / Equitable Ownership Claim"
        },
        { label: "Other", value: "Other" }
      ]
    );
  }

  get realEstateContributionsOptions() {
    return (
      this.picklistValues.RE_Contribution_Types__c || [
        { label: "Down payment", value: "Down payment" },
        { label: "Mortgage payments", value: "Mortgage payments" },
        { label: "Property taxes", value: "Property taxes" },
        {
          label: "Utilities or maintenance",
          value: "Utilities or maintenance"
        },
        {
          label: "Renovations or improvements",
          value: "Renovations or improvements"
        },
        { label: "Sweat equity (labor)", value: "Sweat equity (labor)" },
        { label: "Other", value: "Other" }
      ]
    );
  }

  get realEstateRecordsOptions() {
    return (
      this.picklistValues.RE_Have_Records__c || [
        { label: "Yes", value: "Yes" },
        { label: "No", value: "No" },
        { label: "Some", value: "Some" }
      ]
    );
  }

  get realEstateSeekingOptions() {
    return (
      this.picklistValues.RE_Seeking__c || [
        {
          label: "To recover financial contributions",
          value: "To recover financial contributions"
        },
        {
          label: "An ownership interest in the property",
          value: "An ownership interest in the property"
        },
        {
          label: "Sale of the property and division of proceeds",
          value: "Sale of the property and division of proceeds"
        },
        {
          label: "Partition (judicial sale or division)",
          value: "Partition (judicial sale or division)"
        },
        {
          label: "Establishment of a constructive or resulting trust",
          value: "Establishment of a constructive or resulting trust"
        },
        { label: "Other", value: "Other" }
      ]
    );
  }

  get realEstateAgreementOptions() {
    return (
      this.picklistValues.RE_Ownership_Agreement__c || [
        { label: "Yes – Written", value: "Yes – Written" },
        { label: "Yes – Verbal", value: "Yes – Verbal" },
        { label: "No", value: "No" }
      ]
    );
  }

  get realEstateMortgageLienOptions() {
    return (
      this.picklistValues.RE_Mortgage_Lien__c || [
        { label: "Yes", value: "Yes" },
        { label: "No", value: "No" },
        { label: "Unsure", value: "Unsure" }
      ]
    );
  }

  get realEstateDocumentsOptions() {
    return (
      this.picklistValues.RE_Have_Documents__c || [
        { label: "Yes", value: "Yes" },
        { label: "No", value: "No" },
        { label: "In progress", value: "In progress" }
      ]
    );
  }

  get realEstateLiensTaxOptions() {
    return (
      this.picklistValues.RE_Liens_Tax_Foreclosure__c || [
        { label: "Yes", value: "Yes" },
        { label: "No", value: "No" },
        { label: "Not Sure", value: "Not Sure" }
      ]
    );
  }

  // Real Estate conditional visibility getters
  get showREAssistanceOther() {
    return (
      this.intakeRecord.RE_Assistance_Type__c &&
      Array.isArray(this.intakeRecord.RE_Assistance_Type__c) &&
      this.intakeRecord.RE_Assistance_Type__c.includes("Other")
    );
  }

  get showREPropertyTypeOther() {
    return this.intakeRecord.RE_Property_Type__c === "Other";
  }

  get showRERealtorInfo() {
    return this.intakeRecord.RE_Working_With_Realtor__c === "Yes";
  }

  get showREFinancingOther() {
    return this.intakeRecord.RE_Financing_Type__c === "Other";
  }

  get showRELeaseTypeOther() {
    return this.intakeRecord.RE_Lease_Type__c === "Other";
  }

  get showRELeaseTerms() {
    return this.intakeRecord.RE_Specific_Lease_Terms__c === "Yes";
  }

  get showREDisputeOther() {
    return (
      this.intakeRecord.RE_Dispute_Nature__c &&
      Array.isArray(this.intakeRecord.RE_Dispute_Nature__c) &&
      this.intakeRecord.RE_Dispute_Nature__c.includes("Other")
    );
  }

  get showRELegalActionTaken() {
    return this.intakeRecord.RE_Legal_Action_Taken__c === "Yes";
  }

  get showRELitigationStatus() {
    return this.intakeRecord.RE_Litigation_Status__c === "Yes";
  }

  get showRECoOwner() {
    return this.intakeRecord.RE_Co_Owner__c === "Yes";
  }

  get showREPersonalRelationship() {
    return this.intakeRecord.RE_Personal_Relationship__c === "Yes";
  }

  get showREFinancialContributions() {
    return this.intakeRecord.RE_Financial_Contributions__c === "Yes";
  }

  get showREContributionsOther() {
    return (
      this.intakeRecord.RE_Contribution_Types__c &&
      Array.isArray(this.intakeRecord.RE_Contribution_Types__c) &&
      this.intakeRecord.RE_Contribution_Types__c.includes("Other")
    );
  }

  get showRESeekingOther() {
    return (
      this.intakeRecord.RE_Seeking__c &&
      Array.isArray(this.intakeRecord.RE_Seeking__c) &&
      this.intakeRecord.RE_Seeking__c.includes("Other")
    );
  }

  get showREOwnershipAgreement() {
    return (
      this.intakeRecord.RE_Ownership_Agreement__c === "Yes – Written" ||
      this.intakeRecord.RE_Ownership_Agreement__c === "Yes – Verbal"
    );
  }

  get showRENotAllLiving() {
    return this.intakeRecord.RE_All_Parties_Living__c === "No";
  }

  get showREMortgageLien() {
    return this.intakeRecord.RE_Mortgage_Lien__c === "Yes";
  }

  get showREEnvironmentalTitleZoning() {
    return this.intakeRecord.RE_Environmental_Title_Zoning__c === "Yes";
  }

  get showREPropertyInHOA() {
    return this.intakeRecord.RE_Property_In_HOA__c === "Yes";
  }

  get showREHaveDocuments() {
    return this.intakeRecord.RE_Have_Documents__c === "Yes";
  }

  get showRELiensTaxForeclosure() {
    return this.intakeRecord.RE_Liens_Tax_Foreclosure__c === "Yes";
  }

  // ===== LANDLORD-TENANT GETTERS =====

  // Dropdown Options Getters
  get ltRoleOptions() {
    return (
      this.picklistValues.LT_Role__c || [
        { label: "Landlord", value: "Landlord" },
        { label: "Tenant", value: "Tenant" }
      ]
    );
  }

  get ltLeaseTermTypeOptions() {
    return (
      this.picklistValues.LT_Lease_Term_Type__c || [
        { label: "Fixed Term", value: "Fixed Term" },
        { label: "Month-to-Month", value: "Month-to-Month" },
        { label: "Week-to-Week", value: "Week-to-Week" },
        { label: "Other", value: "Other" }
      ]
    );
  }

  get ltWrittenLeaseOptions() {
    return (
      this.picklistValues.LT_Written_Lease__c || [
        { label: "Yes – Provide a copy", value: "Yes – Provide a copy" },
        {
          label: "No – Would you like assistance drafting one?",
          value: "No – Would you like assistance drafting one?"
        }
      ]
    );
  }

  get ltStageOptions() {
    return (
      this.picklistValues.LT_Stage__c || [
        { label: "Transactional", value: "Transactional" },
        { label: "Pre-Litigation", value: "Pre-Litigation" },
        { label: "Litigation", value: "Litigation" }
      ]
    );
  }

  get ltOwnershipTypeOptions() {
    return (
      this.picklistValues.LT_Ownership_Type__c || [
        { label: "Individual ownership", value: "Individual ownership" },
        { label: "LLC", value: "LLC" },
        { label: "Corporation", value: "Corporation" },
        { label: "Trust", value: "Trust" },
        { label: "Other", value: "Other" }
      ]
    );
  }

  get ltLandlordServicesOptions() {
    return (
      this.picklistValues.LT_Landlord_Services__c || [
        {
          label: "Lease drafting or review",
          value: "Lease drafting or review"
        },
        {
          label: "Addendum for pets, guests, smoking, etc.",
          value: "Addendum for pets, guests, smoking, etc."
        },
        { label: "Rent increase guidance", value: "Rent increase guidance" },
        {
          label: "Security deposit provisions",
          value: "Security deposit provisions"
        },
        {
          label: "Fair housing / anti-discrimination review",
          value: "Fair housing / anti-discrimination review"
        },
        { label: "Other", value: "Other" }
      ]
    );
  }

  get ltDisclosuresOptions() {
    return (
      this.picklistValues.LT_Lease_Disclosures__c || [
        { label: "Yes", value: "Yes" },
        { label: "No", value: "No" },
        { label: "Not sure", value: "Not sure" }
      ]
    );
  }

  get ltIssueNatureOptions() {
    return (
      this.picklistValues.LT_Issue_Nature__c || [
        { label: "Non-payment of rent", value: "Non-payment of rent" },
        { label: "Repeated late rent", value: "Repeated late rent" },
        {
          label: "Unauthorized occupants or subletting",
          value: "Unauthorized occupants or subletting"
        },
        { label: "Property damage", value: "Property damage" },
        { label: "Breach of lease terms", value: "Breach of lease terms" },
        {
          label: "Nuisance / neighbor complaints",
          value: "Nuisance / neighbor complaints"
        },
        {
          label: "Health and safety violations",
          value: "Health and safety violations"
        },
        { label: "Abandonment", value: "Abandonment" },
        { label: "Other", value: "Other" }
      ]
    );
  }

  get ltNoticeIssuedOptions() {
    return (
      this.picklistValues.LT_Notice_Issued__c || [
        { label: "Yes", value: "Yes" },
        { label: "No", value: "No" },
        {
          label: "Not sure how to do this – Need help",
          value: "Not sure how to do this – Need help"
        }
      ]
    );
  }

  get ltPursueOptions() {
    return (
      this.picklistValues.LT_Pursue_Goal__c || [
        { label: "Possession only", value: "Possession only" },
        { label: "Back rent only", value: "Back rent only" },
        { label: "Both", value: "Both" },
        {
          label: "Unsure – need legal guidance",
          value: "Unsure – need legal guidance"
        }
      ]
    );
  }

  get ltWritOptions() {
    return (
      this.picklistValues.LT_Writ_Requested__c || [
        { label: "Yes", value: "Yes" },
        { label: "No", value: "No" },
        { label: "Not sure", value: "Not sure" }
      ]
    );
  }

  get ltRepresentationOptions() {
    return (
      this.picklistValues.LT_Court_Representation__c || [
        { label: "Yes", value: "Yes" },
        { label: "No", value: "No" },
        {
          label: "Possibly – need consultation",
          value: "Possibly – need consultation"
        }
      ]
    );
  }

  get ltSettlementOptions() {
    return (
      this.picklistValues.LT_Settlement_Discussion__c || [
        { label: "Yes", value: "Yes" },
        { label: "No", value: "No" },
        {
          label: "Open to negotiating terms",
          value: "Open to negotiating terms"
        }
      ]
    );
  }

  get ltTenantLeaseOptions() {
    return (
      this.picklistValues.LT_Tenant_Lease_Type__c || [
        { label: "Yes – Provide a copy", value: "Yes – Provide a copy" },
        { label: "No", value: "No" },
        {
          label: "Lease is oral/verbal only",
          value: "Lease is oral/verbal only"
        }
      ]
    );
  }

  get ltTenantTermOptions() {
    return (
      this.picklistValues.LT_Tenant_Lease_Term__c || [
        { label: "Fixed", value: "Fixed" },
        { label: "Month-to-month", value: "Month-to-month" },
        { label: "Other", value: "Other" }
      ]
    );
  }

  get ltTenantLeaseSignedOptions() {
    return (
      this.picklistValues.LT_Lease_All_Signed__c || [
        { label: "Yes", value: "Yes" },
        { label: "No", value: "No" },
        { label: "Not sure", value: "Not sure" }
      ]
    );
  }

  get ltRentWithholdOptions() {
    return (
      this.picklistValues.LT_Rent_Withheld__c || [
        { label: "Yes", value: "Yes" },
        { label: "No", value: "No" },
        {
          label: "Planning to – seeking advice",
          value: "Planning to – seeking advice"
        }
      ]
    );
  }

  get ltRepairRequestOptions() {
    return (
      this.picklistValues.LT_Repair_Requested__c || [
        { label: "Yes – repairs completed", value: "Yes – repairs completed" },
        {
          label: "Yes – repairs not completed",
          value: "Yes – repairs not completed"
        },
        { label: "No", value: "No" }
      ]
    );
  }

  get ltCourtResponseOptions() {
    return (
      this.picklistValues.LT_Court_Response_Plan__c || [
        { label: "Yes", value: "Yes" },
        { label: "No", value: "No" },
        { label: "Need help preparing", value: "Need help preparing" }
      ]
    );
  }

  get ltDefenseOptions() {
    return (
      this.picklistValues.LT_Defenses__c || [
        { label: "Improper notice", value: "Improper notice" },
        {
          label: "Conditions/repairs were never addressed",
          value: "Conditions/repairs were never addressed"
        },
        {
          label: "Rent was paid / partial payments made",
          value: "Rent was paid / partial payments made"
        },
        {
          label: "Discrimination or retaliation",
          value: "Discrimination or retaliation"
        },
        {
          label: "Procedural defects (e.g., incorrect service)",
          value: "Procedural defects (e.g., incorrect service)"
        }
      ]
    );
  }

  get ltNegotiationOptions() {
    return (
      this.picklistValues.LT_Tenant_Negotiation__c || [
        { label: "Yes", value: "Yes" },
        { label: "No", value: "No" },
        { label: "Willing to try", value: "Willing to try" }
      ]
    );
  }

  get yesNoNAOptions() {
    return [
      { label: "Yes", value: "Yes" },
      { label: "No", value: "No" },
      { label: "Not applicable", value: "Not applicable" }
    ];
  }

  // Conditional Visibility Getters
  get showLandlordSections() {
    return this.intakeRecord.LT_Role__c === "Landlord";
  }

  get showTenantSections() {
    return this.intakeRecord.LT_Role__c === "Tenant";
  }

  get showLandlordTransactional() {
    return (
      this.showLandlordSections &&
      this.intakeRecord.LT_Stage__c === "Transactional"
    );
  }

  get showLandlordPreLitigation() {
    return (
      this.showLandlordSections &&
      this.intakeRecord.LT_Stage__c === "Pre-Litigation"
    );
  }

  get showLandlordLitigation() {
    return (
      this.showLandlordSections &&
      this.intakeRecord.LT_Stage__c === "Litigation"
    );
  }

  get showTenantTransactional() {
    return (
      this.showTenantSections &&
      this.intakeRecord.LT_Stage__c === "Transactional"
    );
  }

  get showTenantPreLitigation() {
    return (
      this.showTenantSections &&
      this.intakeRecord.LT_Stage__c === "Pre-Litigation"
    );
  }

  get showTenantLitigation() {
    return (
      this.showTenantSections && this.intakeRecord.LT_Stage__c === "Litigation"
    );
  }

  get showLandlordOwnershipTypeOther() {
    return this.intakeRecord.LT_Ownership_Type__c === "Other";
  }

  get showLandlordEntityFields() {
    return (
      this.intakeRecord.LT_Ownership_Type__c === "LLC" ||
      this.intakeRecord.LT_Ownership_Type__c === "Corporation" ||
      this.intakeRecord.LT_Ownership_Type__c === "Trust" ||
      this.intakeRecord.LT_Ownership_Type__c === "Other"
    );
  }

  get showLandlordServicesOther() {
    return (
      this.intakeRecord.LT_Landlord_Services__c &&
      Array.isArray(this.intakeRecord.LT_Landlord_Services__c) &&
      this.intakeRecord.LT_Landlord_Services__c.includes("Other")
    );
  }

  get showLandlordTemplateSource() {
    return this.intakeRecord.LT_Standard_Templates__c === "Yes";
  }

  get showLandlordActiveIssue() {
    return this.intakeRecord.LT_Active_Tenant_Issue__c === "Yes";
  }

  get showLandlordIssueNatureOther() {
    return (
      this.intakeRecord.LT_Issue_Nature__c &&
      Array.isArray(this.intakeRecord.LT_Issue_Nature__c) &&
      this.intakeRecord.LT_Issue_Nature__c.includes("Other")
    );
  }

  get showLandlordNoticeDate() {
    return this.intakeRecord.LT_Notice_Issued__c === "Yes";
  }

  get showLandlordPreviousEviction() {
    return this.intakeRecord.LT_Previous_Eviction__c === "Yes";
  }

  get showLandlordMediationOutcome() {
    return this.intakeRecord.LT_Mediation_Attempted__c === "Yes";
  }

  get showLandlordEvictionDetails() {
    return this.intakeRecord.LT_Eviction_Filed__c === "Yes";
  }

  get showLandlordTenantDefenses() {
    return this.intakeRecord.LT_Tenant_Defenses__c === "Yes";
  }

  get showTenantLeaseTermOther() {
    return this.intakeRecord.LT_Tenant_Lease_Term__c === "Other";
  }

  get showTenantLeaseConcerns() {
    return this.intakeRecord.LT_Lease_Concerns__c === "Yes";
  }

  get showTenantNoticeDetails() {
    return this.intakeRecord.LT_Received_Notices__c === "Yes";
  }

  get showTenantUnjustExplanation() {
    return this.intakeRecord.LT_Notice_Unjust__c === "Yes";
  }

  get showTenantHabitabilityDetails() {
    return this.intakeRecord.LT_Habitability_Issues__c === "Yes";
  }

  get showTenantHarassmentDetails() {
    return this.intakeRecord.LT_Harassment__c === "Yes";
  }

  get showTenantEvictionDetails() {
    return this.intakeRecord.LT_Served_Eviction__c === "Yes";
  }

  get showLTLegalAction() {
    return this.intakeRecord.LT_Legal_Action_Taken__c === "Yes";
  }

  // ===== GUARDIAN & CONSERVATORSHIP GETTERS =====

  // Dropdown Options Getters
  get gcWardResidenceOptions() {
    return (
      this.picklistValues.GC_Ward_Residence_Type__c || [
        { label: "Their own home", value: "Their own home" },
        { label: "Family member's home", value: "Family member's home" },
        {
          label: "Assisted living or nursing facility",
          value: "Assisted living or nursing facility"
        },
        { label: "Hospital", value: "Hospital" },
        { label: "Other", value: "Other" }
      ]
    );
  }

  get gcReasonOptions() {
    return (
      this.picklistValues.GC_Reason__c || [
        {
          label: "Incapacity due to illness or injury",
          value: "Incapacity due to illness or injury"
        },
        {
          label: "Developmental disability",
          value: "Developmental disability"
        },
        { label: "Mental health condition", value: "Mental health condition" },
        { label: "Substance abuse", value: "Substance abuse" },
        {
          label: "Elderly/dementia-related decline",
          value: "Elderly/dementia-related decline"
        },
        { label: "Other", value: "Other" }
      ]
    );
  }

  get gcMedicalRecordsOptions() {
    return (
      this.picklistValues.GC_Medical_Records__c || [
        { label: "Yes", value: "Yes" },
        { label: "No", value: "No" },
        { label: "Unknown", value: "Unknown" }
      ]
    );
  }

  get gcProceedingTypeOptions() {
    return (
      this.picklistValues.GC_Proceeding_Type__c || [
        {
          label:
            "Guardianship (decision-making authority over personal, medical, educational matters)",
          value: "Guardianship"
        },
        {
          label:
            "Conservatorship (control over financial and property matters)",
          value: "Conservatorship"
        },
        { label: "Both guardianship and conservatorship", value: "Both" },
        {
          label: "Temporary/emergency guardianship or conservatorship",
          value: "Temporary/emergency"
        }
      ]
    );
  }

  get gcWillingnessOptions() {
    return (
      this.picklistValues.GC_Guardian_Willingness__c || [
        { label: "Yes", value: "Yes" },
        { label: "No", value: "No" },
        { label: "Unsure", value: "Unsure" }
      ]
    );
  }

  get gcAssetTypesOptions() {
    return (
      this.picklistValues.GC_Asset_Types__c || [
        { label: "Real estate", value: "Real estate" },
        { label: "Bank accounts", value: "Bank accounts" },
        {
          label: "Investments (stocks, bonds, etc.)",
          value: "Investments (stocks, bonds, etc.)"
        },
        { label: "Retirement accounts", value: "Retirement accounts" },
        {
          label: "Personal property of significant value",
          value: "Personal property of significant value"
        },
        { label: "Business interests", value: "Business interests" },
        { label: "Other", value: "Other" }
      ]
    );
  }

  get gcAdvanceDirectivesOptions() {
    return (
      this.picklistValues.GC_Advance_Directives__c || [
        { label: "Yes", value: "Yes" },
        { label: "No", value: "No" },
        { label: "Unknown", value: "Unknown" }
      ]
    );
  }

  // Conditional Visibility Getters
  get showGCWardResidenceOther() {
    return this.intakeRecord.GC_Ward_Residence_Type__c === "Other";
  }

  get showGCReasonOther() {
    return this.intakeRecord.GC_Reason__c === "Other";
  }

  get showGCMedicalRecordsDetails() {
    return this.intakeRecord.GC_Medical_Records__c === "Yes";
  }

  get showGCExistingPOA() {
    return this.intakeRecord.GC_Existing_POA__c === "Yes";
  }

  get showGCPreviousCase() {
    return this.intakeRecord.GC_Previous_Case__c === "Yes";
  }

  get showGCGuardianOutOfState() {
    return this.intakeRecord.GC_Guardian_In_Colorado__c === "No";
  }

  get showGCGuardianPreviousExperience() {
    return this.intakeRecord.GC_Guardian_Previous_Experience__c === "Yes";
  }

  get showGCGuardianLegalHistory() {
    return this.intakeRecord.GC_Guardian_Legal_History__c === "Yes";
  }

  get showGCFamilyDisputes() {
    return this.intakeRecord.GC_Family_Disputes__c === "Yes";
  }

  get showGCCurrentCaregiver() {
    return this.intakeRecord.GC_Current_Caregiver__c === "Yes";
  }

  get showGCAssetTypesOther() {
    return (
      this.intakeRecord.GC_Asset_Types__c &&
      Array.isArray(this.intakeRecord.GC_Asset_Types__c) &&
      this.intakeRecord.GC_Asset_Types__c.includes("Other")
    );
  }

  get showGCKnownDebts() {
    return this.intakeRecord.GC_Known_Debts__c === "Yes";
  }

  get showGCIncomeSources() {
    return this.intakeRecord.GC_Income_Sources__c === "Yes";
  }

  get showGCOtherLegalOrders() {
    return this.intakeRecord.GC_Other_Legal_Orders__c === "Yes";
  }

  get showGCLegalDocumentsFiled() {
    return this.intakeRecord.GC_Legal_Documents_Filed__c === "Yes";
  }

  get showGCAbuseConcerns() {
    return this.intakeRecord.GC_Abuse_Concerns__c === "Yes";
  }

  // ===== GENERAL TAB GETTERS =====

  get preferredOfficeLocationOptions() {
    // Prioritize global value set values
    if (
      this.globalPreferredOfficeLocationValues &&
      this.globalPreferredOfficeLocationValues.length > 0
    ) {
      return this.globalPreferredOfficeLocationValues;
    }

    // Fall back to default values
    return DEFAULT_PREFERRED_OFFICE_LOCATIONS;
  }
}