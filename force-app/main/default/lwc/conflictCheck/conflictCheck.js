import { LightningElement, track, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import findConflicts from '@salesforce/apex/ConflictCheckController.findConflicts';
import saveConflictCheck from '@salesforce/apex/ConflictCheckController.saveConflictCheck';
import getConflictCheckHistory from '@salesforce/apex/ConflictCheckController.getConflictCheckHistory';
import searchLeads from '@salesforce/apex/ConflictCheckController.searchLeads';

// Define columns for the lightning-datatable
const COLUMNS = [
    { label: 'Name', fieldName: 'nameUrl', type: 'url', typeAttributes: { label: { fieldName: 'name' }, target: '_blank' } },
    { label: 'Type', fieldName: 'recordType', type: 'text', initialWidth: 100 },
    { label: 'Risk', fieldName: 'riskLevel', type: 'text', initialWidth: 90, cellAttributes: {
        class: { fieldName: 'riskLevelClass' }
    }},
    { label: 'Score', fieldName: 'riskScore', type: 'number', initialWidth: 100 },
    { label: 'Match Reason', fieldName: 'matchReason', type: 'text' },
    { label: 'Email', fieldName: 'email', type: 'email', initialWidth: 180 },
    { label: 'Phone', fieldName: 'phone', type: 'phone', initialWidth: 130 }
];

export default class ConflictCheck extends LightningElement {
    @api recordId;

    @track name = '';
    @track email = '';
    @track phone = '';
    @track businessName = '';
    @track results;
    @track error;
    @track isLoading = false;
    @track conflictCheckHistory = [];
    @track conflictCheckHistoryText = null;

    // Modal for viewing historical conflict check details
    @track showModal = false;
    @track selectedHistoryLog = null;
    @track modalMatches = [];
    @track isShowingCurrentResults = false;

    // Lead search functionality for platform users
    @track selectedLeadId = '';
    @track selectedLeadName = '';
    @track leadSearchTerm = '';
    @track leadSearchResults = [];
    @track showLeadSearch = false;
    @track isLeadSearchLoading = false;

    columns = COLUMNS;

    connectedCallback() {
        // If no recordId is provided, show lead search for platform users
        if (!this.recordId) {
            this.showLeadSearch = true;
        } else {
            this.selectedLeadId = this.recordId;
            this.loadConflictCheckHistory();
        }
    }

    loadConflictCheckHistory() {
        const leadId = this.selectedLeadId || this.recordId;
        if (leadId) {
            getConflictCheckHistory({ leadId: leadId })
                .then(data => {
                    // Handle both old string format and new structured format
                    if (typeof data === 'string') {
                        // Old format - display as text (backward compatibility)
                        this.conflictCheckHistory = null;
                        this.conflictCheckHistoryText = data;
                    } else if (Array.isArray(data)) {
                        // New format - structured data with formatted dates
                        this.conflictCheckHistory = (data || []).map(log => ({
                            ...log,
                            formattedDate: this.formatDateTimeAmerican(log.performedDate)
                        }));
                        this.conflictCheckHistoryText = null;
                    } else {
                        this.conflictCheckHistory = [];
                        this.conflictCheckHistoryText = null;
                    }
                })
                .catch(error => {
                    console.error('Error loading conflict check history:', error);
                    this.conflictCheckHistory = [];
                    this.conflictCheckHistoryText = null;
                });
        }
    }

    /**
     * Formats a DateTime in American format (MM/DD/YYYY hh:mm AM/PM)
     * @param {DateTime} dateTime - DateTime value from Salesforce
     * @returns {String} Formatted date string
     */
    formatDateTimeAmerican(dateTime) {
        if (!dateTime) return '';

        const date = new Date(dateTime);
        const month = String(date.getMonth() + 1).padStart(2, '0');
        const day = String(date.getDate()).padStart(2, '0');
        const year = date.getFullYear();

        let hours = date.getHours();
        const minutes = String(date.getMinutes()).padStart(2, '0');
        const ampm = hours >= 12 ? 'PM' : 'AM';
        hours = hours % 12;
        hours = hours ? hours : 12; // the hour '0' should be '12'
        const hoursStr = String(hours).padStart(2, '0');

        return `${month}/${day}/${year} ${hoursStr}:${minutes} ${ampm}`;
    }

    handleNameChange(event) {
        this.name = event.target.value;
    }

    handleEmailChange(event) {
        this.email = event.target.value;
    }

    handlePhoneChange(event) {
        this.phone = event.target.value;
    }

    handleBusinessNameChange(event) {
        this.businessName = event.target.value;
    }

    get isSearchDisabled() {
        const hasSearchTerms = this.name || this.email || this.phone || this.businessName;
        const hasSelectedLead = this.selectedLeadId || this.recordId;
        return !hasSearchTerms || !hasSelectedLead;
    }

    get hasResults() {
        return this.results && this.results.length > 0;
    }

    get hasConflictCheckHistory() {
        return (this.conflictCheckHistory && this.conflictCheckHistory.length > 0) ||
               (this.conflictCheckHistoryText && this.conflictCheckHistoryText.trim().length > 0);
    }

    get showOldFormatHistory() {
        return this.conflictCheckHistoryText && this.conflictCheckHistoryText.trim().length > 0;
    }

    get showNewFormatHistory() {
        return this.conflictCheckHistory && this.conflictCheckHistory.length > 0;
    }

    get showResults() {
        return this.results !== undefined;
    }

    get isSearchReady() {
        return this.selectedLeadId || this.recordId;
    }

    get showConflictCheckForm() {
        return !this.showLeadSearch || this.selectedLeadId;
    }

    get showSelectedLeadSection() {
        // Only show selected lead section when not on a Lead record page (i.e., when recordId is not provided)
        return this.selectedLeadId && !this.recordId;
    }

    get currentResultsHighestRisk() {
        if (!this.results || this.results.length === 0) return null;
        return Math.max(...this.results.map(r => r.riskScore || 0));
    }

    get conflictCountText() {
        if (!this.results) return '';
        const count = this.results.length;
        return `${count} Potential Conflict${count > 1 ? 's' : ''} Found`;
    }

    handleSearch() {
        this.isLoading = true;
        this.results = undefined;
        this.error = undefined;

        findConflicts({
            name: this.name,
            email: this.email,
            phone: this.phone,
            businessName: this.businessName
        })
        .then(data => {
            console.log('Raw Apex response:', JSON.stringify(data, null, 2));

            // Data is already in the correct format from Apex (ConflictMatch objects)
            // Just need to add CSS class for risk level coloring
            this.results = data.map(record => {
                const riskLevelClass = this.getRiskLevelClass(record.riskLevel);
                return {
                    ...record,
                    riskLevelClass: riskLevelClass
                };
            });

            // Sort by risk score descending
            this.results.sort((a, b) => b.riskScore - a.riskScore);

            console.log('Final results for datatable:', this.results);
            this.isLoading = false;

            // Save the conflict check search parameters to the Lead record
            this.saveConflictCheckToLead();
        })
        .catch(error => {
            this.isLoading = false;
            this.error = error;
            
            console.error('Apex call error:', error);
            
            let errorMessage = 'An unknown error occurred.';
            if (error) {
                if (error.body) {
                    if (Array.isArray(error.body)) {
                        errorMessage = error.body.map(e => e.message).join(', ');
                    } else if (error.body.message) {
                        errorMessage = error.body.message;
                    } else if (typeof error.body === 'string') {
                        errorMessage = error.body;
                    }
                } else if (error.message) {
                    errorMessage = error.message;
                }
            }
            
            const toastEvent = new ShowToastEvent({
                title: 'Error Performing Conflict Check',
                message: errorMessage,
                variant: 'error',
                mode: 'sticky' 
            });
            this.dispatchEvent(toastEvent);
        });
    }

    saveConflictCheckToLead() {
        const leadId = this.selectedLeadId || this.recordId;
        if (leadId) {
            saveConflictCheck({
                leadId: leadId,
                name: this.name,
                email: this.email,
                phone: this.phone,
                businessName: this.businessName,
                matches: this.results || []
            })
            .then(() => {
                // Refresh the conflict check history after saving
                this.loadConflictCheckHistory();
            })
            .catch(error => {
                console.error('Error saving conflict check:', error);
                // Don't show error toast for this as it's not critical to the main functionality
            });
        }
    }

    /**
     * Returns CSS class for risk level color coding
     * @param {String} riskLevel - Risk level (Critical, High, Medium, Low)
     * @returns {String} CSS class name
     */
    getRiskLevelClass(riskLevel) {
        switch(riskLevel) {
            case 'Critical':
                return 'slds-text-color_error slds-text-title_bold';
            case 'High':
                return 'slds-text-color_warning slds-text-title_bold';
            case 'Medium':
                return 'slds-text-color_default';
            case 'Low':
                return 'slds-text-color_weak';
            default:
                return '';
        }
    }

    // Lead search methods for platform users
    handleLeadSearchTermChange(event) {
        this.leadSearchTerm = event.target.value;
    }

    handleLeadSearch() {
        if (!this.leadSearchTerm || this.leadSearchTerm.length < 2) {
            return;
        }

        this.isLeadSearchLoading = true;
        searchLeads({ searchTerm: this.leadSearchTerm })
            .then(data => {
                this.leadSearchResults = data || [];
                this.isLeadSearchLoading = false;
            })
            .catch(error => {
                console.error('Error searching leads:', error);
                this.isLeadSearchLoading = false;
                const toastEvent = new ShowToastEvent({
                    title: 'Error Searching Leads',
                    message: 'Unable to search for leads. Please try again.',
                    variant: 'error'
                });
                this.dispatchEvent(toastEvent);
            });
    }

    handleLeadSelect(event) {
        const selectedLeadId = event.currentTarget.dataset.leadId;
        const selectedLead = this.leadSearchResults.find(lead => lead.Id === selectedLeadId);
        
        if (selectedLead) {
            this.selectedLeadId = selectedLeadId;
            this.selectedLeadName = `${selectedLead.FirstName || ''} ${selectedLead.LastName || ''}`.trim();
            this.showLeadSearch = false;
            this.leadSearchResults = [];
            this.leadSearchTerm = '';
            
            // Load conflict check history for the selected lead
            this.loadConflictCheckHistory();
        }
    }

    handleChangeLead() {
        this.selectedLeadId = '';
        this.selectedLeadName = '';
        this.showLeadSearch = true;
        this.conflictCheckHistory = '';
        this.results = undefined;
        this.error = undefined;

        // Clear search fields
        this.name = '';
        this.email = '';
        this.phone = '';
        this.businessName = '';
    }

    handleRunNewCheck() {
        // Clear the results
        this.results = undefined;
        this.error = undefined;

        // Clear the search fields
        this.name = '';
        this.email = '';
        this.phone = '';
        this.businessName = '';

        // Optionally refresh the conflict check history
        this.loadConflictCheckHistory();
    }

    // Modal handlers for current and historical conflict check viewing
    handleCurrentResultsClick() {
        this.isShowingCurrentResults = true;
        this.selectedHistoryLog = null;
        this.modalMatches = this.results || [];
        this.showModal = true;
    }

    handleHistoryTileClick(event) {
        const logId = event.currentTarget.dataset.logId;
        const log = this.conflictCheckHistory.find(l => l.id === logId);

        if (log) {
            this.isShowingCurrentResults = false;
            this.selectedHistoryLog = log;

            // Transform matches to datatable format
            this.modalMatches = (log.matches || []).map(match => {
                const riskLevelClass = this.getRiskLevelClass(match.riskLevel);
                return {
                    ...match,
                    nameUrl: match.recordUrl,
                    name: match.recordName,
                    recordType: match.recordType,
                    riskLevel: match.riskLevel,
                    riskScore: match.riskScore,
                    matchReason: match.matchReason,
                    email: '', // Not available in saved matches
                    phone: '', // Not available in saved matches
                    riskLevelClass: riskLevelClass
                };
            });

            this.showModal = true;
        }
    }

    handleCloseModal() {
        this.showModal = false;
        this.selectedHistoryLog = null;
        this.modalMatches = [];
        this.isShowingCurrentResults = false;
    }

    get modalTitle() {
        if (this.isShowingCurrentResults) {
            // For current results
            const criteria = [];
            if (this.name) criteria.push(this.name);
            if (this.email) criteria.push(this.email);
            if (this.businessName) criteria.push(this.businessName);
            return `Current Conflict Check Results - ${criteria.join(', ')}`;
        } else if (this.selectedHistoryLog) {
            // For historical results
            const date = this.selectedHistoryLog.formattedDate || '';
            const criteria = [];
            if (this.selectedHistoryLog.searchName) criteria.push(this.selectedHistoryLog.searchName);
            if (this.selectedHistoryLog.searchEmail) criteria.push(this.selectedHistoryLog.searchEmail);
            if (this.selectedHistoryLog.searchBusinessName) criteria.push(this.selectedHistoryLog.searchBusinessName);
            return `Conflict Check Results - ${date} - ${criteria.join(', ')}`;
        }
        return '';
    }
}