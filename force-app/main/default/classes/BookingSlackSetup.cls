public with sharing class BookingSlackSetup {
    public class Input {
        @InvocableVariable(required=true)
        public Id bookingId;
    }

    @InvocableMethod(label='Setup Slack Channel for Booking')
    public static void run(List<Input> inputs) {
        for (Input input : inputs) {
            Booking__c bookingRecord = [
                SELECT Id, Name, Event_Manager__r.Email__c
                FROM Booking__c
                WHERE Id = :input.bookingId
                LIMIT 1
            ];

            String channelName = 'event-' + bookingRecord.Name.toLowerCase().replaceAll('[^a-z0-9-]', '-');
            String slackUserId = SlackUtils.getSlackUserIdByEmail(bookingRecord.Event_Manager__r.Email__c);
            String channelId = SlackUtils.createPrivateChannel(channelName);

            if (slackUserId != null && channelId != null) {
                SlackUtils.addUserToChannel(channelId, slackUserId);
            }

            bookingRecord.Channel_Id__c = channelId;
            update bookingRecord;
        }
    }
}
