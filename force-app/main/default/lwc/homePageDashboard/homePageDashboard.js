import { LightningElement, wire, track } from "lwc";
import { NavigationMixin } from "lightning/navigation";
import { loadScript } from "lightning/platformResourceLoader";
import ChartJs from "@salesforce/resourceUrl/ChartJs";

// Apex method imports
import getPracticeAreaOptions from "@salesforce/apex/HomePageDashboardController.getPracticeAreaOptions";
import getOfficeLocationOptions from "@salesforce/apex/HomePageDashboardController.getOfficeLocationOptions";
import getTypeOfCivilLawOptions from "@salesforce/apex/HomePageDashboardController.getTypeOfCivilLawOptions";
import getLeadCount from "@salesforce/apex/HomePageDashboardController.getLeadCount";
import getLeadMetrics from "@salesforce/apex/HomePageDashboardController.getLeadMetrics";
import getLeadConversionBySource from "@salesforce/apex/HomePageDashboardController.getLeadConversionBySource";
import getTotalLeadsBySource from "@salesforce/apex/HomePageDashboardController.getTotalLeadsBySource";
import getIntakeCompletions from "@salesforce/apex/HomePageDashboardController.getIntakeCompletions";
import getMatterTreeData from "@salesforce/apex/HomePageDashboardController.getMatterTreeData";
import getCloseRateByAttorney from "@salesforce/apex/HomePageDashboardController.getCloseRateByAttorney";
import getIntakeSpecialistCloseRate from "@salesforce/apex/HomePageDashboardController.getIntakeSpecialistCloseRate";
import getLeadsByLandingPage from "@salesforce/apex/HomePageDashboardController.getLeadsByLandingPage"; // NEW IMPORT
import getLeadsByPracticeArea from "@salesforce/apex/HomePageDashboardController.getLeadsByPracticeArea";
import getMatterPipelineData from "@salesforce/apex/HomePageDashboardController.getMatterPipelineData";
import getSQLLeadsTrend from "@salesforce/apex/HomePageDashboardController.getSQLLeadsTrend"; // NEW IMPORT

// Export method imports
import exportSalesMarketingData from "@salesforce/apex/HomePageDashboardController.exportSalesMarketingData";
import exportLeadCount from "@salesforce/apex/HomePageDashboardController.exportLeadCount";
import exportLeadMetrics from "@salesforce/apex/HomePageDashboardController.exportLeadMetrics";
import exportIntakeCompletions from "@salesforce/apex/HomePageDashboardController.exportIntakeCompletions";
import exportCloseRateByAttorney from "@salesforce/apex/HomePageDashboardController.exportCloseRateByAttorney";
import exportIntakeSpecialistCloseRate from "@salesforce/apex/HomePageDashboardController.exportIntakeSpecialistCloseRate";
import exportLeadConversionBySource from "@salesforce/apex/HomePageDashboardController.exportLeadConversionBySource";
import exportTotalLeadsBySource from "@salesforce/apex/HomePageDashboardController.exportTotalLeadsBySource";
import exportLeadsByLandingPage from "@salesforce/apex/HomePageDashboardController.exportLeadsByLandingPage";
import exportLeadsByPracticeArea from "@salesforce/apex/HomePageDashboardController.exportLeadsByPracticeArea";
import exportSQLTrend from "@salesforce/apex/HomePageDashboardController.exportSQLTrend";

// Modal record fetching methods
import getOpenMatterRecords from "@salesforce/apex/HomePageDashboardController.getOpenMatterRecords";
import getNewLeadRecords from "@salesforce/apex/HomePageDashboardController.getNewLeadRecords";
import getSQLLeadRecords from "@salesforce/apex/HomePageDashboardController.getSQLLeadRecords";
import getCloseRateLeadRecords from "@salesforce/apex/HomePageDashboardController.getCloseRateLeadRecords";
import getIntakeCompletionLeadRecords from "@salesforce/apex/HomePageDashboardController.getIntakeCompletionLeadRecords";
import getIntakeSpecialistCloseRateLeadRecords from "@salesforce/apex/HomePageDashboardController.getIntakeSpecialistCloseRateLeadRecords";
import getNewLeadsRecords from "@salesforce/apex/HomePageDashboardController.getNewLeadsRecords";
import getIntakeSpecialistCallsRecords from "@salesforce/apex/HomePageDashboardController.getIntakeSpecialistCallsRecords";
import getIntakeAttorneyCallsRecords from "@salesforce/apex/HomePageDashboardController.getIntakeAttorneyCallsRecords";
import getIntakeAttorneyNoShowsRecords from "@salesforce/apex/HomePageDashboardController.getIntakeAttorneyNoShowsRecords";
import getTotalClosedByISRecords from "@salesforce/apex/HomePageDashboardController.getTotalClosedByISRecords";
import getTotalClosedByIARecords from "@salesforce/apex/HomePageDashboardController.getTotalClosedByIARecords";

// Datatable column definitions
// Note: MATTER_COLUMNS defined but may be used in future modal implementations
// eslint-disable-next-line no-unused-vars
const MATTER_COLUMNS = [
  {
    label: "Matter Name",
    fieldName: "recordUrl",
    type: "url",
    typeAttributes: { label: { fieldName: "Name" }, target: "_blank" },
    sortable: true
  },
  {
    label: "Practice Area",
    fieldName: "practiceArea",
    type: "text",
    sortable: true
  },
  { label: "Status", fieldName: "status", type: "text", sortable: true }
];
const LEAD_COLUMNS = [
  {
    label: "Created Date",
    fieldName: "CreatedDate",
    type: "date-local",
    sortable: true
  },
  {
    label: "Lead Name",
    fieldName: "recordUrl",
    type: "url",
    typeAttributes: { label: { fieldName: "Name" }, target: "_blank" },
    sortable: true
  },
  { label: "Status", fieldName: "Status", type: "text", sortable: true },
  { label: "Owner", fieldName: "OwnerName", type: "text", sortable: true },
  {
    label: "Practice Area",
    fieldName: "PracticeArea",
    type: "text",
    sortable: true
  }
];
const SQL_LEAD_COLUMNS = [
  {
    label: "Created Date",
    fieldName: "CreatedDate",
    type: "date-local",
    sortable: true
  },
  {
    label: "Lead Name",
    fieldName: "recordUrl",
    type: "url",
    typeAttributes: { label: { fieldName: "Name" }, target: "_blank" },
    sortable: true
  },
  {
    label: "Intake Specialist",
    fieldName: "OwnerName",
    type: "text",
    sortable: true
  },
  {
    label: "Practice Area",
    fieldName: "PracticeArea",
    type: "text",
    sortable: true
  },
  {
    label: "Preferred Office Location",
    fieldName: "PreferredOfficeLocation",
    type: "text",
    sortable: true
  },
  { label: "Team Lead", fieldName: "TeamLead", type: "text", sortable: true }
];

