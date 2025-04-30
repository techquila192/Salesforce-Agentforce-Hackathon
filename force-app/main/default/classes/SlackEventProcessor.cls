public with sharing class SlackEventProcessor {
    @future(callout=true)
    public static void handleSlackEventAsync(String body){
        Map<String,Object> payload = (Map<String,Object>)JSON.deserializeUntyped(body);
        Map<String,Object> event = (Map<String,Object>)payload.get('event');
        String eventType = (String)event.get('type');
        if(eventType != 'message' || event.containsKey('bot_id')){
        return;
        }
        if(event.containsKey('subtype'))
        {
            String eventSubtype = (String) event.get('subtype');
            if(eventSubtype == 'channel_join')
            return;
        }
        if(event.containsKey('thread_ts')){
            handleThreadMessage(event);
        }
        else {
            handleChannelMessage(event);
        }
    }

    private static void handleChannelMessage(Map<String, Object> event){
        String channelId = (String) event.get('channel');
        String userMessage = (String) event.get('text');
        Agent_Session__c agentSession = [SELECT Id, Session_Id__c, Slack_Id__c FROM Agent_Session__c WHERE Slack_Id__c =: channelId LIMIT 1];
        String sessionId = (String) agentSession.Session_Id__c;
        String agentReply = AgentApiUtils.sendMessageToAgent(sessionId, userMessage);
        Map<String, Object> raw = (Map<String, Object>) JSON.deserializeUntyped(agentReply);

        List<Object> buttonsList = (List<Object>) raw.get('buttons');
        List<Object> itemsJson = (List<Object>) raw.get('items');
        List<Map<String, Object>> items = new List<Map<String, Object>>();

        for (Object o : (List<Object>) itemsJson) {
            if (o instanceof Map<String, Object>) {
                items.add((Map<String, Object>) o);
            }
        }

        String missingItemsListMessage = RestockAction.prepareMissingItemsList(items);
        List<Object> blocks = RestockAction.wrapButtonsIntoSingleBlock(buttonsList, 'Choose category to restock');

        SlackUtils.sendMessage(channelId, missingItemsListMessage);
        SlackUtils.sendBlockMessage(channelId, blocks);
        
    }

    private static void handleThreadMessage(Map<String, Object> event){
        String channelId = (String) event.get('channel');
        String userMessage = (String) event.get('text');
        String threadTs = (String) event.get('thread_ts');
        Agent_Session__c agentSession = [SELECT Id, Session_Id__c, Slack_Id__c FROM Agent_Session__c WHERE Slack_Id__c LIKE :threadTs + '%' LIMIT 1];
        String sessionId = (String) agentSession.Session_Id__c;
        String agentReply = AgentApiUtils.sendMessageToAgent(sessionId, userMessage);
        List<Object> blocks = buildDraftMessageWithSendButton(agentReply, sessionId);
        SlackUtils.sendBlocksThreadMessage(channelId, threadTs, blocks);

    }

    public static List<Object> buildDraftMessageWithSendButton(String draftText, String sessionId) {
        List<Object> blocks = new List<Object>();

        // Section block with the draft message
        blocks.add(new Map<String, Object>{
            'type' => 'section',
            'text' => new Map<String, Object>{
                'type' => 'mrkdwn',
                'text' => draftText
            }
        });

        // Divider for visual clarity
        blocks.add(new Map<String, Object>{ 'type' => 'divider' });

        // Action block with the Send button
        blocks.add(new Map<String, Object>{
            'type' => 'actions',
            'elements' => new List<Object>{
                new Map<String, Object>{
                    'type' => 'button',
                    'text' => new Map<String, Object>{
                        'type' => 'plain_text',
                        'text' => 'Send to Vendor',
                        'emoji' => true
                    },
                    'value' => sessionId,
                    'action_id' => 'send_message_to_vendor',
                    'style' => 'primary'
                }
            }
        });

        return blocks;
    }
}