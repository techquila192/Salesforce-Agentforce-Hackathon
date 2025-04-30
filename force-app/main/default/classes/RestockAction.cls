public with sharing class RestockAction {

    public class Request {
        @InvocableVariable(required=true)
        public Id bookingId;
    }

    // public class Response {

    //     @InvocableVariable
    //     public boolean success;

    // }

    @InvocableMethod(label='Find Insufficient Items' description='Returns items needed for a booking and the current inventory at its venue')
    public static void fetchItems(List<Request> requests) {
        //List<Response> results = new List<Response>();

        for (Request req : requests) {

            // Response resp = new Response();
            // resp.success = false;
            Booking__c booking = [
                SELECT Id, Contact__r.Name, Venue__r.Address__c, Venue__r.City__c, Items__c, Date__c, Event_Type__c, Guest_Count__c, Channel_Id__c
                FROM Booking__c
                WHERE Id = :req.bookingId
                LIMIT 1
            ];
            
            String channelId = booking.Channel_Id__c;

            String sessionId = AgentApiUtils.startAgentSession();
            String checkInventoryMessage = 'Compare the booking items and inventory levels for booking id  ' + booking.Id;
            String agentReply = AgentApiUtils.sendMessageToAgent(sessionId, checkInventoryMessage);


            Map<String, Object> raw = (Map<String, Object>) JSON.deserializeUntyped(agentReply);

            List<Object> buttonsList = (List<Object>) raw.get('buttons');
            List<Object> itemsJson = (List<Object>) raw.get('items');

            List<Map<String, Object>> items = new List<Map<String, Object>>();

            for (Object o : (List<Object>) itemsJson) {
                if (o instanceof Map<String, Object>) {
                    items.add((Map<String, Object>) o);
                }
            }

            String missingItemsListMessage = prepareMissingItemsList(items);
            List<Object> blocks = wrapButtonsIntoSingleBlock(buttonsList, 'Choose category to restock');

            String bookingSummary = '*📅 Booking Details:*\n\n';
            bookingSummary += '*Contact Name:* ' + booking.Contact__r.Name + '\n';
            bookingSummary += '*Event Type:* ' + booking.Event_Type__c + '\n';
            bookingSummary += '*Date:* ' + String.valueOf(booking.Date__c) + '\n';
            bookingSummary += '*Guest Count:* ' + String.valueOf(booking.Guest_Count__c) + '\n';
            bookingSummary += '*Venue:* ' + booking.Venue__r.Address__c + ', ' + booking.Venue__r.City__c + '\n';
            bookingSummary += '*Items Requested by Customer:* ' + booking.Items__c + '\n';

            SlackUtils.sendMessage(channelId, bookingSummary);
                  
            SlackUtils.sendMessage(channelId, missingItemsListMessage);

            SlackUtils.sendBlockMessage(channelId, blocks);

            upsert new Agent_Session__c(
                Session_Id__c = sessionId,
                Slack_Id__c = channelId
            );


            //SlackUtils.sendMessage(channelId, agentReply);
            // resp.success = true;
            // results.add(resp);
        }

        // return results;
    }

    public static String prepareMissingItemsList(List<Map<String, Object>> items){

        Map<String, List<String>> categoryMap = new Map<String, List<String>>();

        for (Map<String, Object> item : items) {
            String category = (String) item.get('category');
            String name = (String) item.get('item');
            Integer quantity = (Integer) item.get('quantity');

            String formattedItem = '- ' + name + ' (Qty: ' + quantity + ')';

            if (!categoryMap.containsKey(category)) {
                categoryMap.put(category, new List<String>());
            }

            categoryMap.get(category).add(formattedItem);
        }

        // Build the Slack markdown-formatted message
        String message = '*🚨 Missing Items by Category:*\n\n';

        for (String category : categoryMap.keySet()) {
            message += '*' + category.capitalize() + '*\n';
            for (String itemLine : categoryMap.get(category)) {
                message += itemLine + '\n';
            }
            message += '\n';
        }

        return message;
    }

    public static List<Object> wrapButtonsIntoSingleBlock(List<Object> buttons, String headingText) {
        List<Object> blocks = new List<Object>();

        // Optional heading block
        if (String.isNotBlank(headingText)) {
            blocks.add(new Map<String, Object>{
                'type' => 'section',
                'text' => new Map<String, Object>{
                    'type' => 'mrkdwn',
                    'text' => '*' + headingText + '*'
                }
            });
        }

        // Single actions block with all buttons
        blocks.add(new Map<String, Object>{
            'type' => 'actions',
            'elements' => buttons
        });

        return blocks;
    }
}