const CLOSE_RATE_LEAD_COLUMNS = [
  {
    label: "Post Consult Completed Date",
    fieldName: "Post_Con_Completed_Date__c",
    type: "date",
    sortable: true
  },
  {
    label: "Lead Name",
    fieldName: "recordUrl",
    type: "url",
    typeAttributes: { label: { fieldName: "Name" }, target: "_blank" },
    sortable: true
  },
  {
    label: "Preferred Office",
    fieldName: "PreferredOfficeLocation",
    type: "text",
    sortable: true
  },
  {
    label: "Owner",
    fieldName: "OwnerName",
    type: "text",
    sortable: true
  },
  {
    label: "Intake Attorney",
    fieldName: "IntakeAttorneyName",
    type: "text",
    sortable: true
  },
  {
    label: "Date FA was Sent (Matter)",
    fieldName: "MatterDateFASent",
    type: "date",
    sortable: true
  },
  {
    label: "Date First Payment (Matter)",
    fieldName: "MatterDateFirstPayment",
    type: "date",
    sortable: true
  }
];

const INTAKE_SPECIALIST_CLOSE_RATE_LEAD_COLUMNS = [
  {
    label: "Post Consult Completed Date",
    fieldName: "Post_Con_Completed_Date__c",
    type: "date",
    sortable: true
  },
  {
    label: "Lead Name",
    fieldName: "recordUrl",
    type: "url",
    typeAttributes: { label: { fieldName: "Name" }, target: "_blank" },
    sortable: true
  },
  {
    label: "Preferred Office",
    fieldName: "PreferredOfficeLocation",
    type: "text",
    sortable: true
  },
  {
    label: "Intake Attorney",
    fieldName: "IntakeAttorneyName",
    type: "text",
    sortable: true
  },
  {
    label: "Date FA was Sent (Matter)",
    fieldName: "MatterDateFASent",
    type: "date",
    sortable: true
  },
  {
    label: "Date First Payment (Matter)",
    fieldName: "MatterDateFirstPayment",
    type: "date",
    sortable: true
  }
];

const CLOSED_BY_LEAD_COLUMNS = [
  {
    label: "Date First Payment (Matter)",
    fieldName: "MatterDateFirstPayment",
    type: "date",
    sortable: true
  },
  {
    label: "Lead Name",
    fieldName: "recordUrl",
    type: "url",
    typeAttributes: { label: { fieldName: "Name" }, target: "_blank" },
    sortable: true
  },
  {
    label: "Preferred Office",
    fieldName: "PreferredOfficeLocation",
    type: "text",
    sortable: true
  },
  {
    label: "Owner",
    fieldName: "OwnerName",
    type: "text",
    sortable: true
  },
  {
    label: "Intake Attorney",
    fieldName: "IntakeAttorneyName",
    type: "text",
    sortable: true
  },
  {
    label: "Date FA was Sent (Matter)",
    fieldName: "MatterDateFASent",
    type: "date",
    sortable: true
  },
  {
    label: "Post Consult Completed Date",
    fieldName: "Post_Con_Completed_Date__c",
    type: "date",
    sortable: true
  }
];

const NEW_LEADS_METRIC_COLUMNS = [
  {
    label: "Created Date",
    fieldName: "CreatedDate",
    type: "date-local",
    sortable: true
  },
  {
    label: "Lead Name",
    fieldName: "recordUrl",
    type: "url",
    typeAttributes: { label: { fieldName: "Name" }, target: "_blank" },
    sortable: true
  },
  {
    label: "Preferred Office",
    fieldName: "PreferredOfficeLocation",
    type: "text",
    sortable: true
  },
  {
    label: "Intake Attorney",
    fieldName: "IntakeAttorneyName",
    type: "text",
    sortable: true
  },
  {
    label: "Date FA was Signed",
    fieldName: "Lead_Completion_Date__c",
    type: "date",
    sortable: true
  },
  {
    label: "Date First Payment Made",
    fieldName: "Date_First_Payment__c",
    type: "date",
    sortable: true
  },
  {
    label: "Post Consult Completed Date",
    fieldName: "Post_Con_Completed_Date__c",
    type: "date",
    sortable: true
  },
  {
    label: "First Call",
    fieldName: "First_Call__c",
    type: "boolean",
    sortable: true
  }
];

const INTAKE_COMPLETION_LEAD_COLUMNS = [
  {
    label: "Intake Completion Date",
    fieldName: "Intake_Completion_Date__c",
    type: "date",
    sortable: true
  },
  {
    label: "Lead Name",
    fieldName: "recordUrl",
    type: "url",
    typeAttributes: { label: { fieldName: "Name" }, target: "_blank" },
    sortable: true
  },
  {
    label: "Preferred Office",
    fieldName: "PreferredOfficeLocation",
    type: "text",
    sortable: true
  },
  {
    label: "Intake Attorney",
    fieldName: "IntakeAttorneyName",
    type: "text",
    sortable: true
  },
  {
    label: "Date FA was Signed",
    fieldName: "Lead_Completion_Date__c",
    type: "date",
    sortable: true
  },
  {
    label: "Date First Payment Made",
    fieldName: "Date_First_Payment__c",
    type: "date",
    sortable: true
  }
];

const MATTER_TREE_COLUMNS = [
  { type: "text", fieldName: "label", label: "Name", initialWidth: 300 },
  { type: "text", fieldName: "status", label: "Status" },
  {
    type: "text",
    fieldName: "responsibleAttorney",
    label: "Responsible Attorney"
  }
];

