import { LightningElement, wire, track } from 'lwc';
import { loadScript } from 'lightning/platformResourceLoader';
import { NavigationMixin } from 'lightning/navigation';
import chartjs from '@salesforce/resourceUrl/ChartJs';
import getTimeEntries from '@salesforce/apex/TimeEntryDashboardController.getTimeEntries';
import getUserTargetInfo from '@salesforce/apex/TimeEntryDashboardController.getUserTargetInfo';
import getCollectionRate from '@salesforce/apex/TimeEntryDashboardController.getCollectionRate';
import getCollectionRateDetails from '@salesforce/apex/TimeEntryDashboardController.getCollectionRateDetails';
import getCurrentUserTeam from '@salesforce/apex/TimeEntryDashboardController.getCurrentUserTeam';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class PersonalTimeDashboard extends NavigationMixin(LightningElement) {
    @track columns = [];
    @track viewTeam = false;
    userTeam = null;

    @track billableFilter = 'All';
    @track dateFilter = 'This Week';
    @track sortBy = 'Date__c';
    @track sortDirection = 'desc';
    @track error;
    
    // Data properties
    allTimeEntries = [];
    @track paginatedTimeEntries = [];
    
    // Pagination properties
    currentPage = 1;
    pageSize = 25;
    totalPages = 1;

    // User goal properties
    yearlyTarget = 0;
    userStartDate;
    currentTargetGoal = 0;
    teamUserCount = 1;

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
    @track currentModalPage = 1;
    @track modalPageSize = 25;
    @track totalModalRecords = 0;

    // Reactive getters for date calculations
    get startDate() {
        return this.calculateStartDate(this.dateFilter);
    }
    get endDate() {
        return this.calculateEndDate(this.dateFilter);
    }

    // Wire Apex methods
    @wire(getTimeEntries, { 
        startDate: '$startDate', 
        endDate: '$endDate', 
        billableStatus: '$billableFilter',
        viewTeam: '$viewTeam'
    })
    wiredTimeEntries({ error, data }) {
        if (data) {
            // Filter out entries related to 'Clio Migration' matters
            const filteredData = data.filter(entry => {
                return !(entry.Matter__r && entry.Matter__r.Name && entry.Matter__r.Name.includes('Clio Migration'));
            });

            this.allTimeEntries = filteredData.map(entry => ({
                ...entry,
                MatterName: entry.Matter__r ? entry.Matter__r.Name : '',
                IsBillableStatus: entry.Non_Billable__c ? 'No' : 'Yes',
                UserName: entry.User__r ? entry.User__r.Name : ''
            }));
            this.updateColumns();
            this.sortData(this.sortBy, this.sortDirection);
            this.error = undefined;
        } else if (error) {
            this.error = error;
            this.allTimeEntries = [];
            this.showToast('Error', 'An error occurred while fetching time entries.', 'error');
        }
        this.setupPagination();
    }

    @wire(getUserTargetInfo, { viewTeam: '$viewTeam' })
    wiredUser({ error, data }) {
        if (data) {
            this.yearlyTarget = data.targetHours || 0;
            this.userStartDate = data.startDate ? new Date(data.startDate + 'T00:00:00') : null;
            this.teamUserCount = data.userCount || 1;
            this.calculateCurrentTargetGoal();
        } else if (error) {
            this.error = error;
             this.showToast('Error', 'An error occurred while fetching user goal information.', 'error');
        }
    }

    @wire(getCollectionRate, { 
        dateFilter: '$dateFilter',
        startDate: null, 
        endDate: null,
        viewTeam: '$viewTeam'
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

    get gaugeTicks() {
        const ticks = [];
        const numTicks = 5;
        const center = 100;
        const gaugeArcRadius = 75;
        const gaugeArcStrokeWidth = 20;
        const outerRadius = gaugeArcRadius + (gaugeArcStrokeWidth / 2);

        for (let i = 0; i <= numTicks; i++) {
            const angle = -Math.PI + (i / numTicks) * Math.PI;

            const x1 = center + outerRadius * Math.cos(angle);
            const y1 = center + outerRadius * Math.sin(angle);
            const x2 = center + (outerRadius + 5) * Math.cos(angle);
            const y2 = center + (outerRadius + 5) * Math.sin(angle);
            
            const textRadius = outerRadius + 12;
            const tx = center + textRadius * Math.cos(angle);
            const ty = center + textRadius * Math.sin(angle);

            ticks.push({
                label: this.formatTickLabel((this.currentTargetGoal * i) / numTicks),
                x1, y1, x2, y2, tx, ty
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

    // Collection rate getters
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
    get totalModalPages() {
        return Math.ceil(this.totalModalRecords / this.modalPageSize);
    }

    get hasMultipleModalPages() {
        return this.totalModalPages > 1;
    }

    get hasPreviousModalPage() {
        return this.currentModalPage > 1;
    }

    get hasNextModalPage() {
        return this.currentModalPage < this.totalModalPages;
    }

    get modalPageInfo() {
        const startRecord = (this.currentModalPage - 1) * this.modalPageSize + 1;
        const endRecord = Math.min(this.currentModalPage * this.modalPageSize, this.totalModalRecords);
        return `${startRecord}-${endRecord} of ${this.totalModalRecords}`;
    }
    
    // Handlers
    handleFilterChange(event) {
        const { name, value } = event.target;
        this[name] = value;
        if (name === 'dateFilter') {
            this.calculateCurrentTargetGoal(); // Recalculate goal when date filter changes
        }
    }

    handleViewTeamChange(event) {
        this.viewTeam = event.target.checked;
        this.updateColumns();
        this.calculateCurrentTargetGoal();
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
        if (!this.userStartDate || !this.yearlyTarget) {
            this.currentTargetGoal = 0;
            return;
        }

        const userStartDate = new Date(this.userStartDate);
        const periodStartDate = new Date(this.startDate + 'T00:00:00');
        const periodEndDate = new Date(this.endDate + 'T00:00:00');
        
        const dailyGoal = this.yearlyTarget / 240;
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
                const weeklyGoal = this.yearlyTarget / 48;
                if (periodEndDate >= userStartDate) {
                    goalForPeriod = weeklyGoal;
                }
                break;
            }
            
            case 'This Month':
            case 'Last Month': {
                const monthlyGoal = this.yearlyTarget / 12;
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
                const quarterlyGoal = this.yearlyTarget / 4;
                const targetYear = periodStartDate.getFullYear();
                const userStartYear = userStartDate.getFullYear();
                const targetQuarter = Math.floor(periodStartDate.getMonth() / 3);
                const userStartQuarter = Math.floor(userStartDate.getMonth() / 3);
                
                if (targetYear > userStartYear || (targetYear === userStartYear && targetQuarter >= userStartQuarter)) {
                    if (targetYear === userStartYear && targetQuarter === userStartQuarter) {
                        const quarterStartMonth = targetQuarter * 3;
                        const userStartMonth = userStartDate.getMonth();
                        const monthsWorkedInQuarter = (quarterStartMonth + 3) - userStartMonth;
                        goalForPeriod = (this.yearlyTarget / 12) * monthsWorkedInQuarter;
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
                        goalForPeriod = (this.yearlyTarget / 12) * remainingMonths;
                    } else {
                        goalForPeriod = this.yearlyTarget;
                    }
                }
                break;
            }
            
            default: { // For custom date ranges, which are not a standard filter option
                let workingDays = 0;
                let currentDate = new Date(Math.max(periodStartDate.getTime(), userStartDate.getTime()));
                while (currentDate <= periodEndDate) {
                    const dayOfWeek = currentDate.getDay();
                    if (dayOfWeek > 0 && dayOfWeek < 6) {
                        workingDays++;
                    }
                    currentDate.setDate(currentDate.getDate() + 1);
                }
                goalForPeriod = dailyGoal * workingDays;
                break;
            }
        }
        this.currentTargetGoal = this.roundToQuarterHour(Math.max(0, goalForPeriod));
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

    // Chart Click Handlers
    handleCollectionRateClick() {
        console.log('Collection Rate chart clicked!');
        this.openModal();
    }

    connectedCallback() {
        // Initialize columns
        this.updateColumns();
        
        // Get current user's team
        getCurrentUserTeam()
            .then(result => {
                this.userTeam = result;
            })
            .catch(error => {
                console.error('Error fetching user team:', error);
            });
    }

    updateColumns() {
        const baseColumns = [
            { label: 'Date', fieldName: 'Date__c', type: 'date-local', sortable: true, typeAttributes:{ month: 'short', day: 'numeric', year: 'numeric' } },
            { label: 'Matter', fieldName: 'MatterName', type: 'text', sortable: true },
            { label: 'Notes', fieldName: 'Note__c', type: 'text', sortable: true },
            { label: 'Hours', fieldName: 'Hours__c', type: 'number', sortable: true, typeAttributes: { minimumFractionDigits: '2', maximumFractionDigits: '2' }},
            { label: 'Rate', fieldName: 'Rate__c', type: 'currency', sortable: true },
            { label: 'Billable', fieldName: 'IsBillableStatus', type: 'text', sortable: true }
        ];

        if (this.viewTeam) {
            // Add User column when viewing team data
            this.columns = [
                baseColumns[0], // Date
                { label: 'User', fieldName: 'UserName', type: 'text', sortable: true },
                ...baseColumns.slice(1) // Rest of columns
            ];
        } else {
            this.columns = baseColumns;
        }
    }

    // Modal methods
    openModal() {
        console.log('Opening Collection Rate modal...');
        this.modalTitle = 'Collection Rate Details';
        this.showModal = true;
        this.isLoadingModal = true;
        this.invoiceDetails = [];
        this.allInvoiceDetails = [];
        this.currentModalPage = 1;

        getCollectionRateDetails({
            dateFilter: this.dateFilter,
            startDate: null,
            endDate: null,
            viewTeam: this.viewTeam
        })
        .then(result => {
            this.allInvoiceDetails = result;
            this.totalModalRecords = result.length;
            this.updateModalDisplayedRecords();
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
        this.currentModalPage = 1;
        this.totalModalRecords = 0;
    }

    updateModalDisplayedRecords() {
        const startIndex = (this.currentModalPage - 1) * this.modalPageSize;
        const endIndex = startIndex + this.modalPageSize;
        this.invoiceDetails = this.allInvoiceDetails.slice(startIndex, endIndex);
    }

    // Modal pagination handlers
    handlePreviousModalPage() {
        if (this.hasPreviousModalPage) {
            this.currentModalPage--;
            this.updateModalDisplayedRecords();
        }
    }

    handleNextModalPage() {
        if (this.hasNextModalPage) {
            this.currentModalPage++;
            this.updateModalDisplayedRecords();
        }
    }

    handleFirstModalPage() {
        this.currentModalPage = 1;
        this.updateModalDisplayedRecords();
    }

    handleLastModalPage() {
        this.currentModalPage = this.totalModalPages;
        this.updateModalDisplayedRecords();
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
            'Matter'
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
                `"${invoice.matter || ''}"`
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
}