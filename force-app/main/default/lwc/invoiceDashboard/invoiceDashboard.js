import { LightningElement, wire, track } from 'lwc';
import { loadScript } from 'lightning/platformResourceLoader';
import { NavigationMixin } from 'lightning/navigation';
import chartjs from '@salesforce/resourceUrl/ChartJs';
import getDashboardData from '@salesforce/apex/InvoiceDashboardController.getDashboardData';
import getTeamOptions from '@salesforce/apex/InvoiceDashboardController.getTeamOptions';
import getInvoiceDetails from '@salesforce/apex/InvoiceDashboardController.getInvoiceDetails';

export default class InvoiceDashboard extends NavigationMixin(LightningElement) {
    @track dateFilter = 'Last Month';
    @track teamFilter = 'All';
    @track startDate = null;
    @track endDate = null;

    @track totalInvoiced = 0;
    @track paymentsReceived = 0;
    @track outstandingBalance = 0;
    @track collectionRate = 0;

    @track teamOptions = [{ label: 'All', value: 'All' }];
    @track showModal = false;
    @track modalTitle = '';
    @track invoiceDetails = [];
    @track allInvoiceDetails = [];
    @track paymentDetails = [];
    @track paymentsTotal = 0;
    @track creditNotesTotal = 0;
    @track combinedApplied = 0;
    @track showPaymentModal = false;
    @track isLoadingModal = false;
    @track currentPage = 1;
    @track pageSize = 25;
    @track totalRecords = 0;
    @track selectedInvoiceId = null;

    chartsInitialized = false;
    totalInvoicedChart;
    paymentsReceivedChart;
    outstandingBalanceChart;
    collectionRateChart;

    @wire(getDashboardData, { dateFilter: '$dateFilter', teamFilter: '$teamFilter', startDate: '$startDate', endDate: '$endDate' })
    wiredDashboardData({ error, data }) {
        if (data) {
            this.dashboardData = data;
            this.totalInvoiced = data.totalInvoiced;
            this.paymentsReceived = data.paymentsReceived;
            this.outstandingBalance = data.outstandingBalance;
            this.collectionRate = data.collectionRate;
            
            if (this.chartsInitialized && this.hasValidDateSelection) {
                // If charts exist but we need to show them, recreate them
                if (this.totalInvoicedChart) {
                    this.updateCharts(data);
                } else {
                    // Charts were destroyed, recreate them
                    this.recreateCharts();
                }
            } else if (!this.chartsInitialized && this.hasValidDateSelection) {
                loadScript(this, chartjs)
                    .then(() => {
                        this.initializeCharts(data);
                        this.chartsInitialized = true;
                    })
                    .catch(error => {
                        console.error('Error loading Chart.js', error);
                    });
            }
        } else if (error) {
            console.error('Error fetching dashboard data:', error);
        }
    }

    @wire(getTeamOptions, { dateFilter: '$dateFilter', startDate: '$startDate', endDate: '$endDate' })
    wiredTeamOptions({ error, data }) {
        if (data) {
            this.teamOptions = [{ label: 'All', value: 'All' }];
            data.forEach(team => {
                this.teamOptions.push({ label: team, value: team });
            });
        } else if (error) {
            console.error('Error fetching team options:', error);
        }
    }


