import { LightningElement, wire, track } from 'lwc';
import { loadScript } from 'lightning/platformResourceLoader';
import { NavigationMixin } from 'lightning/navigation';
import chartjs from '@salesforce/resourceUrl/ChartJs';
import getTeamTimeEntries from '@salesforce/apex/TeamTimeDashboardController.getTeamTimeEntries';
import getTargetInfo from '@salesforce/apex/TeamTimeDashboardController.getTargetInfo';
import getTeams from '@salesforce/apex/TeamTimeDashboardController.getTeams';
import getUsers from '@salesforce/apex/TeamTimeDashboardController.getUsers';
import getCollectionRate from '@salesforce/apex/TeamTimeDashboardController.getCollectionRate';
import getCollectionRateDetails from '@salesforce/apex/TeamTimeDashboardController.getCollectionRateDetails';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class TeamTimeDashboard extends NavigationMixin(LightningElement) {
    @track columns = [
        { label: 'User', fieldName: 'UserName', type: 'text', sortable: true },
        { label: 'Date', fieldName: 'Date__c', type: 'date-local', sortable: true, typeAttributes:{ month: 'short', day: 'numeric', year: 'numeric' } },
        { label: 'Matter', fieldName: 'MatterName', type: 'text', sortable: true },
        { label: 'Notes', fieldName: 'Note__c', type: 'text', sortable: true },
        { label: 'Hours', fieldName: 'Hours__c', type: 'number', sortable: true, typeAttributes: { minimumFractionDigits: '2', maximumFractionDigits: '2' }},
        { label: 'Rate', fieldName: 'Rate__c', type: 'currency', sortable: true },
        { label: 'Billable', fieldName: 'IsBillableStatus', type: 'text', sortable: true }
    ];

    @track teamFilter = 'All';
    @track personFilter = 'All';
    @track billableFilter = 'All';
    @track dateFilter = 'This Week';
    @track startDate = null;
    @track endDate = null;
    @track sortBy = 'Date__c';
    @track sortDirection = 'desc';
    @track error;
    
    // Data properties
    allTimeEntries = [];
    @track paginatedTimeEntries = [];
    @track teamOptions = [{ label: 'All', value: 'All' }];
    @track personOptions = [{ label: 'All', value: 'All' }];
    
    // Pagination properties
    currentPage = 1;
    pageSize = 25;
    totalPages = 1;

    // User goal properties
    goalData = [];
    currentTargetGoal = 0;

    // Collection rate properties
    @track collectionRate = 0;
    chartsInitialized = false;
    collectionRateChart;

    // Collection Rate Modal properties
    @track showModal = false;
    @track modalTitle = 'Collection Rate Details';
    @track invoiceDetails = [];
    @track allInvoiceDetails = [];
    @track isLoadingModal = false;
    @track currentPage = 1;
    @track pageSize = 25;
    @track totalRecords = 0;

    // Time Entry Modal properties
    @track showTimeEntryModal = false;
    @track timeEntryModalTitle = 'Time Entry Details';
    @track timeEntryModalData = [];
    @track allTimeEntryModalData = [];
    @track isLoadingTimeEntryModal = false;
    @track timeEntryCurrentPage = 1;
    @track timeEntryPageSize = 25;
    @track timeEntryTotalRecords = 0;

    // Lifecycle hooks
    connectedCallback() {
        // Load teams when component initializes
        this.loadTeams();
    }

    // Reactive getters for date calculations
    get calculatedStartDate() {
        return this.startDate || this.calculateStartDate(this.dateFilter);
    }
    get calculatedEndDate() {
        return this.endDate || this.calculateEndDate(this.dateFilter);
    }

    // Wire Apex methods
    @wire(getTeamTimeEntries, { 
        startDate: '$calculatedStartDate', 
        endDate: '$calculatedEndDate', 
        billableStatus: '$billableFilter',
        team: '$teamFilter',
        userId: '$personFilter'
    })
    wiredTimeEntries({ error, data }) {
        if (data) {
            // Filter out entries related to 'Clio Migration' matters and entries with 0 hours
            const filteredData = data.filter(entry => {
                // Filter out Clio Migration matters
                const isClioMigration = entry.Matter__r && entry.Matter__r.Name && entry.Matter__r.Name.includes('Clio Migration');
                
                // Filter out entries with no hours or 0 hours
                const hours = parseFloat(entry.Hours__c);
                const hasHours = hours && hours > 0;
                
                return !isClioMigration && hasHours;
            });

            this.allTimeEntries = filteredData.map(entry => ({
                ...entry,
                UserName: entry.User__r ? entry.User__r.Name : '',
                MatterName: entry.Matter__r ? entry.Matter__r.Name : '',
                IsBillableStatus: entry.Non_Billable__c ? 'No' : 'Yes'
            }));
            this.sortData(this.sortBy, this.sortDirection);
            this.error = undefined;
        } else if (error) {
            this.error = error;
            this.allTimeEntries = [];
            this.showToast('Error', 'An error occurred while fetching time entries.', 'error');
        }
        this.setupPagination();
    }

    @wire(getTargetInfo, { team: '$teamFilter', userId: '$personFilter' })
    wiredUser({ error, data }) {
        if (data) {
            this.goalData = data.map(user => ({
                yearlyTarget: user.Target_Hours__c || 0,
                userStartDate: user.Start_Date__c ? new Date(user.Start_Date__c + 'T00:00:00') : null
            }));
            this.calculateCurrentTargetGoal();
        } else if (error) {
            this.error = error;
             this.showToast('Error', 'An error occurred while fetching user goal information.', 'error');
        }
    }

    async loadTeams() {
        try {
            const teams = await getTeams({ 
                startDate: this.calculatedStartDate, 
                endDate: this.calculatedEndDate 
            });
            this.teamOptions = [{ label: 'All', value: 'All' }];
            teams.forEach(team => {
                this.teamOptions.push({ label: team, value: team });
            });
        } catch (error) {
            this.showToast('Error', 'An error occurred while fetching teams.', 'error');
        }
    }

    @wire(getUsers, { team: '$teamFilter' })
    wiredUsers({ error, data }) {
        if (data) {
            this.personOptions = [{ label: 'All', value: 'All' }];
            data.forEach(user => {
                this.personOptions.push({ label: user.Name, value: user.Id });
            });
        } else if (error) {
            this.showToast('Error', 'An error occurred while fetching users.', 'error');
        }
    }

    @wire(getCollectionRate, { 
        dateFilter: '$dateFilter',
        startDate: '$startDate', 
        endDate: '$endDate', 
        team: '$teamFilter',
        userId: '$personFilter'
    })
    wiredCollectionRate({ error, data }) {
        if (data !== undefined) {
            this.collectionRate = data;
            if (this.chartsInitialized) {
                this.updateCollectionRateChart();
            } else {
                loadScript(this, chartjs)
                    .then(() => {
                        this.initializeCollectionRateChart();
                        this.chartsInitialized = true;
                    })
                    .catch(error => {
                        console.error('Error loading Chart.js', error);
                    });
            }
        } else if (error) {
            console.error('Error fetching collection rate:', error);
            this.collectionRate = 0;
        }
    }

    // Getters for display
    get billableOptions() {
        return [
            { label: 'All', value: 'All' },
            { label: 'Billable', value: 'Billable' },
            { label: 'Non-Billable', value: 'Non-Billable' },
        ];
    }

    get dateRangeOptions() {
        return [
            { label: 'Today', value: 'Today' },
            { label: 'Yesterday', value: 'Yesterday' },
            { label: 'This Week', value: 'This Week' },
            { label: 'Last Week', value: 'Last Week' },
            { label: 'This Month', value: 'This Month' },
            { label: 'Last Month', value: 'Last Month' },
            { label: 'This Quarter', value: 'This Quarter' },
            { label: 'Last Quarter', value: 'Last Quarter' },
            { label: 'This Year', value: 'This Year' },
            { label: 'Last Year', value: 'Last Year' }
        ];
    }

    get dateRangeOptionsWithCustom() {
        return [
            ...this.dateRangeOptions,
            { label: 'Custom', value: 'Custom' }
        ];
    }
    
    get totalHours() {
        const total = (this.allTimeEntries || []).reduce((acc, entry) => acc + (Number(entry.Hours__c) || 0), 0);
        return total.toFixed(2);
    }

    get billableHoursValue() {
        const total = (this.allTimeEntries || [])
            .filter(e => !e.Non_Billable__c)
            .reduce((acc, entry) => acc + (Number(entry.Hours__c) || 0), 0);
        return total.toFixed(2);
    }

    get nonBillableHoursValue() {
        const total = (this.allTimeEntries || [])
            .filter(e => e.Non_Billable__c)
            .reduce((acc, entry) => acc + (Number(entry.Hours__c) || 0), 0);
        return total.toFixed(2);
    }
    
    get goalPercentage() {
        if (this.currentTargetGoal === 0) return 0;
        const percentage = (this.billableHoursValue / this.currentTargetGoal) * 100;
        return Math.round(percentage);
    }

    get formattedCurrentTargetGoal() {
        return this.currentTargetGoal.toFixed(2);
    }

    get gaugeNeedleTransform() {
        const percentage = this.goalPercentage > 100 ? 100 : this.goalPercentage; // Cap at 100% for rotation
        const rotation = -90 + (percentage * 1.8); // -90 is start, 180 degrees total arc
        return `rotate(${rotation} 100 100)`;
    }

    get gaugeNeedleTransformCompact() {
        const percentage = this.goalPercentage > 100 ? 100 : this.goalPercentage; // Cap at 100% for rotation
        const rotation = -90 + (percentage * 1.8); // -90 is start, 180 degrees total arc
        return `rotate(${rotation} 80 80)`; // Compact center at 80,80
    }

    get gaugeTicks() {
        const ticks = [];
        const numTicks = 5;
        const center = 100;
        const gaugeArcRadius = 75;
        const gaugeArcStrokeWidth = 20;
        const outerRadius = gaugeArcRadius + (gaugeArcStrokeWidth / 2);

        // Compact gauge parameters
        const centerCompact = 80;
        const gaugeArcRadiusCompact = 60;
        const gaugeArcStrokeWidthCompact = 15;
        const outerRadiusCompact = gaugeArcRadiusCompact + (gaugeArcStrokeWidthCompact / 2);

        for (let i = 0; i <= numTicks; i++) {
            const angle = -Math.PI + (i / numTicks) * Math.PI;

            // Original coordinates
            const x1 = center + outerRadius * Math.cos(angle);
            const y1 = center + outerRadius * Math.sin(angle);
            const x2 = center + (outerRadius + 5) * Math.cos(angle);
            const y2 = center + (outerRadius + 5) * Math.sin(angle);
            
            const textRadius = outerRadius + 12;
            const tx = center + textRadius * Math.cos(angle);
            const ty = center + textRadius * Math.sin(angle);

            // Compact coordinates
            const x1Compact = centerCompact + outerRadiusCompact * Math.cos(angle);
            const y1Compact = centerCompact + outerRadiusCompact * Math.sin(angle);
            const x2Compact = centerCompact + (outerRadiusCompact + 4) * Math.cos(angle);
            const y2Compact = centerCompact + (outerRadiusCompact + 4) * Math.sin(angle);
            
            const textRadiusCompact = outerRadiusCompact + 8;
            const txCompact = centerCompact + textRadiusCompact * Math.cos(angle);
            const tyCompact = centerCompact + textRadiusCompact * Math.sin(angle);

            ticks.push({
                label: this.formatTickLabel((this.currentTargetGoal * i) / numTicks),
                x1, y1, x2, y2, tx, ty,
                x1Compact, y1Compact, x2Compact, y2Compact, txCompact, tyCompact
            });
        }
        return ticks;
    }

    get isFirstPage() {
        return this.currentPage === 1;
    }
    get isLastPage() {
        return this.currentPage === this.totalPages || this.totalPages === 0;
    }

    // Check if either custom date field has a value (for disabling dropdown)
    get hasCustomDateRange() {
        return (this.startDate && this.startDate !== null && this.startDate !== '') || 
               (this.endDate && this.endDate !== null && this.endDate !== '');
    }

    // Check if BOTH custom dates are filled (for validation)
    get hasBothCustomDates() {
        return (this.startDate && this.startDate !== null && this.startDate !== '') && 
               (this.endDate && this.endDate !== null && this.endDate !== '');
    }

    // Get placeholder text for date dropdown
    get dateFilterPlaceholder() {
        return this.hasCustomDateRange ? 'Custom dates selected' : '';
    }

    get startDateContainerClass() {
        return this.startDate ? 'date-input-container has-clear-button' : 'date-input-container';
    }

    get endDateContainerClass() {
        return this.endDate ? 'date-input-container has-clear-button' : 'date-input-container';
    }

    get showCustomDateInputs() {
        return this.dateFilter === 'Custom' || this.hasCustomDateRange;
    }
    
    // Handlers
    handleFilterChange(event) {
        const { name, value } = event.target;
        this[name] = value;
        if (name === 'dateFilter') {
            // Clear custom date range when using dropdown
            this.startDate = null;
            this.endDate = null;
            // Reload teams based on new date range
            this.loadTeams();
        }
        if (name === 'dateFilter' || name === 'personFilter' || name === 'teamFilter') {
            // Recalculate goal when filters affecting user selection change.
            // A slight delay to allow wired service to fetch new goalData.
            // eslint-disable-next-line @lwc/lwc/no-async-operation
            setTimeout(() => this.calculateCurrentTargetGoal(), 100);
        }
        if (name === 'teamFilter') {
            this.personFilter = 'All'; // Reset person filter when team changes
        }
    }

    handleDateFilterChange(event) {
        const { value } = event.target;
        this.dateFilter = value;
        
        if (value !== 'Custom') {
            // Clear custom dates when selecting a preset range
            this.startDate = null;
            this.endDate = null;
        }
        
        // Reload teams based on new date range
        this.loadTeams();
        
        // Recalculate goal when date filter changes
        setTimeout(() => this.calculateCurrentTargetGoal(), 100);
    }

    handleDateRangeChange(event) {
        const { name, value } = event.target;
        this[name] = value;

        // Keep dateFilter as 'Custom' when custom dates are being used
        // This ensures the inputs stay visible
        if (this.hasCustomDateRange && this.dateFilter !== 'Custom') {
            this.dateFilter = 'Custom';
        }

        // Reload teams when custom date range changes
        if (this.hasBothCustomDates) {
            this.loadTeams();
            // Recalculate goal when custom date range changes
            // eslint-disable-next-line @lwc/lwc/no-async-operation
            setTimeout(() => this.calculateCurrentTargetGoal(), 100);
        }
    }

    clearStartDate() {
        this.startDate = null;
        // Reset to default dropdown if no custom dates remain
        if (!this.endDate) {
            this.dateFilter = 'This Week';
            // Force data refresh when returning to dropdown
            this.refreshData();
        }
    }

    clearEndDate() {
        this.endDate = null;
        // Reset to default dropdown if no custom dates remain
        if (!this.startDate) {
            this.dateFilter = 'This Week';
            // Force data refresh when returning to dropdown
            this.refreshData();
        }
    }

    clearCustomDates() {
        this.startDate = null;
        this.endDate = null;
        this.dateFilter = 'This Week';
        
        // Force data refresh
        this.refreshData();
    }

    refreshData() {
        // Reload teams based on new date range
        this.loadTeams();
        
        // Force the wire services to re-execute by clearing and resetting team filter
        const currentTeamFilter = this.teamFilter;
        this.teamFilter = '';
        // Use setTimeout to ensure the change is processed
        setTimeout(() => {
            this.teamFilter = currentTeamFilter;
        }, 10);
    }

    handleSort(event) {
        const { fieldName: sortedBy, sortDirection } = event.detail;
        this.sortBy = sortedBy;
        this.sortDirection = sortDirection;
        this.sortData(sortedBy, sortDirection);
    }

    handlePrevious() {
        if (this.currentPage > 1) {
            this.currentPage--;
            this.updatePaginatedEntries();
        }
    }

    handleNext() {
        if (this.currentPage < this.totalPages) {
            this.currentPage++;
            this.updatePaginatedEntries();
        }
    }

    // UTILITY FUNCTIONS
    setupPagination() {
        this.totalPages = Math.ceil((this.allTimeEntries.length || 0) / this.pageSize);
        this.currentPage = 1;
        this.updatePaginatedEntries();
    }

    updatePaginatedEntries() {
        const startIndex = (this.currentPage - 1) * this.pageSize;
        const endIndex = startIndex + this.pageSize;
        this.paginatedTimeEntries = this.allTimeEntries.slice(startIndex, endIndex);
    }
    
    formatTickLabel(num) {
        const fixedNum = num.toFixed(2);
        // parseFloat will drop trailing zeroes, so 30.00 becomes 30
        return parseFloat(fixedNum).toString();
    }

    calculateStartDate(filter) {
        const now = new Date();
        const today = new Date(now.getFullYear(), now.getMonth(), now.getDate()); // Use today at midnight
        switch (filter) {
            case 'Today': return this.formatDate(today);
            case 'Yesterday': return this.formatDate(new Date(new Date().setDate(today.getDate() - 1)));
            case 'This Week': {
                const firstDayOfWeek = new Date(today.setDate(today.getDate() - today.getDay()));
                return this.formatDate(firstDayOfWeek);
            }
            case 'Last Week': {
                 const prevWeek = new Date();
                 prevWeek.setDate(new Date().getDate() - 7 - new Date().getDay());
                 return this.formatDate(prevWeek);
            }
            case 'This Month': return this.formatDate(new Date(today.getFullYear(), today.getMonth(), 1));
            case 'Last Month': return this.formatDate(new Date(today.getFullYear(), today.getMonth() - 1, 1));
            case 'This Quarter': {
                const quarter = Math.floor(today.getMonth() / 3);
                return this.formatDate(new Date(today.getFullYear(), quarter * 3, 1));
            }
            case 'Last Quarter': {
                const lastQuarterDate = new Date();
                lastQuarterDate.setMonth(lastQuarterDate.getMonth() - 3);
                const quarter = Math.floor(lastQuarterDate.getMonth() / 3);
                return this.formatDate(new Date(lastQuarterDate.getFullYear(), quarter * 3, 1));
            }
            case 'This Year': return this.formatDate(new Date(today.getFullYear(), 0, 1));
            case 'Last Year': return this.formatDate(new Date(today.getFullYear() - 1, 0, 1));
            default: return this.formatDate(today);
        }
    }

    calculateEndDate(filter) {
        const now = new Date();
        const today = new Date(now.getFullYear(), now.getMonth(), now.getDate()); // Use today at midnight
        switch (filter) {
            case 'Today': return this.formatDate(today);
            case 'Yesterday': return this.formatDate(new Date(new Date().setDate(today.getDate() - 1)));
            case 'This Week': {
                 const lastDayOfWeek = new Date(new Date().setDate(new Date().getDate() - new Date().getDay() + 6));
                 return this.formatDate(lastDayOfWeek);
            }
            case 'Last Week': {
                const prevWeek = new Date();
                prevWeek.setDate(new Date().getDate() - 7 - new Date().getDay() + 6);
                return this.formatDate(prevWeek);
            }
            case 'This Month': return this.formatDate(new Date(today.getFullYear(), today.getMonth() + 1, 0));
            case 'Last Month': return this.formatDate(new Date(today.getFullYear(), today.getMonth(), 0));
            case 'This Quarter': {
                const quarter = Math.floor(today.getMonth() / 3);
                return this.formatDate(new Date(today.getFullYear(), quarter * 3 + 3, 0));
            }
            case 'Last Quarter': {
                const lastQuarterDate = new Date();
                lastQuarterDate.setMonth(lastQuarterDate.getMonth() - 3);
                const quarter = Math.floor(lastQuarterDate.getMonth() / 3);
                return this.formatDate(new Date(lastQuarterDate.getFullYear(), quarter * 3 + 3, 0));
            }
            case 'This Year': return this.formatDate(new Date(today.getFullYear(), 11, 31));
            case 'Last Year': return this.formatDate(new Date(today.getFullYear() - 1, 11, 31));
            default: return this.formatDate(today);
        }
    }

    formatDate(date) {
        return date.toISOString().split('T')[0];
    }
    
    sortData(field, direction) {
        let parseData = [...this.allTimeEntries];
        let keyValue = (a) => {
            return a[field];
        };

        let isReverse = direction === 'asc' ? 1 : -1;
        
        parseData.sort((x, y) => {
            x = keyValue(x) ? keyValue(x) : ''; 
            y = keyValue(y) ? keyValue(y) : '';
           
            return isReverse * ((x > y) - (y > x));
        });
        this.allTimeEntries = parseData;
    }
    
    showToast(title, message, variant) {
        const event = new ShowToastEvent({ title, message, variant });
        this.dispatchEvent(event);
    }
    
    roundToQuarterHour(num) {
        return Math.round(num * 4) / 4;
    }

    calculateCurrentTargetGoal() {
        if (!this.goalData || this.goalData.length === 0) {
            this.currentTargetGoal = 0;
            return;
        }

        let totalGoalForPeriod = 0;

        this.goalData.forEach(user => {
            if (!user.userStartDate || !user.yearlyTarget) {
                return; // Skip users with no start date or target
            }

            const userStartDate = new Date(user.userStartDate);
            const periodStartDate = new Date(this.calculatedStartDate + 'T00:00:00');
            const periodEndDate = new Date(this.calculatedEndDate + 'T00:00:00');

            const dailyGoal = user.yearlyTarget / 240;
            let goalForPeriod = 0;

            switch (this.dateFilter) {
                case 'Today':
                case 'Yesterday': {
                    const dayOfWeek = periodStartDate.getDay();
                    if (dayOfWeek > 0 && dayOfWeek < 6 && periodStartDate >= userStartDate) {
                        goalForPeriod = dailyGoal;
                    }
                    break;
                }
                
                case 'This Week':
                case 'Last Week': {
                    const weeklyGoal = user.yearlyTarget / 48;
                    if (periodEndDate >= userStartDate) {
                        goalForPeriod = weeklyGoal;
                    }
                    break;
                }
                
                case 'This Month':
                case 'Last Month': {
                    const monthlyGoal = user.yearlyTarget / 12;
                    const targetYear = periodStartDate.getFullYear();
                    const userStartYear = userStartDate.getFullYear();
                    const targetMonth = periodStartDate.getMonth();
                    const userStartMonth = userStartDate.getMonth();
                    
                    if (targetYear > userStartYear || (targetYear === userStartYear && targetMonth >= userStartMonth)) {
                        goalForPeriod = monthlyGoal;
                    }
                    break;
                }
                
                case 'This Quarter':
                case 'Last Quarter': {
                    const quarterlyGoal = user.yearlyTarget / 4;
                    const targetYear = periodStartDate.getFullYear();
                    const userStartYear = userStartDate.getFullYear();
                    const targetQuarter = Math.floor(periodStartDate.getMonth() / 3);
                    const userStartQuarter = Math.floor(userStartDate.getMonth() / 3);
                    
                    if (targetYear > userStartYear || (targetYear === userStartYear && targetQuarter >= userStartQuarter)) {
                        if (targetYear === userStartYear && targetQuarter === userStartQuarter) {
                            const quarterStartMonth = targetQuarter * 3;
                            const userStartMonth = userStartDate.getMonth();
                            const monthsWorkedInQuarter = (quarterStartMonth + 3) - userStartMonth;
                            goalForPeriod = (user.yearlyTarget / 12) * monthsWorkedInQuarter;
                        } else {
                            goalForPeriod = quarterlyGoal;
                        }
                    }
                    break;
                }
                
                case 'This Year':
                case 'Last Year': {
                    const targetYear = periodStartDate.getFullYear();
                    const userStartYear = userStartDate.getFullYear();
                    
                    if (targetYear >= userStartYear) {
                        if (targetYear === userStartYear) {
                            const userStartMonth = userStartDate.getMonth();
                            const remainingMonths = 12 - userStartMonth;
                            goalForPeriod = (user.yearlyTarget / 12) * remainingMonths;
                        } else {
                            goalForPeriod = user.yearlyTarget;
                        }
                    }
                    break;
                }
                
                default: { // For custom date ranges
                    // Use period dates (not adjusted for user start date) for pattern matching
                    const startYear = periodStartDate.getFullYear();
                    const startMonth = periodStartDate.getMonth();
                    const startDay = periodStartDate.getDate();
                    const endYear = periodEndDate.getFullYear();
                    const endMonth = periodEndDate.getMonth();
                    const endDay = periodEndDate.getDate();

                    // Check if custom range matches a full year (Jan 1 - Dec 31)
                    const isFullYear = startMonth === 0 && startDay === 1 &&
                                      endMonth === 11 && endDay === 31 &&
                                      startYear === endYear;

                    // Check if custom range matches a full quarter
                    const quarterStarts = [0, 3, 6, 9]; // Jan, Apr, Jul, Oct
                    const quarterEnds = [2, 5, 8, 11]; // Mar, Jun, Sep, Dec
                    const quarterEndDays = [31, 30, 30, 31]; // Last day of each quarter-end month

                    let isFullQuarter = false;
                    for (let i = 0; i < 4; i++) {
                        if (startMonth === quarterStarts[i] && startDay === 1 &&
                            endMonth === quarterEnds[i] && endDay === quarterEndDays[i] &&
                            startYear === endYear) {
                            isFullQuarter = true;
                            break;
                        }
                    }

                    // Check if custom range matches a full month
                    const daysInMonth = new Date(startYear, startMonth + 1, 0).getDate();
                    const isFullMonth = startDay === 1 &&
                                       endMonth === startMonth &&
                                       endDay === daysInMonth &&
                                       startYear === endYear;

                    // Apply appropriate calculation based on pattern match
                    if (isFullYear) {
                        // Full year: use yearly target
                        const targetYear = periodStartDate.getFullYear();
                        const userStartYear = userStartDate.getFullYear();

                        if (targetYear >= userStartYear) {
                            if (targetYear === userStartYear) {
                                const userStartMonth = userStartDate.getMonth();
                                const remainingMonths = 12 - userStartMonth;
                                goalForPeriod = (user.yearlyTarget / 12) * remainingMonths;
                            } else {
                                goalForPeriod = user.yearlyTarget;
                            }
                        }
                    } else if (isFullQuarter) {
                        // Full quarter: use 1/4 of yearly target
                        const quarterlyGoal = user.yearlyTarget / 4;
                        const targetYear = periodStartDate.getFullYear();
                        const userStartYear = userStartDate.getFullYear();
                        const targetQuarter = Math.floor(periodStartDate.getMonth() / 3);
                        const userStartQuarter = Math.floor(userStartDate.getMonth() / 3);

                        if (targetYear > userStartYear || (targetYear === userStartYear && targetQuarter >= userStartQuarter)) {
                            if (targetYear === userStartYear && targetQuarter === userStartQuarter) {
                                const quarterStartMonth = targetQuarter * 3;
                                const userStartMonth = userStartDate.getMonth();
                                const monthsWorkedInQuarter = (quarterStartMonth + 3) - userStartMonth;
                                goalForPeriod = (user.yearlyTarget / 12) * monthsWorkedInQuarter;
                            } else {
                                goalForPeriod = quarterlyGoal;
                            }
                        }
                    } else if (isFullMonth) {
                        // Full month: use 1/12 of yearly target
                        const monthlyGoal = user.yearlyTarget / 12;
                        const targetYear = periodStartDate.getFullYear();
                        const userStartYear = userStartDate.getFullYear();
                        const targetMonth = periodStartDate.getMonth();
                        const userStartMonth = userStartDate.getMonth();

                        if (targetYear > userStartYear || (targetYear === userStartYear && targetMonth >= userStartMonth)) {
                            goalForPeriod = monthlyGoal;
                        }
                    } else {
                        // Partial period: use days proportion
                        const effectiveStartDate = periodStartDate >= userStartDate ? periodStartDate : userStartDate;
                        const totalDays = Math.floor((periodEndDate - effectiveStartDate) / (1000 * 60 * 60 * 24)) + 1;
                        goalForPeriod = (totalDays / 365) * user.yearlyTarget;
                    }
                    break;
                }
            }
            totalGoalForPeriod += goalForPeriod;
        });

        this.currentTargetGoal = this.roundToQuarterHour(Math.max(0, totalGoalForPeriod));
    }

    // Collection Rate Chart Methods
    initializeCollectionRateChart() {
        const canvas = this.template.querySelector('.collectionRateChart');
        if (canvas && window.Chart) {
            const ctx = canvas.getContext('2d');
            
            const collectionRatePercent = this.collectionRate || 0;
            const remainingPercent = Math.max(0, 100 - collectionRatePercent);
            
            this.collectionRateChart = new window.Chart(ctx, {
                type: 'doughnut',
                data: {
                    datasets: [{
                        data: [collectionRatePercent, remainingPercent],
                        backgroundColor: [
                            '#00C851', // Green for collected
                            '#f5f5f5'  // Light gray for remaining
                        ],
                        borderWidth: 0,
                        cutout: '70%'
                    }]
                },
                options: {
                    responsive: true,
                    maintainAspectRatio: false,
                    plugins: {
                        legend: {
                            display: false
                        },
                        tooltip: {
                            enabled: false
                        }
                    }
                }
            });
        }
    }

    updateCollectionRateChart() {
        if (this.collectionRateChart && this.collectionRateChart.data && this.collectionRateChart.data.datasets) {
            const collectionRatePercent = this.collectionRate || 0;
            const remainingPercent = Math.max(0, 100 - collectionRatePercent);
            
            this.collectionRateChart.data.datasets[0].data = [collectionRatePercent, remainingPercent];
            this.collectionRateChart.update();
        }
    }

    get collectionRateFormatted() {
        return (this.collectionRate || 0).toFixed(1);
    }

    // Modal data table columns
    get modalColumns() {
        return [
            {
                label: 'Invoice Number',
                fieldName: 'invoiceNumber',
                type: 'text'
            },
            {
                label: 'Date',
                fieldName: 'invoiceDate',
                type: 'date',
                typeAttributes: {
                    month: '2-digit',
                    day: '2-digit',
                    year: 'numeric'
                }
            },
            {
                label: 'Total Amount',
                fieldName: 'totalAmount',
                type: 'currency'
            },
            {
                label: 'Payments Received',
                fieldName: 'paymentsReceivedTotal',
                type: 'currency'
            },
            {
                label: 'Outstanding Balance',
                fieldName: 'outstandingBalance',
                type: 'currency'
            },
            {
                label: 'Status',
                fieldName: 'status',
                type: 'text'
            },
            {
                label: 'Team',
                fieldName: 'teamMatter',
                type: 'text'
            },
            {
                label: 'Matter',
                fieldName: 'matter',
                type: 'text'
            },
            {
                label: 'Responsible Attorney',
                fieldName: 'responsibleAttorney',
                type: 'text'
            },
            {
                type: 'action',
                typeAttributes: {
                    rowActions: [
                        {
                            label: 'View Record',
                            name: 'view_record'
                        }
                    ]
                }
            }
        ];
    }

    // Modal pagination computed properties
    get totalPages() {
        return Math.ceil(this.totalRecords / this.pageSize);
    }

    get hasMultiplePages() {
        return this.totalPages > 1;
    }

    get hasPreviousPage() {
        return this.currentPage > 1;
    }

    get hasNextPage() {
        return this.currentPage < this.totalPages;
    }

    get pageInfo() {
        const startRecord = (this.currentPage - 1) * this.pageSize + 1;
        const endRecord = Math.min(this.currentPage * this.pageSize, this.totalRecords);
        return `${startRecord}-${endRecord} of ${this.totalRecords}`;
    }

    // Time Entry Modal pagination computed properties
    get timeEntryTotalPages() {
        return Math.ceil(this.timeEntryTotalRecords / this.timeEntryPageSize);
    }

    get hasTimeEntryMultiplePages() {
        return this.timeEntryTotalPages > 1;
    }

    get hasTimeEntryPreviousPage() {
        return this.timeEntryCurrentPage > 1;
    }

    get hasTimeEntryNextPage() {
        return this.timeEntryCurrentPage < this.timeEntryTotalPages;
    }

    get timeEntryPageInfo() {
        const startRecord = (this.timeEntryCurrentPage - 1) * this.timeEntryPageSize + 1;
        const endRecord = Math.min(this.timeEntryCurrentPage * this.timeEntryPageSize, this.timeEntryTotalRecords);
        return `${startRecord}-${endRecord} of ${this.timeEntryTotalRecords}`;
    }

    // Chart Click Handlers
    handleCollectionRateClick() {
        console.log('Collection Rate chart clicked!');
        this.openModal();
    }

    handleTimeSummaryClick() {
        console.log('Time Summary chart clicked!');
        this.openTimeEntryModal('Time Summary Details');
    }

    handleGoalProgressClick() {
        console.log('Goal Progress chart clicked!');
        this.openTimeEntryModal('Goal Progress Details');
    }

    // Modal methods
    openModal() {
        console.log('Opening Collection Rate modal...');
        this.modalTitle = 'Collection Rate Details';
        this.showModal = true;
        this.isLoadingModal = true;
        this.invoiceDetails = [];
        this.allInvoiceDetails = [];
        this.currentPage = 1;

        getCollectionRateDetails({
            dateFilter: this.dateFilter,
            startDate: this.startDate,
            endDate: this.endDate,
            team: this.teamFilter,
            userId: this.personFilter
        })
        .then(result => {
            this.allInvoiceDetails = result;
            this.totalRecords = result.length;
            this.updateDisplayedRecords();
        })
        .catch(error => {
            console.error('Error fetching collection rate details:', error);
        })
        .finally(() => {
            this.isLoadingModal = false;
        });
    }

    closeModal() {
        this.showModal = false;
        this.modalTitle = '';
        this.invoiceDetails = [];
        this.allInvoiceDetails = [];
        this.currentPage = 1;
        this.totalRecords = 0;
    }

    updateDisplayedRecords() {
        const startIndex = (this.currentPage - 1) * this.pageSize;
        const endIndex = startIndex + this.pageSize;
        this.invoiceDetails = this.allInvoiceDetails.slice(startIndex, endIndex);
    }

    // Modal pagination handlers
    handlePreviousPage() {
        if (this.hasPreviousPage) {
            this.currentPage--;
            this.updateDisplayedRecords();
        }
    }

    handleNextPage() {
        if (this.hasNextPage) {
            this.currentPage++;
            this.updateDisplayedRecords();
        }
    }

    handleFirstPage() {
        this.currentPage = 1;
        this.updateDisplayedRecords();
    }

    handleLastPage() {
        this.currentPage = this.totalPages;
        this.updateDisplayedRecords();
    }

    handleRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;
        
        if (actionName === 'view_record') {
            // Generate the URL for the record page and open in new tab
            this[NavigationMixin.GenerateUrl]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: row.invoiceId,
                    objectApiName: 'Invoice__c',
                    actionName: 'view'
                }
            }).then(url => {
                window.open(url, '_blank');
            });
        }
    }

    handleDownloadCSV() {
        console.log('CSV Download clicked');
        console.log('allInvoiceDetails:', this.allInvoiceDetails);
        
        if (!this.allInvoiceDetails || this.allInvoiceDetails.length === 0) {
            console.log('No data available for download');
            return;
        }

        // CSV headers
        const headers = [
            'Invoice Number',
            'Date',
            'Total Amount',
            'Payments Received',
            'Outstanding Balance',
            'Status',
            'Team',
            'Matter',
            'Responsible Attorney'
        ];

        // Convert data to CSV format
        let csvContent = headers.join(',') + '\n';

        this.allInvoiceDetails.forEach(invoice => {
            const row = [
                `"${invoice.invoiceNumber || ''}"`,
                `"${invoice.invoiceDate || ''}"`,
                `"${invoice.totalAmount || '0'}"`,
                `"${invoice.paymentsReceivedTotal || '0'}"`,
                `"${invoice.outstandingBalance || '0'}"`,
                `"${invoice.status || ''}"`,
                `"${invoice.teamMatter || ''}"`,
                `"${invoice.matter || ''}"`,
                `"${invoice.responsibleAttorney || ''}"`
            ];
            csvContent += row.join(',') + '\n';
        });

        // Create and download the file using Salesforce-compatible method
        try {
            console.log('Creating CSV download...');
            const fileName = `${this.modalTitle.replace(/\s+/g, '_')}_${new Date().toISOString().split('T')[0]}.csv`;
            
            // Use data URI instead of blob for Salesforce compatibility
            const dataUri = 'data:text/csv;charset=utf-8,' + encodeURIComponent(csvContent);
            
            const link = document.createElement('a');
            link.setAttribute('href', dataUri);
            link.setAttribute('download', fileName);
            link.style.visibility = 'hidden';
            
            document.body.appendChild(link);
            
            console.log('Triggering download for:', fileName);
            link.click();
            
            // Clean up
            document.body.removeChild(link);
            
            console.log('CSV download completed');
        } catch (error) {
            console.error('Error during CSV download:', error);
            // Fallback: copy to clipboard if download fails
            try {
                navigator.clipboard.writeText(csvContent).then(() => {
                    console.log('CSV data copied to clipboard as fallback');
                });
            } catch (clipboardError) {
                console.error('Clipboard fallback also failed:', clipboardError);
            }
        }
    }

    // Time Entry Modal methods
    openTimeEntryModal(title) {
        console.log('Opening Time Entry modal:', title);
        this.timeEntryModalTitle = title;
        this.showTimeEntryModal = true;
        this.isLoadingTimeEntryModal = true;
        this.timeEntryModalData = [];
        this.allTimeEntryModalData = [];
        this.timeEntryCurrentPage = 1;

        // Filter time entries to only include those with actual hours > 0
        this.allTimeEntryModalData = this.allTimeEntries.filter(entry => {
            const hours = parseFloat(entry.Hours__c);
            return hours && hours > 0;
        });
        
        console.log('Filtered time entries for modal:', this.allTimeEntryModalData.length, 'entries with hours > 0');
        this.timeEntryTotalRecords = this.allTimeEntryModalData.length;
        this.updateTimeEntryDisplayedRecords();
        this.isLoadingTimeEntryModal = false;
    }

    closeTimeEntryModal() {
        this.showTimeEntryModal = false;
        this.timeEntryModalTitle = '';
        this.timeEntryModalData = [];
        this.allTimeEntryModalData = [];
        this.timeEntryCurrentPage = 1;
        this.timeEntryTotalRecords = 0;
    }

    updateTimeEntryDisplayedRecords() {
        const startIndex = (this.timeEntryCurrentPage - 1) * this.timeEntryPageSize;
        const endIndex = startIndex + this.timeEntryPageSize;
        this.timeEntryModalData = this.allTimeEntryModalData.slice(startIndex, endIndex);
    }

    // Time Entry Modal pagination handlers
    handleTimeEntryPreviousPage() {
        if (this.hasTimeEntryPreviousPage) {
            this.timeEntryCurrentPage--;
            this.updateTimeEntryDisplayedRecords();
        }
    }

    handleTimeEntryNextPage() {
        if (this.hasTimeEntryNextPage) {
            this.timeEntryCurrentPage++;
            this.updateTimeEntryDisplayedRecords();
        }
    }

    handleTimeEntryFirstPage() {
        this.timeEntryCurrentPage = 1;
        this.updateTimeEntryDisplayedRecords();
    }

    handleTimeEntryLastPage() {
        this.timeEntryCurrentPage = this.timeEntryTotalPages;
        this.updateTimeEntryDisplayedRecords();
    }

    handleDownloadTimeEntryCSV() {
        console.log('Time Entry CSV Download clicked');
        console.log('allTimeEntryModalData:', this.allTimeEntryModalData);
        
        if (!this.allTimeEntryModalData || this.allTimeEntryModalData.length === 0) {
            console.log('No time entry data available for download');
            return;
        }

        // CSV headers matching the existing Time Entry table columns
        const headers = [
            'User',
            'Date', 
            'Matter',
            'Note',
            'Hours',
            'Rate',
            'Amount',
            'Billable Status'
        ];

        // Convert data to CSV format
        let csvContent = headers.join(',') + '\n';
        
        this.allTimeEntryModalData.forEach(entry => {
            const row = [
                `"${entry.UserName || ''}"`,
                `"${entry.Date__c || ''}"`,
                `"${entry.MatterName || ''}"`,
                `"${entry.Note__c || ''}"`,
                `"${entry.Hours__c || '0'}"`,
                `"${entry.Rate__c || '0'}"`,
                `"${entry.Amount__c || '0'}"`,
                `"${entry.BillableStatus || ''}"`
            ];
            csvContent += row.join(',') + '\n';
        });

        // Create and download the file
        try {
            console.log('Creating Time Entry CSV download...');
            const fileName = `${this.timeEntryModalTitle.replace(/\s+/g, '_')}_${new Date().toISOString().split('T')[0]}.csv`;
            
            // Use data URI for Salesforce compatibility
            const dataUri = 'data:text/csv;charset=utf-8,' + encodeURIComponent(csvContent);
            
            const link = document.createElement('a');
            link.setAttribute('href', dataUri);
            link.setAttribute('download', fileName);
            link.style.visibility = 'hidden';
            
            document.body.appendChild(link);
            
            console.log('Triggering download for:', fileName);
            link.click();
            
            // Clean up
            document.body.removeChild(link);
            
            console.log('Time Entry CSV download completed');
        } catch (error) {
            console.error('Error during Time Entry CSV download:', error);
            // Fallback: copy to clipboard if download fails
            try {
                navigator.clipboard.writeText(csvContent).then(() => {
                    console.log('Time Entry CSV data copied to clipboard as fallback');
                });
            } catch (clipboardError) {
                console.error('Clipboard fallback also failed:', clipboardError);
            }
        }
    }
}