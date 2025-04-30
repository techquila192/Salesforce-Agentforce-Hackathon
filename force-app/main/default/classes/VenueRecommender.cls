public with sharing class VenueRecommender {
    public VenueRecommender() {

    }
    public class VenueInput {
        @InvocableVariable public String city;
        @InvocableVariable public Integer guestCount;
        @InvocableVariable public Date eventDate;
    }

    public class VenueRecord {
        @InvocableVariable public Id venueId;
        @InvocableVariable public String city;
        @InvocableVariable public Integer capacity;
        @InvocableVariable public String address;
    }

    public class VenueOutput {
        @InvocableVariable public List<VenueRecord> venues;
    }

    @InvocableMethod(label='Recommend Venues')
    public static List<VenueOutput> recommend(List<VenueInput> inputs) {
        List<VenueOutput> recommendations = new List<VenueOutput>();
        List<VenueRecord> venueRecords = new List<VenueRecord>();
        if (inputs == null || inputs.isEmpty()) return recommendations;

        VenueInput filter = inputs[0];

        String filterCity = filter.city;
        Integer filterGuestCount = filter.guestCount;
        Date filterEventDate = filter.eventDate;
        String query = 'SELECT Id, Name, City__c, Capacity__c, Address__c FROM Venue__c WHERE Id != null';
        if (filter.city != null) {
            query += ' AND City__c = :filterCity';
        }
        if (filter.guestCount != null) {
            query += ' AND Capacity__c >= :filterGuestCount';
        }

        List<Venue__c> venues = Database.query(query);

        Set<Id> bookedVenueIds = new Set<Id>();
        if (filter.eventDate != null) {
            for (Booking__c booking : [
                SELECT Venue__c FROM Booking__c
                WHERE Date__c = :filterEventDate
            ]) {
                bookedVenueIds.add(booking.Venue__c);
            }
        }

        for (Venue__c venue : venues) {
            if (filter.eventDate != null && bookedVenueIds.contains(venue.Id)) continue;

            VenueRecord record = new VenueRecord();
            record.venueId = venue.Id;
            record.city = venue.City__c;
            record.capacity = venue.Capacity__c != null ? venue.Capacity__c.intValue() : null;
            record.address = venue.Address__c;

            venueRecords.add(record);
        }
        VenueOutput output = new VenueOutput();
        output.venues = venueRecords;
        recommendations.add(output);
        System.debug(recommendations);
        return recommendations;
    }
}