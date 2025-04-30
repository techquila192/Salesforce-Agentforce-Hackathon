import { LightningElement, wire } from 'lwc';
import { getRecord } from 'lightning/uiRecordApi';
import NAME_FIELD from '@salesforce/schema/User.Name';
import ID from '@salesforce/user/Id';

export default class UserAvatar extends LightningElement {
  userName;
  initials = '';

  @wire(getRecord, { recordId: ID, fields: [NAME_FIELD] })
  wiredUser({ error, data }) {
    if (data) {
      this.userName = data.fields.Name.value;
      this.initials = this.userName
        .split(' ')
        .map(n => n[0])
        .join('');
    } else if (error) {
      console.error('Error loading user info:', error);
    }
  }
}
