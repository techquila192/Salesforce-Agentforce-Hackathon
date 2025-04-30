public with sharing class GetInventoryAndBookingItems {

    public class Request {
        @InvocableVariable(required=true)
        public Id bookingId;
    }

    public class Response {
        @InvocableVariable
        public String bookingItems;

        @InvocableVariable
        public String inventoryItems;
    }

    @InvocableMethod(label='Get Inventory and Booking Items' description='Returns the Items__c fields from Booking and corresponding Inventory')
    public static List<Response> getItems(List<Request> requests) {
        List<Response> results = new List<Response>();

        for (Request req : requests) {
            Response res = new Response();

            // Get the booking
            Booking__c booking = [
                SELECT Id, Items__c, Venue__c
                FROM Booking__c
                WHERE Id = :req.bookingId
                LIMIT 1
            ];

            res.bookingItems = booking.Items__c;

            // Get the inventory record for the same venue
            Inventory__c inv = [
                SELECT Id, Items__c
                FROM Inventory__c
                WHERE Venue__c = :booking.Venue__c
                LIMIT 1
            ];

            res.inventoryItems = inv.Items__c;

            results.add(res);
        }

        return results;
    }
}