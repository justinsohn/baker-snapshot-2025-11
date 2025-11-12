import { LightningElement, track, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex';
import getARAgingData from '@salesforce/apex/ARAgingController.getARAgingData';
import getInvoiceDetails from '@salesforce/apex/ARAgingController.getInvoiceDetails';
import getAvailableTeams from '@salesforce/apex/ARAgingController.getAvailableTeams';

const RECORDS_PER_PAGE = 25;

const COLUMNS = [
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
        label: 'Days Outstanding',
        fieldName: 'daysOutstanding',
        type: 'number'
    },
    {
        label: 'Balance',
        fieldName: 'balance',
        type: 'currency'
    },
    {
        type: 'action',
        typeAttributes: {
            rowActions: [
                { label: 'View Record', name: 'view_record' }
            ]
        }
    }
];

export default class ArAging extends NavigationMixin(LightningElement) {
    @track asOfDate = new Date().toISOString().split('T')[0];
    @track selectedTeam = 'All';
    @track agingData;
    @track showModal = false;
    @track modalData = [];
    @track modalTitle = '';
    @track isLoadingModal = false;
    @track error;
    @track isLoading = false;
    @track availableTeams = [];
    @track teamOptions = [];
    
    // Pagination properties
    @track currentPage = 1;
    @track totalRecords = 0;
    @track paginatedData = [];
    
    wiredAgingResult;
    wiredTeamsResult;
    columns = COLUMNS;

    @wire(getARAgingData, { asOfDate: '$asOfDate', teamFilter: '$selectedTeam' })
    wiredAging(result) {
        this.wiredAgingResult = result;
        this.isLoading = true;
        if (result.data) {
            this.agingData = result.data;
            this.error = undefined;
            this.isLoading = false;
        } else if (result.error) {
            this.error = result.error.body?.message || 'Error loading AR aging data';
            this.agingData = undefined;
            this.isLoading = false;
        }
    }

    @wire(getAvailableTeams, { asOfDate: '$asOfDate' })
    wiredTeams(result) {
        this.wiredTeamsResult = result;
        if (result.data) {
            this.availableTeams = result.data;
            this.teamOptions = result.data.map(team => ({
                label: team,
                value: team
            }));
            this.error = undefined;
        } else if (result.error) {
            this.error = result.error.body?.message || 'Error loading available teams';
        }
    }

    // Computed properties for truncated values (not rounded)
    get aging30DaysTruncated() {
        return Math.floor(this.agingData?.aging30Days || 0);
    }

    get aging60DaysTruncated() {
        return Math.floor(this.agingData?.aging60Days || 0);
    }

    get aging90DaysTruncated() {
        return Math.floor(this.agingData?.aging90Days || 0);
    }

    get aging91PlusDaysTruncated() {
        return Math.floor(this.agingData?.aging91PlusDays || 0);
    }

    get formatted30DaysAmount() {
        return this.formatCurrency(this.agingData?.aging30Days || 0);
    }

    get formatted60DaysAmount() {
        return this.formatCurrency(this.agingData?.aging60Days || 0);
    }

    get formatted90DaysAmount() {
        return this.formatCurrency(this.agingData?.aging90Days || 0);
    }

    get formatted91PlusDaysAmount() {
        return this.formatCurrency(this.agingData?.aging91PlusDays || 0);
    }

    get totalPages() {
        return Math.ceil(this.totalRecords / RECORDS_PER_PAGE);
    }

    get isFirstPage() {
        return this.currentPage === 1;
    }

    get isLastPage() {
        return this.currentPage === this.totalPages;
    }

    get showPagination() {
        return this.totalRecords > RECORDS_PER_PAGE;
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
        const startRecord = (this.currentPage - 1) * RECORDS_PER_PAGE + 1;
        const endRecord = Math.min(this.currentPage * RECORDS_PER_PAGE, this.totalRecords);
        return `${startRecord}-${endRecord} of ${this.totalRecords}`;
    }

    formatCurrency(amount) {
        if (amount == null || isNaN(amount)) {
            return '$0';
        }
        return new Intl.NumberFormat('en-US', {
            style: 'currency',
            currency: 'USD',
            minimumFractionDigits: 0,
            maximumFractionDigits: 0
        }).format(Math.floor(amount));
    }

