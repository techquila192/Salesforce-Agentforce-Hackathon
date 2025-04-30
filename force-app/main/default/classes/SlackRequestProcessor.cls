public with sharing class SlackRequestProcessor {
    @future(callout=true)
    public static void handleSlackInteractionAsync(String body){
        String rawPayload = extractPayloadFromForm(body);
        if (String.isBlank(rawPayload)) return;

        Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(rawPayload);
        String type = (String) payload.get('type');

        if (type == 'view_submission') {
            handleModalSubmission(payload);
        }

        if (type == 'block_actions') {
            List<Object> actions = (List<Object>) payload.get('actions');
            if (!actions.isEmpty()) {
                Map<String, Object> action = (Map<String, Object>) actions[0];
                String actionId = (String) action.get('action_id');

                if(actionId == 'prepare_draft_email'){
                    handleDraftEmail(action);
                }

                if(actionId == 'send_message_to_vendor'){
                    handleSendMessage(payload);
                }

                if(actionId.startsWith('open_modal_')){
                    String category = actionId.substring('open_modal_'.length());
                    handleOpenModal(payload, action, category);
                }

            }
        }


    }


    private static String extractPayloadFromForm(String body) {
        System.debug(body);
        if (body.startsWith('payload=')) {
            String encoded = body.substringAfter('payload=');
            return EncodingUtil.urlDecode(encoded, 'UTF-8');
        }
        return null;
    }

    private static void handleSendMessage(Map<String, Object> payload){
        List<Object> actions = (List<Object>) payload.get('actions');
        Map<String, Object> action = (Map<String, Object>) actions[0];
        String sessionId = (String)action.get('value');
        String sentConfirmation = 'I confirm I want to send the above message. The order session Id is ' + sessionId + '\n';
        AgentApiUtils.sendMessageToAgent(sessionId, sentConfirmation);
        Map<String, Object> container = (Map<String, Object>) payload.get('container');
        String channelId = (String) container.get('channel_id');
        String messageTs = (String) container.get('message_ts');

         // Get original blocks
        Map<String, Object> message = (Map<String, Object>) payload.get('message');
        List<Object> blocks = (List<Object>) message.get('blocks');
        List<Object> updatedBlocks = new List<Object>();

        // Modify only the button
        for (Object blockObj : blocks) {
            Map<String, Object> block = (Map<String, Object>) blockObj;
            if (block.get('type') == 'actions') {
                continue;
            }
            updatedBlocks.add(block);
        }

        updatedBlocks.add(new Map<String, Object>{
            'type' => 'context',
            'elements' => new List<Object>{
                new Map<String, Object>{
                    'type' => 'mrkdwn',
                    'text' => '*Message Sent to Vendor*'
                }
            }
        });


        // Update the original Slack message
        SlackUtils.updateSlackMessage(channelId, messageTs, updatedBlocks);
    }

    private static void handleDraftEmail(Map<String, Object> action){
        String sessionId = (String)action.get('value');
        Agent_Session__c agentSession = [SELECT Id, Session_Id__c, Slack_Id__c FROM Agent_Session__c WHERE Session_Id__c =: sessionId]; 
        String metadata = (String) agentSession.Slack_Id__c;
        List<String> parts = metadata.split(':');
        String threadTs = parts.size() > 0 ? parts[0] : null;
        String channelId = parts.size() > 1 ? parts[1] : null;
        String message = 'Frame a message for the order';
        String agentReply = AgentApiUtils.sendMessageToAgent(sessionId, message);
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

    private static void handleOpenModal(Map<String, Object> payload, Map<String, Object> action, String category){
        // Decode the button value (base64 JSON string of items for the category)
    String encoded = (String) action.get('value');
    String json = EncodingUtil.urlDecode(EncodingUtil.base64Decode(encoded).toString(), 'UTF-8');

    List<Object> itemList = (List<Object>) System.JSON.deserializeUntyped(json);

    List<Object> options = new List<Object>();
    for (Object itemObj : itemList) {
        Map<String, Object> item = (Map<String, Object>) itemObj;
        String name = (String) item.get('item');
        Integer quantity = (Integer) item.get('quantity');

        String label = name + ' (Qty: ' + quantity + ')';
        String optionValue = name + ':' + quantity;

        options.add(new Map<String, Object>{
            'text' => new Map<String, Object>{
                'type' => 'plain_text',
                'text' => label
            },
            'value' => optionValue
        });
    }

    List<Object> blocks = new List<Object>();
    //item options
    blocks.add(new Map<String, Object>{
        'type' => 'input',
        'block_id' => 'missing_items_select_' + category.replaceAll('\\s+', '_'),
        'element' => new Map<String, Object>{
            'type' => 'multi_static_select',
            'action_id' => 'selected_items_' + category.replaceAll('\\s+', '_'),
            'placeholder' => new Map<String, Object>{
                'type' => 'plain_text',
                'text' => 'Choose items'
            },
            'options' => options
        },
        'label' => new Map<String, Object>{
            'type' => 'plain_text',
            'text' => 'Select Items from ' + category.capitalize()
        }
    });

    Schema.DescribeFieldResult fieldResult = Vendor__c.Vendor_Category__c.getDescribe();
    List<Schema.PicklistEntry> picklistValues = fieldResult.getPicklistValues();

    String matchedPicklistValue = null;

    for (Schema.PicklistEntry entry : picklistValues) {
        String normalized = entry.getValue().toLowerCase().replaceAll('\\s+', '_');
        String inputCategory = category.toLowerCase().replaceAll('\\s+', '_');
        if (normalized == inputCategory) {
            matchedPicklistValue = entry.getValue();
            break;
        }
    }

    List<Vendor__c> vendors;

    if(matchedPicklistValue==null){
        vendors = [SELECT Id, Name__c FROM Vendor__c];
    }
    else{
        vendors = [SELECT Id, Name__c FROM Vendor__c WHERE Vendor_Category__c = :matchedPicklistValue];
    }

    List<Object> vendorOptions = new List<Object>();
    for (Vendor__c vendor : vendors) {
        vendorOptions.add(new Map<String, Object>{
            'text' => new Map<String, Object>{
                'type' => 'plain_text',
                'text' => vendor.Name__c
            },
            'value' => vendor.Id
        });
    }

    blocks.add(new Map<String, Object>{
        'type' => 'input',
        'block_id' => 'vendor_select_block',
        'element' => new Map<String, Object>{
            'type' => 'static_select',
            'action_id' => 'selected_vendor',
            'placeholder' => new Map<String, Object>{
                'type' => 'plain_text',
                'text' => 'Choose a vendor'
            },
            'options' => vendorOptions
        },
        'label' => new Map<String, Object>{
            'type' => 'plain_text',
            'text' => 'Select Vendor'
        }
    });

    String channelId = (String)((Map<String,Object>) payload.get('channel')).get('id');

    // Construct modal
    Map<String, Object> modal = new Map<String, Object>{
        'type' => 'modal',
        'callback_id' => 'modal_callback_' + category.replaceAll('\\s+', '_'),
        'private_metadata' => channelId,
        'title' => new Map<String, Object>{
            'type' => 'plain_text',
            'text' => 'Prepare Order'
        },
        'submit' => new Map<String, Object>{
            'type' => 'plain_text',
            'text' => 'Prepare Order'
        },
        'close' => new Map<String, Object>{
            'type' => 'plain_text',
            'text' => 'Cancel'
        },
        'blocks' => blocks
    };

    // Extract trigger_id to open the modal
    String triggerId = (String) payload.get('trigger_id');

    SlackUtils.openModal(triggerId, modal);

    }

    private static void handleModalSubmission(Map<String, Object> payload) {
        Map<String, Object> view = (Map<String, Object>) payload.get('view');
        String callbackId = (String) view.get('callback_id');

        if (callbackId == 'register_vendor_modal') {
            handleVendorRegistration(view);
            return;
        }

        Map<String, Object> state = (Map<String, Object>) view.get('state');
        Map<String, Object> values = (Map<String, Object>) state.get('values');
    
        List<String> selectedItems = new List<String>();
        String selectedVendorId = '';
        String selectedVendorLabel = '';
    
        for (String blockId : values.keySet()) {
            Map<String, Object> block = (Map<String, Object>) values.get(blockId);
            for (String actionId : block.keySet()) {
                Map<String, Object> action = (Map<String, Object>) block.get(actionId);
                if (action.containsKey('selected_options')) {
                    List<Object> options = (List<Object>) action.get('selected_options');
                    for (Object opt : options) {
                        Map<String, Object> optMap = (Map<String, Object>) opt;
                        selectedItems.add((String) optMap.get('value'));
                    }
                }
                if (action.containsKey('selected_option')) {
                    Map<String, Object> vendorOption = (Map<String, Object>) action.get('selected_option');
                    selectedVendorId = (String) vendorOption.get('value');
                    selectedVendorLabel = (String) ((Map<String, Object>) vendorOption.get('text')).get('text');
                }
            }
        }

        Vendor__c vendor = [SELECT Id, Name__c, Email__c, Point_of_Contact__c 
        FROM Vendor__c WHERE Id = :selectedVendorId LIMIT 1];


    
        // Reconstruct message text
        String summary = '*Order Summary:*\n\n';
        summary += '*Selected Vendor:* ' + vendor.Name__c + '\n';
        summary += '*Email:* ' + vendor.Email__c + '\n';
        summary += '*Point of Contact:* ' + vendor.Point_of_Contact__c + '\n\n';
        summary += '*Items:*\n';
        for (String item : selectedItems) {
            summary += '• ' + item + '\n';
        }

        List<Object> blocks = new List<Object>();

        // Section block with the order summary
        blocks.add(new Map<String, Object>{
            'type' => 'section',
            'text' => new Map<String, Object>{
                'type' => 'mrkdwn',
                'text' => summary
            }
        });

        // String prepareDraftInfo = JSON.serialize(new Map<String, Object>{
        //     'vendorId' => vendor.Id,
        //     'items' => selectedItems
        // });

        // Button block to trigger email draft preparation
        

    
        // Extract Slack response_url if needed OR use channel + user info
        String channelId = (String) view.get('private_metadata');
        Booking__c booking = [SELECT Id, Event_Manager__r.Name__c, Event_Manager__r.Email__c FROM Booking__c WHERE Channel_Id__c = :channelId LIMIT 1];
        String eventManagerName = booking.Event_Manager__r.Name__c;
        String eventManagerEmail = booking.Event_Manager__r.Email__c;

        String agentContextMessage = 'This a message meant to provide context related to a order.*\n\n';

        agentContextMessage += '*Vendor Details:*\n';
        agentContextMessage += '• Name: ' + vendor.Name__c + '\n';
        agentContextMessage += '• Point of Contact: ' + vendor.Point_of_Contact__c + '\n';
        agentContextMessage += '• Email: ' + vendor.Email__c + '\n\n';
        agentContextMessage += '• Buyer Name: ' + eventManagerName + '\n';
        agentContextMessage += '• Buyer Email: ' + eventManagerEmail + '\n\n';

        agentContextMessage += 'Items to be Ordered:\n';
        for (String item : selectedItems) {
            agentContextMessage += '• ' + item + '\n';
        }

        String sessionId = AgentApiUtils.startAgentSession();
        AgentApiUtils.sendMessageToAgent(sessionId, agentContextMessage);

        blocks.add(new Map<String, Object>{
            'type' => 'actions',
            'elements' => new List<Object>{
                new Map<String, Object>{
                    'type' => 'button',
                    'text' => new Map<String, Object>{
                        'type' => 'plain_text',
                        'text' => 'Prepare Draft Email'
                    },
                    'action_id' => 'prepare_draft_email' ,
                    'value' =>  sessionId  //EncodingUtil.base64Encode(Blob.valueOf(prepareDraftInfo))
                }
            }
        });

    
        // Send message via SlackUtils (custom helper class)
        Map<String,Object> res = SlackUtils.sendBlockMessage(channelId, blocks); 
        String timestamp = (String) res.get('ts');       

        upsert new Agent_Session__c(
                Session_Id__c = sessionId,
                Slack_Id__c = timestamp + ':' + channelId
        );

    }

    private static void handleVendorRegistration(Map<String, Object> view) {
        Map<String, Object> state = (Map<String, Object>) view.get('state');
        Map<String, Object> values = (Map<String, Object>) state.get('values');

        String name = extractInput(values, 'vendor_name_block', 'vendor_name');
        String pointOfContact = extractInput(values, 'contact_name_block', 'contact_name');
        String email = extractInput(values, 'email_block', 'email');
        String category = extractSelectedValue(values, 'category_block', 'category');

        Vendor__c newVendor = new Vendor__c(
            Name__c = name,
            Point_of_Contact__c = pointOfContact,
            Email__c = email,
            Vendor_Category__c = category
        );

        String confirmation = 'Vendor saved!\n\n' +
        '*Name:* ' + name + '\n' +
        '*Point of Contact:* ' + pointOfContact + '\n' +
        '*Email:* ' + email + '\n' +
        '*Category:* ' + category;

        String channelId = (String) view.get('private_metadata');

        SlackUtils.sendMessage(channelId, confirmation);

        try {
            insert newVendor;
            System.debug('Vendor inserted: ' + newVendor.Id);
        } catch (Exception e) {
            System.debug('Error inserting vendor: ' + e.getMessage());
        }

        


    }

    private static String extractInput(Map<String, Object> values, String blockId, String actionId) {
        Map<String, Object> block = (Map<String, Object>) values.get(blockId);
        Map<String, Object> action = (Map<String, Object>) block.get(actionId);
        return (String) action.get('value');
    }

    private static String extractSelectedValue(Map<String, Object> values, String blockId, String actionId) {
        Map<String, Object> block = (Map<String, Object>) values.get(blockId);
        Map<String, Object> action = (Map<String, Object>) block.get(actionId);
        Map<String, Object> selected = (Map<String, Object>) action.get('selected_option');
        return (String) selected.get('value');
    }
}