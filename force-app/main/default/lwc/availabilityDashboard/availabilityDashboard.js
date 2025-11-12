import { LightningElement, wire, track } from 'lwc';
import getActiveUsersByPracticeArea from '@salesforce/apex/UserAvailabilityController.getActiveUsersByPracticeArea';
import getActiveUsersRefresh from '@salesforce/apex/UserAvailabilityController.getActiveUsersRefresh';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class AvailabilityDashboard extends LightningElement {
    @track users = [];
    @track isLoading = false;
    error;

    getBadgeClass(availability) {
        const baseClass = 'slds-badge slds-text-heading_small';
        switch (availability) {
            case 'Green':
                return `${baseClass} badge-green`;
            case 'Yellow':
                return `${baseClass} badge-yellow`;
            case 'Red':
                return `${baseClass} badge-red`;
            default:
                return `${baseClass} slds-badge_inverse`;
        }
    }

    @wire(getActiveUsersByPracticeArea)
    wiredUsers({ error, data }) {
        if (data) {
            this.processUserData(data);
            this.error = undefined;
        } else if (error) {
            this.error = error;
            this.users = [];
        }
    }

    processUserData(data) {
        this.users = data.map(user => {
            const availability = user.Weekly_Availability__c || 'Not Set';
            return {
                ...user,
                fullName: `${user.FirstName} ${user.LastName}`,
                weekly_availability__c: availability,
                badgeClass: this.getBadgeClass(availability),
                practiceAreaDisplay: user.Practice_Area__c || 'Not Set'
            };
        });
    }

    handleRefresh() {
        this.isLoading = true;
        getActiveUsersRefresh()
            .then(data => {
                this.processUserData(data);
                this.error = undefined;
                this.isLoading = false;
                
                // Show success toast
                const toastEvent = new ShowToastEvent({
                    title: 'Success',
                    message: 'Availability dashboard refreshed',
                    variant: 'success'
                });
                this.dispatchEvent(toastEvent);
            })
            .catch(error => {
                this.error = error;
                this.isLoading = false;
                
                // Show error toast
                const toastEvent = new ShowToastEvent({
                    title: 'Error',
                    message: 'Failed to refresh dashboard',
                    variant: 'error'
                });
                this.dispatchEvent(toastEvent);
            });
    }

    get hasUsers() {
        return this.users && this.users.length > 0;
    }
}