export default class HomePageDashboard extends NavigationMixin(
  LightningElement
) {
  // Filter state
  @track selectedDateFilter = "THIS_MONTH";
  @track selectedPracticeArea = "";
  @track selectedOfficeLocation = "";
  @track selectedTypeOfCivilLaw = "";
  @track selectedAttorneyName = "";
  @track selectedOwnerName = "";
  @track includeAttorneyInIS = false;

  // Filter options
  @track practiceAreaOptions = [];
  @track officeLocationOptions = [];
  @track typeOfCivilLawOptions = [];

  // Data properties
  @track leadCountResult = {};
  @track leadMetricsResult = {};
  @track leadSourceConversionResult = {};
  @track totalLeadsBySourceResult = {};
  @track intakeCompletionsResult = {};
  @track matterTreeData = [];
  @track matterTreeColumns = MATTER_TREE_COLUMNS;
  @track matterPipelineResult = {};
  @track closeRateByAttorneyResult = {};
  @track intakeSpecialistCloseRateResult = {};
  @track leadsByLandingPageResult = {}; // NEW
  @track leadsByPracticeAreaResult = {};
  @track sqlTrendResult = {}; // NEW

  // Error properties
  @track practiceAreaError;
  @track officeLocationError;
  @track typeOfCivilLawError;
  @track matterTreeError;

  // Modal state
  @track isModalOpen = false;
  @track modalTitle = "";
  @track modalData = [];
  @track modalColumns = [];
  @track modalLoading = false;
  @track modalError = null;
  @track currentSortField;
  @track currentSortDirection = "asc";
  @track modalType = ""; // Track which modal is open
  @track filterFirstCallOnly = false; // Track First Call filter state
  @track firstCallLeadsCount = 0; // Total count of First Call leads
  @track isFiltering = false; // Track if we're filtering (not initial load)

  // Pagination state
  @track currentPage = 1;
  @track pageSize = 50;
  @track totalRecords = 0;
  allModalRecords = []; // Store all records for client-side pagination

  // UI state
  @track currentTime = new Date();
  refreshInterval;

  // Chart.js properties
  chartJsInitialized = false;
  intakeChart;
  sqlTrendChart;

  // Lifecycle hooks
  connectedCallback() {
    // eslint-disable-next-line @lwc/lwc/no-async-operation
    this.refreshInterval = setInterval(() => {
      this.currentTime = new Date();
    }, 60000);
  }

  disconnectedCallback() {
    if (this.refreshInterval) {
      clearInterval(this.refreshInterval);
    }
    // Destroy chart instances
    if (this.intakeChart) {
      this.intakeChart.destroy();
      this.intakeChart = null;
    }
    if (this.sqlTrendChart) {
      this.sqlTrendChart.destroy();
      this.sqlTrendChart = null;
    }
  }

  async renderedCallback() {
    // Initialize Chart.js
    if (!this.chartJsInitialized) {
      try {
        await loadScript(this, ChartJs);
        this.chartJsInitialized = true;
        this.initializeIntakeChart();
        this.initializeSQLChart();
      } catch (error) {
        console.error("Error loading Chart.js:", error);
      }
    } else {
      // Update charts when data changes
      if (this.intakeCompletionsResult.data) {
        this.updateIntakeChart();
      }
      if (this.sqlTrendResult.data) {
        this.updateSQLChart();
      }
    }
  }

  // Computed properties
  get dateFilterOptions() {
    return [
      { label: "Today", value: "TODAY" },
      { label: "Yesterday", value: "YESTERDAY" },
      { label: "This Week", value: "THIS_WEEK" },
      { label: "Last Week", value: "LAST_WEEK" },
      { label: "This Month", value: "THIS_MONTH" },
      { label: "Last Month", value: "LAST_MONTH" },
      { label: "This Quarter", value: "THIS_QUARTER" },
      { label: "Last Quarter", value: "LAST_QUARTER" },
      { label: "This Year", value: "THIS_YEAR" },
      { label: "Last Year", value: "LAST_YEAR" }
    ];
  }

  get getFilterLabel() {
    const filters = [];
    if (this.selectedPracticeArea) {
      const pa = this.practiceAreaOptions.find(
        (opt) => opt.value === this.selectedPracticeArea
      );
      if (pa) filters.push(pa.label);
    }
    if (this.selectedOfficeLocation) {
      const ol = this.officeLocationOptions.find(
        (opt) => opt.value === this.selectedOfficeLocation
      );
      if (ol) filters.push(ol.label);
    }
    if (this.selectedTypeOfCivilLaw) {
      const tcl = this.typeOfCivilLawOptions.find(
        (opt) => opt.value === this.selectedTypeOfCivilLaw
      );
      if (tcl) filters.push(tcl.label);
    }
    return filters.length > 0 ? `(${filters.join(", ")})` : "(All)";
  }

  // Error getters
  get leadCountError() {
    return this.formatError(this.leadCountResult?.error);
  }
  get leadSourceConversionError() {
    return this.formatError(this.leadSourceConversionResult?.error);
  }
  get totalLeadsBySourceError() {
    return this.formatError(this.totalLeadsBySourceResult?.error);
  }
  get intakeCompletionsError() {
    return this.formatError(this.intakeCompletionsResult?.error);
  }
  get closeRateByAttorneyError() {
    return this.formatError(this.closeRateByAttorneyResult?.error);
  }
  get leadsByLandingPageError() {
    return this.formatError(this.leadsByLandingPageResult?.error);
  } // NEW
  get leadsByPracticeAreaError() {
    return this.formatError(this.leadsByPracticeAreaResult?.error);
  }
  get sqlTrendError() {
    return this.formatError(this.sqlTrendResult?.error);
  } // NEW
  get matterPipelineError() {
    return this.formatError(this.matterPipelineResult?.error);
  }

  get totalSQLs() {
    if (this.sqlTrendResult?.data) {
      return this.sqlTrendResult.data.reduce(
        (sum, point) => sum + (point.sqlCount || 0),
        0
      );
    }
    return 0;
  }

  get showFirstCallFilter() {
    return this.modalType === "new_leads_metric";
  }

  // Wire adapters for filter options
  @wire(getPracticeAreaOptions) wiredPracticeAreas({ error, data }) {
    if (data) this.practiceAreaOptions = data;
    else if (error) this.practiceAreaError = this.formatError(error);
  }

  @wire(getOfficeLocationOptions) wiredOfficeLocations({ error, data }) {
    if (data) this.officeLocationOptions = data;
    else if (error) this.officeLocationError = this.formatError(error);
  }

  @wire(getTypeOfCivilLawOptions) wiredTypeOfCivilLawOptions({ error, data }) {
    if (data) this.typeOfCivilLawOptions = data;
    else if (error) this.typeOfCivilLawError = this.formatError(error);
  }

  // Wire adapters for data
  @wire(getCloseRateByAttorney, {
    dateFilter: "$selectedDateFilter",
    practiceArea: "$selectedPracticeArea",
    officeLocation: "$selectedOfficeLocation",
    typeOfCivilLaw: "$selectedTypeOfCivilLaw"
  })
  wiredCloseRateByAttorney(result) {
    this.closeRateByAttorneyResult = result;
  }

  @wire(getIntakeSpecialistCloseRate, {
    dateFilter: "$selectedDateFilter",
    practiceArea: "$selectedPracticeArea",
    officeLocation: "$selectedOfficeLocation",
    includeAttorney: "$includeAttorneyInIS",
    typeOfCivilLaw: "$selectedTypeOfCivilLaw"
  })
  wiredIntakeSpecialistCloseRate(result) {
    this.intakeSpecialistCloseRateResult = result;
  }

  @wire(getLeadCount, {
    dateFilter: "$selectedDateFilter",
    practiceArea: "$selectedPracticeArea",
    officeLocation: "$selectedOfficeLocation",
    typeOfCivilLaw: "$selectedTypeOfCivilLaw"
  })
  wiredLeadCount(result) {
    this.leadCountResult = result;
  }

  @wire(getLeadMetrics, {
    dateFilter: "$selectedDateFilter",
    practiceArea: "$selectedPracticeArea",
    officeLocation: "$selectedOfficeLocation",
    typeOfCivilLaw: "$selectedTypeOfCivilLaw"
  })
  wiredLeadMetrics(result) {
    this.leadMetricsResult = result;
  }

  @wire(getLeadConversionBySource, {
    dateFilter: "$selectedDateFilter",
    practiceArea: "$selectedPracticeArea",
    officeLocation: "$selectedOfficeLocation",
    typeOfCivilLaw: "$selectedTypeOfCivilLaw"
  })
  wiredLeadSourceConversions(result) {
    this.leadSourceConversionResult = result;
  }
  @wire(getTotalLeadsBySource, {
    dateFilter: "$selectedDateFilter",
    practiceArea: "$selectedPracticeArea",
    officeLocation: "$selectedOfficeLocation",
    typeOfCivilLaw: "$selectedTypeOfCivilLaw"
  })
  wiredTotalLeadsBySource(result) {
    this.totalLeadsBySourceResult = result;
  }
  @wire(getIntakeCompletions, {
    dateFilter: "$selectedDateFilter",
    practiceArea: "$selectedPracticeArea",
    officeLocation: "$selectedOfficeLocation",
    typeOfCivilLaw: "$selectedTypeOfCivilLaw"
  })
  wiredIntakeCompletions(result) {
    this.intakeCompletionsResult = result;
  }
  @wire(getLeadsByLandingPage, {
    dateFilter: "$selectedDateFilter",
    practiceArea: "$selectedPracticeArea",
    officeLocation: "$selectedOfficeLocation",
    typeOfCivilLaw: "$selectedTypeOfCivilLaw"
  })
  wiredLeadsByLandingPage(result) {
    this.leadsByLandingPageResult = result;
  } // NEW
  @wire(getLeadsByPracticeArea, {
    dateFilter: "$selectedDateFilter",
    practiceArea: "$selectedPracticeArea",
    officeLocation: "$selectedOfficeLocation",
    typeOfCivilLaw: "$selectedTypeOfCivilLaw"
  })
  wiredLeadsByPracticeArea(result) {
    this.leadsByPracticeAreaResult = result;
  }
  @wire(getSQLLeadsTrend, {
    dateFilter: "$selectedDateFilter",
    practiceArea: "$selectedPracticeArea",
    officeLocation: "$selectedOfficeLocation",
    typeOfCivilLaw: "$selectedTypeOfCivilLaw"
  })
  wiredSQLLeadsTrend(result) {
    this.sqlTrendResult = result;
  } // NEW
  @wire(getMatterPipelineData, { practiceArea: "$selectedPracticeArea" })
  wiredMatterPipelineData(result) {
    if (result.data) {
      // Find the maximum total count for scaling
      const maxTotal = Math.max(
        ...result.data.map((item) => item.totalCount),
        1
      );

      // Process the data to add computed styles
      const processedData = result.data.map((item) => {
        const openWidth = (item.openCount / maxTotal) * 100;
        const pendingWidth = (item.pendingCount / maxTotal) * 100;

        return {
          ...item,
          openBarStyle: `width: ${openWidth}%`,
          pendingBarStyle: `width: ${pendingWidth}%`,
          openTooltip: `Open: ${item.openCount}`,
          pendingTooltip: `Pending: ${item.pendingCount}`
        };
      });

      this.matterPipelineResult = {
        ...result,
        data: processedData
      };
    } else {
      this.matterPipelineResult = result;
    }
  }
  @wire(getMatterTreeData, { practiceArea: "$selectedPracticeArea" })
  wiredMatterTreeData({ error, data }) {
    if (data) {
      this.matterTreeData = this.remapTreeData(data);
      this.matterTreeError = null;
    } else if (error) {
      this.matterTreeError = this.formatError(error);
      this.matterTreeData = [];
    }
  }

  // Event handlers
  handleDateFilterChange(event) {
    this.selectedDateFilter = event.detail.value;
  }
  handlePracticeAreaChange(event) {
    this.selectedPracticeArea = event.detail.value;
  }
  handleOfficeLocationChange(event) {
    this.selectedOfficeLocation = event.detail.value;
  }
  handleTypeOfCivilLawChange(event) {
    this.selectedTypeOfCivilLaw = event.detail.value;
  }

  // Click handlers for dashboard tiles
  handleNewLeadsClick() {
    this.modalTitle = `New Leads: ${this.selectedDateFilter.replace("_", " ")} ${this.getFilterLabel}`;
    this.modalColumns = LEAD_COLUMNS;
    this.fetchModalData("leads");
  }

  handleSQLTrendClick() {
    this.modalTitle = `SQL Leads: ${this.selectedDateFilter.replace("_", " ")} ${this.getFilterLabel}`;
    this.modalColumns = SQL_LEAD_COLUMNS;
    this.fetchModalData("sql_leads");
  }

  handleCloseRateClick(event) {
    const attorneyName = event.currentTarget.dataset.attorneyName;
    this.selectedAttorneyName = attorneyName;
    this.modalTitle = `${attorneyName} Leads: ${this.selectedDateFilter.replace("_", " ")} ${this.getFilterLabel}`;
    this.modalColumns = CLOSE_RATE_LEAD_COLUMNS;
    this.fetchModalData("close_rate_leads");
  }

  handleIntakeSpecialistCloseRateClick(event) {
    const ownerName = event.currentTarget.dataset.ownerName;
    this.selectedOwnerName = ownerName;
    const filterText = this.includeAttorneyInIS
      ? " (With Attorney)"
      : " (No Attorney)";
    this.modalTitle = `${ownerName} Intake Spec. Leads${filterText}: ${this.selectedDateFilter.replace("_", " ")} ${this.getFilterLabel}`;
    this.modalColumns = INTAKE_SPECIALIST_CLOSE_RATE_LEAD_COLUMNS;
    this.fetchModalData("intake_specialist_close_rate_leads");
  }

  handleIncludeAttorneyToggle(event) {
    this.includeAttorneyInIS = event.target.checked;
  }

  handleFirstCallFilterChange(event) {
    this.filterFirstCallOnly = event.target.checked;
    this.isFiltering = true;
    // Re-fetch modal data with the new filter
    this.fetchModalData("new_leads_metric");
  }

  // Lead Metrics Click Handlers
  handleNewLeadsMetricClick() {
    this.modalTitle = `New Leads: ${this.selectedDateFilter.replace("_", " ")} ${this.getFilterLabel}`;
    this.modalColumns = NEW_LEADS_METRIC_COLUMNS;
    this.fetchModalData("new_leads_metric");
  }

  handleIntakeSpecialistCallsClick() {
    this.modalTitle = `Intake Spec. Post-Consults: ${this.selectedDateFilter.replace("_", " ")} ${this.getFilterLabel}`;
    this.modalColumns = INTAKE_SPECIALIST_CLOSE_RATE_LEAD_COLUMNS;
    this.fetchModalData("intake_specialist_calls");
  }

  handleIntakeAttorneyCallsClick() {
    this.modalTitle = `Intake Atty. Post-Consults: ${this.selectedDateFilter.replace("_", " ")} ${this.getFilterLabel}`;
    this.modalColumns = INTAKE_SPECIALIST_CLOSE_RATE_LEAD_COLUMNS;
    this.fetchModalData("intake_attorney_calls");
  }

  handleIntakeAttorneyNoShowsClick() {
    this.modalTitle = `Intake Attorney No Shows: ${this.selectedDateFilter.replace("_", " ")} ${this.getFilterLabel}`;
    this.modalColumns = INTAKE_SPECIALIST_CLOSE_RATE_LEAD_COLUMNS;
    this.fetchModalData("intake_attorney_no_shows");
  }

  handleTotalClosedByISClick() {
    this.modalTitle = `Closed by Intake Spec.: ${this.selectedDateFilter.replace("_", " ")} ${this.getFilterLabel}`;
    this.modalColumns = CLOSED_BY_LEAD_COLUMNS;
    this.fetchModalData("total_closed_by_is");
  }

  handleTotalClosedByIAClick() {
    this.modalTitle = `Closed by Intake Atty.: ${this.selectedDateFilter.replace("_", " ")} ${this.getFilterLabel}`;
    this.modalColumns = CLOSED_BY_LEAD_COLUMNS;
    this.fetchModalData("total_closed_by_ia");
  }

  handleIntakeCompletionClick(event) {
    // Get the clicked element and traverse up to find the canvas
    const canvas = this.refs.intakeChart;
    if (!canvas || !this.intakeChart) return;

    // Get the elements at the click position using Chart.js
    const elements = this.intakeChart.getElementsAtEventForMode(
      event,
      "nearest",
      { intersect: true },
      false
    );

    if (elements.length > 0) {
      const index = elements[0].index;
      const ownerName = this.intakeCompletionsResult.data[index].ownerName;
      this.selectedOwnerName = ownerName;
      this.modalTitle = `${ownerName} Intake Specialist Completions: ${this.selectedDateFilter.replace("_", " ")} ${this.getFilterLabel}`;
      this.modalColumns = INTAKE_COMPLETION_LEAD_COLUMNS;
      this.fetchModalData("intake_completion_leads");
    }
  }

  // Modal operations
  async fetchModalData(type) {
    this.isModalOpen = true;
    // Only show loading spinner on initial load, not when filtering
    if (!this.isFiltering) {
      this.modalLoading = true;
    }
    this.modalError = null;
    this.modalType = type; // Store the modal type
    try {
      let records;
      switch (type) {
        case "leads":
          records = await getNewLeadRecords({
            dateFilter: this.selectedDateFilter,
            practiceArea: this.selectedPracticeArea,
            officeLocation: this.selectedOfficeLocation,
            typeOfCivilLaw: this.selectedTypeOfCivilLaw
          });
          break;
        case "sql_leads":
          records = await getSQLLeadRecords({
            dateFilter: this.selectedDateFilter,
            practiceArea: this.selectedPracticeArea,
            officeLocation: this.selectedOfficeLocation,
            typeOfCivilLaw: this.selectedTypeOfCivilLaw
          });
          break;
        case "close_rate_leads":
          records = await getCloseRateLeadRecords({
            attorneyName: this.selectedAttorneyName,
            dateFilter: this.selectedDateFilter,
            practiceArea: this.selectedPracticeArea,
            officeLocation: this.selectedOfficeLocation,
            typeOfCivilLaw: this.selectedTypeOfCivilLaw
          });
          break;
        case "intake_completion_leads":
          records = await getIntakeCompletionLeadRecords({
            ownerName: this.selectedOwnerName,
            dateFilter: this.selectedDateFilter,
            practiceArea: this.selectedPracticeArea,
            officeLocation: this.selectedOfficeLocation,
            typeOfCivilLaw: this.selectedTypeOfCivilLaw
          });
          break;
        case "intake_specialist_close_rate_leads":
          records = await getIntakeSpecialistCloseRateLeadRecords({
            ownerName: this.selectedOwnerName,
            dateFilter: this.selectedDateFilter,
            practiceArea: this.selectedPracticeArea,
            officeLocation: this.selectedOfficeLocation,
            includeAttorney: this.includeAttorneyInIS,
            typeOfCivilLaw: this.selectedTypeOfCivilLaw
          });
          break;
        case "new_leads_metric":
          records = await getNewLeadsRecords({
            dateFilter: this.selectedDateFilter,
            practiceArea: this.selectedPracticeArea,
            officeLocation: this.selectedOfficeLocation,
            typeOfCivilLaw: this.selectedTypeOfCivilLaw,
            firstCallOnly: this.filterFirstCallOnly
          });
          break;
        case "intake_specialist_calls":
          records = await getIntakeSpecialistCallsRecords({
            dateFilter: this.selectedDateFilter,
            practiceArea: this.selectedPracticeArea,
            officeLocation: this.selectedOfficeLocation,
            typeOfCivilLaw: this.selectedTypeOfCivilLaw
          });
          break;
        case "intake_attorney_calls":
          records = await getIntakeAttorneyCallsRecords({
            dateFilter: this.selectedDateFilter,
            practiceArea: this.selectedPracticeArea,
            officeLocation: this.selectedOfficeLocation,
            typeOfCivilLaw: this.selectedTypeOfCivilLaw
          });
          break;
        case "intake_attorney_no_shows":
          records = await getIntakeAttorneyNoShowsRecords({
            dateFilter: this.selectedDateFilter,
            practiceArea: this.selectedPracticeArea,
            officeLocation: this.selectedOfficeLocation,
            typeOfCivilLaw: this.selectedTypeOfCivilLaw
          });
          break;
        case "total_closed_by_is":
          records = await getTotalClosedByISRecords({
            dateFilter: this.selectedDateFilter,
            practiceArea: this.selectedPracticeArea,
            officeLocation: this.selectedOfficeLocation,
            typeOfCivilLaw: this.selectedTypeOfCivilLaw
          });
          break;
        case "total_closed_by_ia":
          records = await getTotalClosedByIARecords({
            dateFilter: this.selectedDateFilter,
            practiceArea: this.selectedPracticeArea,
            officeLocation: this.selectedOfficeLocation,
            typeOfCivilLaw: this.selectedTypeOfCivilLaw
          });
          break;
        case "matters":
          records = await getOpenMatterRecords({
            practiceArea: this.selectedPracticeArea
          });
          break;
        default:
          throw new Error("Invalid modal type");
      }
      // Store all records and initialize pagination
      this.allModalRecords = this.processModalRecords(records);

      // Calculate First Call leads count for New Leads modal
      if (type === "new_leads_metric") {
        this.firstCallLeadsCount = this.allModalRecords.filter(
          (record) => record.First_Call__c === true
        ).length;
      }

      // Apply initial sort by the first column (date field) in descending order
      const firstColumn = this.modalColumns[0];
      if (firstColumn) {
        this.currentSortField = firstColumn.fieldName;
        this.currentSortDirection = "desc";
        this.allModalRecords.sort(
          this.sortBy(this.currentSortField, -1) // -1 for descending
        );
      }

      this.totalRecords = this.allModalRecords.length;
      this.currentPage = 1;
      this.updatePaginatedData();
    } catch (error) {
      this.modalError = this.formatError(error);
    } finally {
      this.modalLoading = false;
      this.isFiltering = false;
    }
  }

  updatePaginatedData() {
    const startIndex = (this.currentPage - 1) * this.pageSize;
    const endIndex = startIndex + this.pageSize;
    this.modalData = this.allModalRecords.slice(startIndex, endIndex);
  }

  processModalRecords(records) {
    return records.map((record) => {
      const processedRecord = {
        ...record,
        recordUrl: `/lightning/r/${record.Id}/view`,
        // Map field names for different modal types
        OwnerName: record.Owner?.Name || record.OwnerName,
        IntakeAttorneyName:
          record.Intake_Attorney__r?.Name || record.IntakeAttorneyName,
        PreferredOfficeLocation:
          record.Preferred_Office_Location__c || record.PreferredOfficeLocation,
        PracticeArea: record.Category__c || record.PracticeArea,
        // Map Matter fields
        MatterDateFASent: record.Matter__r?.Date_FA_was_sent__c,
        MatterDateFirstPayment: record.Matter__r?.Date_First_Payment__c,
        // Ensure First_Call__c is available
        First_Call__c: record.First_Call__c || false
      };
      return processedRecord;
    });
  }

  closeModal() {
    this.isModalOpen = false;
    this.modalType = "";
    this.filterFirstCallOnly = false;
    this.firstCallLeadsCount = 0;
    this.isFiltering = false;
  }

  handleModalSort(event) {
    const { fieldName: sortedBy, sortDirection } = event.detail;
    this.currentSortField = sortedBy;
    this.currentSortDirection = sortDirection;
    // Sort all records, not just the current page
    this.allModalRecords = [...this.allModalRecords].sort(
      this.sortBy(sortedBy, sortDirection === "asc" ? 1 : -1)
    );
    // Update the current page view
    this.updatePaginatedData();
  }

  // Utility methods
  remapTreeData(data) {
    if (!Array.isArray(data)) return [];
    return data.map((item) => {
      const remappedItem = { ...item };
      if (item.children?.length)
        remappedItem._children = this.remapTreeData(item.children);
      return remappedItem;
    });
  }

  sortBy(field, reverse, primer) {
    const key = primer ? (x) => primer(x[field]) : (x) => x[field] ?? "";
    return (a, b) => {
      const aValue = key(a);
      const bValue = key(b);
      if (typeof aValue === "string" && typeof bValue === "string") {
        return (
          reverse * aValue.toLowerCase().localeCompare(bValue.toLowerCase())
        );
      }
      return reverse * ((aValue > bValue) - (bValue > aValue));
    };
  }

  formatError(error) {
    if (!error) return null;
    if (typeof error === "string") return error;
    if (error.body?.message) return error.body.message;
    if (Array.isArray(error.body))
      return error.body
        .map((e) => e.message)
        .filter(Boolean)
        .join(", ");
    if (error.message) return error.message;
    return "An unexpected error occurred";
  }

  // Pagination computed properties
  get totalPages() {
    return Math.ceil(this.totalRecords / this.pageSize);
  }

  get isFirstPage() {
    return this.currentPage === 1;
  }

  get isLastPage() {
    return this.currentPage >= this.totalPages;
  }

  get startRecord() {
    return this.totalRecords === 0
      ? 0
      : (this.currentPage - 1) * this.pageSize + 1;
  }

  get endRecord() {
    const end = this.currentPage * this.pageSize;
    return end > this.totalRecords ? this.totalRecords : end;
  }

  get paginationInfo() {
    return `${this.startRecord}-${this.endRecord} of ${this.totalRecords}`;
  }

  // Help text getters for tooltips
  get sqlTrendHelpText() {
    return 'A Sales Qualified Lead (SQL) is a PC who came from a marketing channel that is not in a "test market," and scheduled and completed an initial call with sales. A Lead whose disqualification status reason is "Hired Another Firm" or "Firm Availability" also counts as an SQL';
  }

  get leadMetricsHelpText() {
    return "Key metrics tracking lead activity and conversions. Click any metric to see detailed records. Date logic for each component can differ. The first column in the popup shows which date field is controlling the date ranges for the component.";
  }

  get leadsByPracticeAreaHelpText() {
    return "Number of leads for each practice area are based on Created Date of Intake Form, sorted by volume highest to lowest. Practice Areas will only show if there's at least one record in the filter range. Zeros will not display.";
  }

  get intakeCompletionsHelpText() {
    return "Number of intake forms completed by each Intake Specialist based on Intake Completion Date. Top 10 specialists shown.";
  }

  get intakeSpecialistCloseRateHelpText() {
    return "Percentage of leads closed by each Intake Specialist. 'Closed' means Date FA was Sent AND Date First Payment have values. Only counts 'at bat' leads (Post Consult Complete is checked AND client was reached - not a No Show). Toggle 'Incl. Attorney' to include/exclude leads with attorney involvement.";
  }

  get intakeAttorneyCloseRateHelpText() {
    return "Percentage of leads closed by each Intake Attorney. 'Closed' means Date FA was Sent AND Date First Payment have values. Only counts 'at bat' leads (Post Consult Complete is checked AND client was reached - not a No Show).";
  }

  get leadConversionBySourceHelpText() {
    return "Conversion rate by lead source where converted means lead status is 'Closed - Converted' or 'Qualified'.";
  }

  get totalLeadsBySourceHelpText() {
    return "Total number of leads from each source, sorted by volume highest to lowest. Shows all sources.";
  }

  get leadsByLandingPageHelpText() {
    return "Number of leads from each website landing page based on Created Date, sorted by volume highest to lowest. Shows all landing pages.";
  }

  // Pagination handlers
  handleFirstPage() {
    this.currentPage = 1;
    this.updatePaginatedData();
  }

  handlePreviousPage() {
    if (!this.isFirstPage) {
      this.currentPage--;
      this.updatePaginatedData();
    }
  }

  handleNextPage() {
    if (!this.isLastPage) {
      this.currentPage++;
      this.updatePaginatedData();
    }
  }

  handleLastPage() {
    this.currentPage = this.totalPages;
    this.updatePaginatedData();
  }

  // Export handlers
  async handleExportSalesMarketing() {
    try {
      const csvData = await exportSalesMarketingData({
        dateFilter: this.selectedDateFilter,
        practiceArea: this.selectedPracticeArea,
        officeLocation: this.selectedOfficeLocation,
        typeOfCivilLaw: this.selectedTypeOfCivilLaw
      });
      this.downloadCSV(csvData, "sales-marketing-export.csv");
    } catch (error) {
      console.error("Export error:", error);
      // Could add toast notification here if needed
    }
  }

  // Individual component download handlers
  handleDownloadLeadCount() {
    console.log("handleDownloadLeadCount called - filters:", {
      dateFilter: this.selectedDateFilter,
      practiceArea: this.selectedPracticeArea,
      officeLocation: this.selectedOfficeLocation
    });

    exportLeadCount({
      dateFilter: this.selectedDateFilter,
      practiceArea: this.selectedPracticeArea,
      officeLocation: this.selectedOfficeLocation
    })
      .then((csvData) => {
        console.log("CSV data received:", csvData);
        this.downloadCSV(
          csvData,
          `new-leads-${this.selectedDateFilter.toLowerCase()}.csv`
        );
      })
      .catch((error) => {
        console.error("Export error:", error);
      });
  }

  handleDownloadLeadMetrics() {
    console.log("handleDownloadLeadMetrics called");
    exportLeadMetrics({
      dateFilter: this.selectedDateFilter,
      practiceArea: this.selectedPracticeArea,
      officeLocation: this.selectedOfficeLocation
    })
      .then((csvData) => {
        this.downloadCSV(
          csvData,
          `lead-metrics-${this.selectedDateFilter.toLowerCase()}.csv`
        );
      })
      .catch((error) => {
        console.error("Export error:", error);
      });
  }

  handleDownloadIntakeCompletions() {
    console.log("handleDownloadIntakeCompletions called");
    exportIntakeCompletions({
      dateFilter: this.selectedDateFilter,
      practiceArea: this.selectedPracticeArea,
      officeLocation: this.selectedOfficeLocation
    })
      .then((csvData) => {
        this.downloadCSV(
          csvData,
          `intake-completions-${this.selectedDateFilter.toLowerCase()}.csv`
        );
      })
      .catch((error) => {
        console.error("Export error:", error);
      });
  }

  handleDownloadIntakeSpecialistCloseRate() {
    console.log("handleDownloadIntakeSpecialistCloseRate called");
    exportIntakeSpecialistCloseRate({
      dateFilter: this.selectedDateFilter,
      practiceArea: this.selectedPracticeArea,
      officeLocation: this.selectedOfficeLocation,
      includeAttorney: this.includeAttorneyInIS,
      typeOfCivilLaw: this.selectedTypeOfCivilLaw
    })
      .then((csvData) => {
        this.downloadCSV(
          csvData,
          `intake-specialist-close-rate-${this.selectedDateFilter.toLowerCase()}.csv`
        );
      })
      .catch((error) => {
        console.error("Export error:", error);
      });
  }

  handleDownloadCloseRateByAttorney() {
    console.log("handleDownloadCloseRateByAttorney called");
    exportCloseRateByAttorney({
      dateFilter: this.selectedDateFilter,
      practiceArea: this.selectedPracticeArea,
      officeLocation: this.selectedOfficeLocation
    })
      .then((csvData) => {
        this.downloadCSV(
          csvData,
          `close-rate-by-attorney-${this.selectedDateFilter.toLowerCase()}.csv`
        );
      })
      .catch((error) => {
        console.error("Export error:", error);
      });
  }

  handleDownloadLeadConversionBySource() {
    console.log("handleDownloadLeadConversionBySource called");
    exportLeadConversionBySource({
      dateFilter: this.selectedDateFilter,
      practiceArea: this.selectedPracticeArea,
      officeLocation: this.selectedOfficeLocation
    })
      .then((csvData) => {
        this.downloadCSV(
          csvData,
          `lead-conversion-by-source-${this.selectedDateFilter.toLowerCase()}.csv`
        );
      })
      .catch((error) => {
        console.error("Export error:", error);
      });
  }

  handleDownloadTotalLeadsBySource() {
    console.log("handleDownloadTotalLeadsBySource called");
    exportTotalLeadsBySource({
      dateFilter: this.selectedDateFilter,
      practiceArea: this.selectedPracticeArea,
      officeLocation: this.selectedOfficeLocation
    })
      .then((csvData) => {
        this.downloadCSV(
          csvData,
          `total-leads-by-source-${this.selectedDateFilter.toLowerCase()}.csv`
        );
      })
      .catch((error) => {
        console.error("Export error:", error);
      });
  }

  handleDownloadLeadsByLandingPage() {
    console.log("handleDownloadLeadsByLandingPage called");
    exportLeadsByLandingPage({
      dateFilter: this.selectedDateFilter,
      practiceArea: this.selectedPracticeArea,
      officeLocation: this.selectedOfficeLocation
    })
      .then((csvData) => {
        this.downloadCSV(
          csvData,
          `leads-by-landing-page-${this.selectedDateFilter.toLowerCase()}.csv`
        );
      })
      .catch((error) => {
        console.error("Export error:", error);
      });
  }

  handleDownloadLeadsByPracticeArea() {
    console.log("handleDownloadLeadsByPracticeArea called");
    exportLeadsByPracticeArea({
      dateFilter: this.selectedDateFilter,
      practiceArea: this.selectedPracticeArea,
      officeLocation: this.selectedOfficeLocation
    })
      .then((csvData) => {
        this.downloadCSV(
          csvData,
          `leads-by-practice-area-${this.selectedDateFilter.toLowerCase()}.csv`
        );
      })
      .catch((error) => {
        console.error("Export error:", error);
      });
  }

  handleDownloadSQLTrend() {
    console.log("handleDownloadSQLTrend called");
    exportSQLTrend({
      dateFilter: this.selectedDateFilter,
      practiceArea: this.selectedPracticeArea,
      officeLocation: this.selectedOfficeLocation
    })
      .then((csvData) => {
        this.downloadCSV(
          csvData,
          `sql-leads-trend-${this.selectedDateFilter.toLowerCase()}.csv`
        );
      })
      .catch((error) => {
        console.error("Export error:", error);
      });
  }

  downloadCSV(csvData, filename) {
    try {
      const blob = new Blob([csvData], { type: "text/csv" });
      const link = document.createElement("a");

      if (link.download !== undefined) {
        const url = URL.createObjectURL(blob);
        link.setAttribute("href", url);
        link.setAttribute("download", filename);
        link.style.visibility = "hidden";
        document.body.appendChild(link);
        link.click();
        document.body.removeChild(link);
        URL.revokeObjectURL(url);
      }
    } catch (error) {
      console.error("Download error:", error);
      // Fallback for environments with strict security
      this.fallbackDownload(csvData, filename);
    }
  }

  fallbackDownload(csvData, filename) {
    try {
      // Alternative approach using data URL
      const dataUrl =
        "data:text/csv;charset=utf-8," + encodeURIComponent(csvData);
      const link = document.createElement("a");
      link.href = dataUrl;
      link.download = filename;
      link.style.display = "none";
      document.body.appendChild(link);
      link.click();
      document.body.removeChild(link);
    } catch (error) {
      console.error("Fallback download also failed:", error);
      // Show user a message that they can copy the data
      this.showCopyFallback(csvData);
    }
  }

  showCopyFallback(csvData) {
    // Create a temporary textarea for copying
    const textarea = document.createElement("textarea");
    textarea.value = csvData;
    textarea.style.position = "fixed";
    textarea.style.left = "-999999px";
    document.body.appendChild(textarea);
    textarea.select();

    try {
      document.execCommand("copy");
      console.log("CSV data copied to clipboard");
      // You could show a toast notification here
    } catch (err) {
      console.error("Could not copy CSV data:", err);
    }

    document.body.removeChild(textarea);
  }

  // Chart.js methods
  initializeSQLChart() {
    if (this.sqlTrendResult.data && this.refs.sqlTrendChart) {
      this.createSQLChart();
    }
  }

  updateSQLChart() {
    if (this.sqlTrendChart && this.sqlTrendResult.data) {
      const chartData = this.processSQLChartData();
      this.sqlTrendChart.data.labels = chartData.labels;
      this.sqlTrendChart.data.datasets[0].data = chartData.data;
      this.sqlTrendChart.update();
    } else if (this.refs.sqlTrendChart && this.sqlTrendResult.data) {
      this.createSQLChart();
    }
  }

  createSQLChart() {
    const ctx = this.refs.sqlTrendChart.getContext("2d");
    const chartData = this.processSQLChartData();

    // Destroy existing chart
    if (this.sqlTrendChart) {
      this.sqlTrendChart.destroy();
    }

    // Create gradient for modern look
    const gradient = ctx.createLinearGradient(0, 0, 0, 200);
    gradient.addColorStop(0, "rgba(0, 112, 210, 0.3)");
    gradient.addColorStop(1, "rgba(0, 112, 210, 0.05)");

    const lineGradient = ctx.createLinearGradient(0, 0, 0, 200);
    lineGradient.addColorStop(0, "#0070d2");
    lineGradient.addColorStop(1, "#1589ee");

    this.sqlTrendChart = new window.Chart(ctx, {
      type: "line",
      data: {
        labels: chartData.labels,
        datasets: [
          {
            label: "Sales Qualified Leads",
            data: chartData.data,
            borderColor: lineGradient,
            backgroundColor: gradient,
            borderWidth: 3,
            fill: true,
            tension: 0.4,
            pointBackgroundColor: "#0070d2",
            pointBorderColor: "#ffffff",
            pointBorderWidth: 2,
            pointRadius: 5,
            pointHoverRadius: 8,
            pointHoverBackgroundColor: "#1589ee",
            pointHoverBorderColor: "#ffffff",
            pointHoverBorderWidth: 3
          }
        ]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        layout: {
          padding: {
            left: 10,
            right: 20,
            top: 20,
            bottom: 10
          }
        },
        plugins: {
          legend: {
            display: false
          },
          tooltip: {
            enabled: true,
            backgroundColor: "rgba(0, 0, 0, 0.85)",
            titleColor: "#ffffff",
            bodyColor: "#ffffff",
            cornerRadius: 8,
            padding: 12,
            displayColors: false,
            callbacks: {
              title: function (context) {
                return context[0].label;
              },
              label: function (context) {
                const count = context.parsed.y;
                return `${count} SQL${count !== 1 ? "s" : ""}`;
              }
            }
          }
        },
        interaction: {
          intersect: false,
          mode: "index"
        },
        scales: {
          x: {
            border: {
              display: false
            },
            ticks: {
              font: {
                size: 11,
                family: "Salesforce Sans, Arial, sans-serif"
              },
              color: "#706e6b",
              padding: 8,
              maxRotation: 45
            },
            grid: {
              color: "rgba(112, 110, 107, 0.15)",
              lineWidth: 1,
              drawBorder: false
            }
          },
          y: {
            beginAtZero: true,
            border: {
              display: false
            },
            ticks: {
              precision: 0,
              font: {
                size: 11,
                family: "Salesforce Sans, Arial, sans-serif"
              },
              color: "#706e6b",
              padding: 8
            },
            grid: {
              color: "rgba(112, 110, 107, 0.15)",
              lineWidth: 1,
              drawBorder: false
            }
          }
        },
        elements: {
          point: {
            hoverRadius: 8
          }
        }
      }
    });
  }

  processSQLChartData() {
    if (!this.sqlTrendResult.data) {
      return { labels: [], data: [] };
    }

    const labels = this.sqlTrendResult.data.map((item) => item.periodLabel);
    const data = this.sqlTrendResult.data.map((item) => item.sqlCount);

    return { labels, data };
  }

  initializeIntakeChart() {
    if (this.intakeCompletionsResult.data && this.refs.intakeChart) {
      this.createIntakeChart();
    }
  }

  updateIntakeChart() {
    if (this.intakeChart && this.intakeCompletionsResult.data) {
      const chartData = this.processIntakeChartData();
      this.intakeChart.data.labels = chartData.labels;
      this.intakeChart.data.datasets[0].data = chartData.data;
      this.intakeChart.update();
    } else if (this.refs.intakeChart && this.intakeCompletionsResult.data) {
      this.createIntakeChart();
    }
  }

  createIntakeChart() {
    const ctx = this.refs.intakeChart.getContext("2d");
    const chartData = this.processIntakeChartData();

    // Destroy existing chart
    if (this.intakeChart) {
      this.intakeChart.destroy();
    }

    // Create gradient for modern look
    const gradient = ctx.createLinearGradient(0, 0, 400, 0);
    gradient.addColorStop(0, "#00d924");
    gradient.addColorStop(1, "#4ade80");

    // Calculate responsive bar thickness and spacing based on number of data points
    const dataPointCount = chartData.labels.length;
    const minBarThickness = 10;
    const maxBarThickness = 22;
    const calculatedBarThickness = Math.max(
      minBarThickness,
      Math.min(maxBarThickness, 180 / dataPointCount)
    );

    // Add spacing between bars based on data count
    const categoryPercentage = dataPointCount > 8 ? 0.6 : 0.8;
    const barPercentage = dataPointCount > 8 ? 0.7 : 0.9;

    this.intakeChart = new window.Chart(ctx, {
      type: "bar",
      data: {
        labels: chartData.labels,
        datasets: [
          {
            label: "Intake Specialist Completions",
            data: chartData.data,
            backgroundColor: gradient,
            borderColor: "#00d924",
            borderWidth: 0,
            borderRadius: 6,
            borderSkipped: false,
            barThickness: calculatedBarThickness,
            maxBarThickness: maxBarThickness
          }
        ]
      },
      options: {
        indexAxis: "y",
        responsive: true,
        maintainAspectRatio: false,
        categoryPercentage: categoryPercentage,
        barPercentage: barPercentage,
        layout: {
          padding: {
            left: 10,
            right: 20,
            top: dataPointCount > 8 ? 8 : 12,
            bottom: dataPointCount > 8 ? 8 : 12
          }
        },
        plugins: {
          legend: {
            display: false
          },
          tooltip: {
            enabled: true,
            backgroundColor: "rgba(0, 0, 0, 0.85)",
            titleColor: "#ffffff",
            bodyColor: "#ffffff",
            cornerRadius: 8,
            padding: 12,
            displayColors: false,
            callbacks: {
              title: function (context) {
                // Ensure we get the correct label for each bar
                return context[0].label || "Unknown";
              },
              label: function (context) {
                const value = context.parsed.x || context.raw || 0;
                return `${value} intake completion${value !== 1 ? "s" : ""}`;
              }
            }
          }
        },
        interaction: {
          intersect: true,
          mode: "point"
        },
        scales: {
          x: {
            beginAtZero: true,
            border: {
              display: false
            },
            ticks: {
              precision: 0,
              font: {
                size: 11,
                family: "Salesforce Sans, Arial, sans-serif"
              },
              color: "#706e6b",
              padding: 8
            },
            grid: {
              color: "rgba(112, 110, 107, 0.15)",
              lineWidth: 1,
              drawBorder: false,
              offset: false
            }
          },
          y: {
            border: {
              display: false
            },
            ticks: {
              font: {
                size: dataPointCount > 8 ? 10 : 12,
                family: "Salesforce Sans, Arial, sans-serif",
                weight: "500"
              },
              color: "#181818",
              padding: dataPointCount > 8 ? 8 : 12,
              maxRotation: 0
            },
            grid: {
              display: false,
              drawBorder: false
            }
          }
        },
        elements: {
          bar: {
            borderRadius: 8
          }
        }
      }
    });
  }

  processIntakeChartData() {
    if (
      !this.intakeCompletionsResult.data ||
      this.intakeCompletionsResult.data.length === 0
    ) {
      return { labels: [], data: [] };
    }

    // The data comes from Apex as IntakeCompletionSummary objects with ownerName and intakeCount
    const labels = this.intakeCompletionsResult.data.map(
      (item) => item.ownerName || "Unknown"
    );
    const data = this.intakeCompletionsResult.data.map(
      (item) => item.intakeCount || 0
    );

    return { labels, data };
  }
}