    initializeCharts(data) {
        const invoicedLabels = data.invoicedByTeam.map(item => item.label);
        const invoicedData = data.invoicedByTeam.map(item => Math.floor(item.value));
        
        const paymentsLabels = data.paymentsByTeam.map(item => item.label);
        const paymentsData = data.paymentsByTeam.map(item => Math.floor(item.value));
        
        const outstandingLabels = data.outstandingByTeam.map(item => item.label);
        const outstandingData = data.outstandingByTeam.map(item => Math.floor(item.value));
        
        const collectionRateLabels = data.collectionRateByTeam.map(item => item.label);
        const collectionRateData = data.collectionRateByTeam.map(item => item.value);

        // Use a single, consistent color per chart to avoid mixed light/dark bars
        this.totalInvoicedChart = this.createChart('totalInvoicedChart', 'Total Invoiced Amount', invoicedLabels, invoicedData, '#4F7DE2');
        this.paymentsReceivedChart = this.createChart('paymentsReceivedChart', 'Payments Received', paymentsLabels, paymentsData, '#34CE57');
        this.outstandingBalanceChart = this.createChart('outstandingBalanceChart', 'Outstanding Balance', outstandingLabels, outstandingData, '#dc3545');
        this.collectionRateChart = this.createChart('collectionRateChart', 'Collection Rate (%)', collectionRateLabels, collectionRateData, '#ffc107', true);
    }

    updateCharts(data) {
        const invoicedLabels = data.invoicedByTeam.map(item => item.label);
        const invoicedData = data.invoicedByTeam.map(item => Math.floor(item.value));
        
        const paymentsLabels = data.paymentsByTeam.map(item => item.label);
        const paymentsData = data.paymentsByTeam.map(item => Math.floor(item.value));
        
        const outstandingLabels = data.outstandingByTeam.map(item => item.label);
        const outstandingData = data.outstandingByTeam.map(item => Math.floor(item.value));
        
        const collectionRateLabels = data.collectionRateByTeam.map(item => item.label);
        const collectionRateData = data.collectionRateByTeam.map(item => item.value);

        this.updateChartData(this.totalInvoicedChart, invoicedLabels, invoicedData);
        this.updateChartData(this.paymentsReceivedChart, paymentsLabels, paymentsData);
        this.updateChartData(this.outstandingBalanceChart, outstandingLabels, outstandingData);
        this.updateChartData(this.collectionRateChart, collectionRateLabels, collectionRateData, true);
    }
    
    createChart(canvasSelector, label, labels, data, backgroundColors, isPercentage = false) {
        const canvas = this.template.querySelector(`.${canvasSelector}`);
        if (canvas) {
            const ctx = canvas.getContext('2d');
            
            // Calculate suggested max to add padding (25% more than max value)
            const maxValue = Math.max(...(data || [0]));
            const suggestedMax = isPercentage ? 100 : (maxValue > 0 ? maxValue * 1.25 : 100);
            
            // Create consistent colors based on team names, not array index
            let colors = this.getConsistentColors(labels, backgroundColors);
            
            // Ensure colors is always an array with valid values
            if (!Array.isArray(colors)) {
                colors = labels.map(() => colors || '#4F7DE2');
            } else {
                // Validate each color
                colors = colors.map(c => c || '#4F7DE2');
            }
            
            return new window.Chart(ctx, {
                type: 'bar',
                data: {
                    labels: labels,
                    datasets: [{
                        label: label,
                        data: data,
                        backgroundColor: colors,
                        borderRadius: 6,
                        borderSkipped: false,
                    }]
                },
                options: {
                    indexAxis: 'y',
                    responsive: true,
                    maintainAspectRatio: false,
                    animation: {
                        duration: 750,
                        easing: 'easeInOutQuart'
                    },
                    layout: {
                        padding: {
                            top: 10,
                            right: 20,
                            bottom: 10,
                            left: 10
                        }
                    },
                    plugins: {
                        legend: {
                            display: false
                        },
                        tooltip: {
                            backgroundColor: 'rgba(0, 0, 0, 0.8)',
                            titleColor: '#fff',
                            bodyColor: '#fff',
                            borderColor: '#ddd',
                            borderWidth: 1,
                            cornerRadius: 8,
                            displayColors: false,
                            callbacks: {
                                label: function(context) {
                                    if (isPercentage) {
                                        return context.parsed.x.toFixed(1) + '%';
                                    }
                                    return new Intl.NumberFormat('en-US', {
                                        style: 'currency',
                                        currency: 'USD'
                                    }).format(context.parsed.x);
                                }
                            }
                        }
                    },
                    scales: {
                        x: {
                            beginAtZero: true,
                            suggestedMax: suggestedMax,
                            grid: {
                                color: '#f5f5f5',
                                lineWidth: 1
                            },
                            ticks: {
                                color: '#666',
                                font: {
                                    size: 11,
                                    family: 'Salesforce Sans, Arial, sans-serif'
                                },
                                callback: function(value) {
                                    if (isPercentage) {
                                        return value.toFixed(0) + '%';
                                    }
                                    return new Intl.NumberFormat('en-US', {
                                        style: 'currency',
                                        currency: 'USD',
                                        minimumFractionDigits: 0,
                                        maximumFractionDigits: 0
                                    }).format(value);
                                }
                            }
                        },
                        y: {
                            grid: {
                                display: false
                            },
                            ticks: {
                                color: '#333',
                                font: {
                                    size: 12,
                                    weight: 500,
                                    family: 'Salesforce Sans, Arial, sans-serif'
                                }
                            }
                        }
                    }
                }
            });
        }
        return null;
    }