    handleDateChange(event) {
        this.asOfDate = event.target.value;
        this.isLoading = true;
        refreshApex(this.wiredAgingResult);
        refreshApex(this.wiredTeamsResult);
    }

    handleTeamChange(event) {
        this.selectedTeam = event.target.value;
        this.isLoading = true;
        refreshApex(this.wiredAgingResult);
    }

    handle30DaysClick() {
        this.showInvoiceDetails('30', '0-30 Days Outstanding');
    }

    handle60DaysClick() {
        this.showInvoiceDetails('60', '0-60 Days Outstanding');
    }

    handle90DaysClick() {
        this.showInvoiceDetails('90', '0-90 Days Outstanding');
    }

    handle91PlusDaysClick() {
        this.showInvoiceDetails('91+', '91+ Days Outstanding');
    }

    async showInvoiceDetails(agingBucket, title) {
        this.modalTitle = title;
        this.showModal = true;
        this.isLoadingModal = true;
        this.modalData = [];
        this.currentPage = 1;

        try {
            const result = await getInvoiceDetails({ 
                asOfDate: this.asOfDate, 
                agingBucket: agingBucket,
                teamFilter: this.selectedTeam
            });
            
            this.modalData = result.map(invoice => ({
                ...invoice,
                invoiceUrl: `/${invoice.invoiceId}`
            }));
            
            this.totalRecords = this.modalData.length;
            this.updatePaginatedData();
            this.isLoadingModal = false;
            
        } catch (error) {
            console.error('Error loading invoice details:', error);
            this.error = error.body?.message || 'Error loading invoice details';
            this.isLoadingModal = false;
        }
    }

    updatePaginatedData() {
        const startIndex = (this.currentPage - 1) * RECORDS_PER_PAGE;
        const endIndex = startIndex + RECORDS_PER_PAGE;
        this.paginatedData = this.modalData.slice(startIndex, endIndex);
    }

    handlePrevious() {
        if (this.currentPage > 1) {
            this.currentPage--;
            this.updatePaginatedData();
        }
    }

    handleNext() {
        if (this.currentPage < this.totalPages) {
            this.currentPage++;
            this.updatePaginatedData();
        }
    }

    handlePreviousPage() {
        if (this.hasPreviousPage) {
            this.currentPage--;
            this.updatePaginatedData();
        }
    }

    handleNextPage() {
        if (this.hasNextPage) {
            this.currentPage++;
            this.updatePaginatedData();
        }
    }

    handleFirstPage() {
        this.currentPage = 1;
        this.updatePaginatedData();
    }

    handleLastPage() {
        this.currentPage = this.totalPages;
        this.updatePaginatedData();
    }

    handleRowAction(event) {
        const action = event.detail.action;
        const row = event.detail.row;
        
        if (action.name === 'view_record') {
            this.navigateToRecord(row.invoiceId);
        }
    }

    navigateToRecord(recordId) {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: recordId,
                actionName: 'view'
            }
        });
    }

    closeModal() {
        this.showModal = false;
        this.modalData = [];
        this.modalTitle = '';
        this.isLoadingModal = false;
        this.currentPage = 1;
        this.totalRecords = 0;
        this.paginatedData = [];
    }

    handleDownloadCSV() {
        console.log('CSV Download clicked');
        console.log('modalData:', this.modalData);
        
        if (!this.modalData || this.modalData.length === 0) {
            console.log('No data available for download');
            return;
        }

        // CSV headers
        const headers = [
            'Invoice Number',
            'Date', 
            'Status',
            'Team',
            'Matter',
            'Days Outstanding',
            'Balance'
        ];

        // Convert data to CSV format
        let csvContent = headers.join(',') + '\n';
        
        this.modalData.forEach(invoice => {
            const row = [
                `"${invoice.invoiceNumber || ''}"`,
                `"${invoice.invoiceDate || ''}"`,
                `"${invoice.status || ''}"`,
                `"${invoice.teamMatter || ''}"`,
                `"${invoice.matter || ''}"`,
                `"${invoice.daysOutstanding || '0'}"`,
                `"${invoice.balance || '0'}"`
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