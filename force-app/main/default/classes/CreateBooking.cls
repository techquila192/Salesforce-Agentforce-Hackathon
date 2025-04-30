public with sharing class CreateBooking {
    
    @InvocableMethod(label='Create Booking')
    public static List<BookingOutput> create(List<BookingInput> inputs) {
        List<BookingOutput>  outputs = new List<BookingOutput>();
        for (BookingInput input : inputs) {
            // 1. Fetch Venue and get Event Manager Email
            Venue__c venue = [
                SELECT Id, Name, City__c, Capacity__c, Point_Of_Contact__c
                FROM Venue__c
                WHERE Id = :input.venueId
                LIMIT 1
            ];

            String managerId = venue.Point_Of_Contact__c;
            if (String.isBlank(managerId)) {
                throw new AuraHandledException('Event manager Id (Point_Of_Contact__c) is missing for the venue.');
            }

            // 2. Lookup Event Manager (Custom Object) by Email
            Event_Manager__c eventManager = [
                SELECT Id, Name, Email__c
                FROM Event_Manager__c
                WHERE Id = :managerId
                LIMIT 1
            ];

            String managerEmail = eventManager.Email__c;

            // 3. Create Booking Record (include Event_Manager__c lookup)
            Booking__c booking = new Booking__c(
                Contact__c = input.contactId,
                Date__c = input.eventDate,
                Event_Type__c = input.eventType,
                Guest_Count__c = input.guestCount,
                Venue__c = venue.Id,
                Items__c = input.items,
                Event_Manager__c = eventManager.Id
            );
            insert booking;

            // 4. Slack Setup
            // String slackUserId = SlackUtils.getSlackUserIdByEmail(managerEmail);
            // String channelName = 'booking-' + booking.Name.toLowerCase().replaceAll('[^a-z0-9-]', '-');
            // String channelId = SlackUtils.createPrivateChannel(channelName);

            // if (slackUserId != null && channelId != null) {
            //     SlackUtils.addUserToChannel(channelId, slackUserId);
            // }

            // // 5. Store Slack channel ID
            // booking.Channel_Id__c = channelId;
            // update booking;

            
            BookingOutput output = new BookingOutput();
            output.success = true;
            outputs.add(output);
        }
        return outputs;
    }

    public class BookingInput {
        @InvocableVariable(required=true) public Id contactId;
        @InvocableVariable(required=true) public Date eventDate;
        @InvocableVariable(required=true) public String eventType;
        @InvocableVariable(required=true) public Integer guestCount;
        @InvocableVariable(required=true) public String items;
        @InvocableVariable(required=true) public Id venueId;
    }

    public class BookingOutput{
        @InvocableVariable public boolean success;
    }
}