    updateChartData(chart, labels, data, isPercentage = false) {
        if (chart && chart.data && chart.data.datasets && chart.data.datasets[0]) {
            chart.data.labels = labels || [];
            chart.data.datasets[0].data = data || [];
            
            // Always update colors to maintain consistency and prevent black bars
            const baseColors = this.getBaseColorsFromChart(chart);
            const newColors = this.getConsistentColors(labels, baseColors);
            
            // Ensure colors is an array with valid values
            if (Array.isArray(newColors)) {
                chart.data.datasets[0].backgroundColor = newColors;
            } else {
                // If single color returned, apply to all bars
                chart.data.datasets[0].backgroundColor = labels.map(() => newColors || '#4F7DE2');
            }
            
            // Update the suggested max to maintain padding
            const maxValue = Math.max(...(data || [0]));
            const suggestedMax = isPercentage ? 100 : (maxValue > 0 ? maxValue * 1.25 : 100);
            if (chart.options && chart.options.scales && chart.options.scales.x) {
                chart.options.scales.x.suggestedMax = suggestedMax;
            }
            
            // Update chart with smooth animations
            chart.update();
        }
    }

    getConsistentColors(labels, backgroundColors) {
        // Allow a single color string to be used for all bars
        if (typeof backgroundColors === 'string') {
            return backgroundColors;
        }

        if (!Array.isArray(backgroundColors) || backgroundColors.length === 0) {
            // Return a default color if no colors provided
            return '#4F7DE2';
        }
        
        if (!labels || labels.length === 0) {
            return backgroundColors[0];
        }
        
        // Create a simple hash function for team names to ensure consistent colors
        const hashTeamName = (teamName) => {
            if (!teamName || typeof teamName !== 'string') {
                return 0;
            }
            let hash = 0;
            for (let i = 0; i < teamName.length; i++) {
                const char = teamName.charCodeAt(i);
                hash = ((hash << 5) - hash) + char;
                hash = hash & hash; // Convert to 32-bit integer
            }
            return Math.abs(hash);
        };
        
        return labels.map(label => {
            const index = hashTeamName(label) % backgroundColors.length;
            const color = backgroundColors[index];
            // Ensure we return a valid color string
            return color || backgroundColors[0] || '#4F7DE2';
        });
    }

