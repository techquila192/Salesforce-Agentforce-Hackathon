import { LightningElement, wire } from 'lwc';
import Id from '@salesforce/user/Id';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import CONTACT_ID from '@salesforce/schema/User.ContactId';

export default class UserInfoEmitter extends LightningElement {
    @wire(getRecord, { recordId: Id, fields: [CONTACT_ID] })
    wiredUser({ error, data }) {
        if (data) {
            const contactId = getFieldValue(data, CONTACT_ID);
            // Fire the event on the global window object
            const event = new CustomEvent('userInfo', {
                detail: { contactId },
                bubbles: true,
                composed: true
            });
            this.dispatchEvent(event);
            window.dispatchEvent(event); // In case you're listening from global scripts
        } else if (error) {
            console.error('Error fetching user ContactId:', error);
        }
    }
}
