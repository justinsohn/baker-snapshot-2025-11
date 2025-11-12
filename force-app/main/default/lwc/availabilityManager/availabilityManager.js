import { LightningElement, track, wire } from 'lwc';
// Import getFieldValue to safely access record data
import { getRecord, getFieldValue, updateRecord } from 'lightning/uiRecordApi';
import Id from '@salesforce/user/Id';
import WEEKLY_AVAILABILITY_FIELD from '@salesforce/schema/User.Weekly_Availability__c';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class AvailabilityManager extends LightningElement {
    @track currentAvailability;
    @track error;
    userId = Id;

    get availabilityOptions() {
        const baseOptions = [
            { label: 'Green - Available for new work', value: 'Green', className: 'radio-green' },
            { label: 'Yellow - Nearing capacity', value: 'Yellow', className: 'radio-yellow' },
            { label: 'Red - At capacity, no new work', value: 'Red', className: 'radio-red' },
        ];

        return baseOptions.map(option => ({
            ...option,
            checked: this.currentAvailability === option.value
        }));
    }

    @wire(getRecord, { recordId: '$userId', fields: [WEEKLY_AVAILABILITY_FIELD] })
    wiredUser({ error, data }) {
        if (data) {
            // Use getFieldValue to safely extract the value.
            // This prevents errors if the field isn't available.
            const availability = getFieldValue(data, WEEKLY_AVAILABILITY_FIELD);

            // If the value is null or undefined, default to 'Green'.
            this.currentAvailability = availability || 'Green';
            this.error = undefined;

        } else if (error) {
            this.error = 'Error retrieving user availability.';
            // Also set a default value on error to prevent the spinner from getting stuck.
            this.currentAvailability = 'Green';
        }
    }

    handleChange(event) {
        this.currentAvailability = event.target.value;
        this.updateUserAvailability();
    }

    updateUserAvailability() {
        const fields = {};
        fields.Id = this.userId;
        fields[WEEKLY_AVAILABILITY_FIELD.fieldApiName] = this.currentAvailability;

        const recordInput = { fields };

        updateRecord(recordInput)
            .then(() => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Success',
                        message: 'Availability updated successfully',
                        variant: 'success'
                    })
                );
            })
            .catch(error => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error updating availability',
                        message: error.body.message,
                        variant: 'error'
                    })
                );
                this.error = 'Error updating availability.';
            });
    }
}