    getBaseColorsFromChart(chart) {
        // Store a single base color per chart type (uniform bars)
        const chartElement = chart.canvas;
        if (chartElement.classList.contains('totalInvoicedChart')) {
            return '#4F7DE2';
        } else if (chartElement.classList.contains('paymentsReceivedChart')) {
            return '#34CE57';
        } else if (chartElement.classList.contains('outstandingBalanceChart')) {
            return '#dc3545';
        } else if (chartElement.classList.contains('collectionRateChart')) {
            return '#ffc107';
        }
        return '#4F7DE2'; // Default
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

    // Computed properties for truncated values (not rounded)
    get totalInvoicedTruncated() {
        return Math.floor(this.totalInvoiced || 0);
    }

    get paymentsReceivedTruncated() {
        return Math.floor(this.paymentsReceived || 0);
    }

    get outstandingBalanceTruncated() {
        return Math.floor(this.outstandingBalance || 0);
    }

    // Check if either custom date field has a value (for disabling dropdown)
    get hasCustomDateRange() {
        return (this.startDate && this.startDate !== null && this.startDate !== '') || 
               (this.endDate && this.endDate !== null && this.endDate !== '');
    }

    // Check if BOTH custom dates are filled (for showing charts when using custom range)
    get hasBothCustomDates() {
        return (this.startDate && this.startDate !== null && this.startDate !== '') && 
               (this.endDate && this.endDate !== null && this.endDate !== '');
    }

    // Get placeholder text for date dropdown
    get dateFilterPlaceholder() {
        return this.hasCustomDateRange ? 'Custom dates selected' : '';
    }

    // Check if valid date selection exists for showing charts
    get hasValidDateSelection() {
        // Either dropdown has a value (and no custom dates) OR both custom dates are filled
        if (this.hasCustomDateRange) {
            // If any custom date is entered, require both to be filled
            return this.hasBothCustomDates;
        }
        // Otherwise, just check if dropdown has a value
        return (this.dateFilter && this.dateFilter !== '');
    }

    get startDateContainerClass() {
        return this.startDate ? 'date-input-container has-clear-button' : 'date-input-container';
    }

    get endDateContainerClass() {
        return this.endDate ? 'date-input-container has-clear-button' : 'date-input-container';
    }

    handleFilterChange(event) {
        const { name, value } = event.target;
        this[name] = value;
        if (name === 'dateFilter') {
            this.teamFilter = 'All';
            // Clear custom date range when using dropdown
            this.startDate = null;
            this.endDate = null;
        }
    }

    handleDateRangeChange(event) {
        const { name, value } = event.target;
        this[name] = value;
        
        // Clear dropdown selection when any custom date is entered
        if (this.hasCustomDateRange) {
            this.dateFilter = '';
        }
    }

    clearStartDate() {
        this.startDate = null;
        // Reset to default dropdown if no custom dates remain
        if (!this.endDate) {
            this.dateFilter = 'Last Month';
            // Force data refresh when returning to dropdown
            this.refreshData();
        }
    }

    clearEndDate() {
        this.endDate = null;
        // Reset to default dropdown if no custom dates remain
        if (!this.startDate) {
            this.dateFilter = 'Last Month';
            // Force data refresh when returning to dropdown
            this.refreshData();
        }
    }

    refreshData() {
        // Force the wire services to re-execute by clearing and resetting team filter
        const currentTeamFilter = this.teamFilter;
        this.teamFilter = '';
        // Use setTimeout to ensure the change is processed
        setTimeout(() => {
            this.teamFilter = currentTeamFilter;
        }, 10);
    }

    destroyCharts() {
        if (this.totalInvoicedChart) {
            this.totalInvoicedChart.destroy();
            this.totalInvoicedChart = null;
        }
        if (this.paymentsReceivedChart) {
            this.paymentsReceivedChart.destroy();
            this.paymentsReceivedChart = null;
        }
        if (this.outstandingBalanceChart) {
            this.outstandingBalanceChart.destroy();
            this.outstandingBalanceChart = null;
        }
        if (this.collectionRateChart) {
            this.collectionRateChart.destroy();
            this.collectionRateChart = null;
        }
    }

    recreateCharts() {
        // Small delay to ensure DOM is ready
        setTimeout(() => {
            if (this.dashboardData && this.hasValidDateSelection) {
                this.initializeCharts(this.dashboardData);
            }
        }, 100);
    }

    renderedCallback() {
        // Handle chart lifecycle when visibility changes
        if (this.chartsInitialized && this.dashboardData) {
            if (this.hasValidDateSelection && !this.totalInvoicedChart) {
                // Charts should be visible but don't exist - recreate them
                this.recreateCharts();
            } else if (!this.hasValidDateSelection && this.totalInvoicedChart) {
                // Charts should be hidden but still exist - destroy them
                this.destroyCharts();
            }
        }
    }

    // Data table columns
    get columns() {
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
    
    // Payment details columns for modal
    get paymentColumns() {
        return [
            {
                label: 'Date',
                fieldName: 'paymentDate',
                type: 'date',
                typeAttributes: {
                    month: '2-digit',
                    day: '2-digit',
                    year: 'numeric'
                }
            },
            {
                label: 'Method/Reference',
                fieldName: 'methodRef',
                type: 'text'
            },
            {
                label: 'Amount',
                fieldName: 'amount',
                type: 'currency',
                cellAttributes: {
                    alignment: 'right'
                }
            },
            {
                label: 'Credit Note',
                fieldName: 'creditNote',
                type: 'currency',
                cellAttributes: {
                    alignment: 'right'
                }
            }
        ];
    }

    // Click handlers for metric cards
    handleTotalInvoicedClick() {
        this.openModal('Total Invoiced Amount Details', 'totalInvoiced');
    }

    handlePaymentsReceivedClick() {
        this.openModal('Payments Received Details', 'paymentsReceived');
    }

    handleOutstandingBalanceClick() {
        this.openModal('Outstanding Balance Details', 'outstandingBalance');
    }

    handleCollectionRateClick() {
        this.openModal('Collection Rate Details', 'totalInvoiced');
    }

    // Modal methods
    openModal(title, metricType) {
        this.modalTitle = title;
        this.showModal = true;
        this.isLoadingModal = true;
        this.invoiceDetails = [];
        this.allInvoiceDetails = [];
        this.currentPage = 1;

        getInvoiceDetails({
            dateFilter: this.dateFilter,
            teamFilter: this.teamFilter,
            metricType: metricType,
            startDate: this.startDate,
            endDate: this.endDate
        })
        .then(result => {
            this.allInvoiceDetails = result;
            this.totalRecords = result.length;
            this.updateDisplayedRecords();
        })
        .catch(error => {
            console.error('Error fetching invoice details:', error);
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
    
    openPaymentModal(invoiceId, invoiceNumber) {
        this.selectedInvoiceId = invoiceId;
        this.modalTitle = `Payment Details - ${invoiceNumber}`;
        this.showPaymentModal = true;
        this.isLoadingModal = true;
        this.paymentDetails = [];
        
        getPaymentDetails({ invoiceId: invoiceId })
        .then(result => {
            this.paymentDetails = result.paymentDetails || [];
            this.paymentsTotal = result.paymentsTotal || 0;
            this.creditNotesTotal = result.creditNotesTotal || 0;
            this.combinedApplied = result.combinedApplied || 0;
        })
        .catch(error => {
            console.error('Error fetching payment details:', error);
        })
        .finally(() => {
            this.isLoadingModal = false;
        });
    }
    
    closePaymentModal() {
        this.showPaymentModal = false;
        this.selectedInvoiceId = null;
        this.paymentDetails = [];
        this.paymentsTotal = 0;
        this.creditNotesTotal = 0;
        this.combinedApplied = 0;
    }

    updateDisplayedRecords() {
        const startIndex = (this.currentPage - 1) * this.pageSize;
        const endIndex = startIndex + this.pageSize;
        this.invoiceDetails = this.allInvoiceDetails.slice(startIndex, endIndex);
    }

    // Pagination computed properties
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

    // Pagination handlers
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
        } else if (actionName === 'view_payments') {
            this.openPaymentModal(row.invoiceId, row.invoiceNumber);
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