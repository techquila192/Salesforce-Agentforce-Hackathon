@RestResource(urlMapping='/SlackCommandHandler')
global with sharing class SlackCommandHandler {
    
    @HttpPost
    global static void handleSlashCommand() {
        RestRequest req = RestContext.request;
        String body = req.requestBody.toString();
        Map<String, String> params = parseFormEncodedBody(body);

        String channelId = params.get('channel_id');
        
        String triggerId = params.get('trigger_id');
        if (String.isBlank(triggerId)) return;

        Map<String, Object> modal = buildModalView();
        modal.put('private_metadata', channelId);

        SlackUtils.openModal(triggerId, modal); 
    }

    private static Map<String, String> parseFormEncodedBody(String body) {
        Map<String, String> result = new Map<String, String>();
        for (String part : body.split('&')) {
            List<String> pair = part.split('=');
            if (pair.size() == 2) {
                result.put(
                    EncodingUtil.urlDecode(pair[0], 'UTF-8'),
                    EncodingUtil.urlDecode(pair[1], 'UTF-8')
                );
            }
        }
        return result;
    }

    private static Map<String, Object> buildModalView() {
        return new Map<String, Object>{
            'type' => 'modal',
            'callback_id' => 'register_vendor_modal',
            'title' => new Map<String, Object>{ 'type' => 'plain_text', 'text' => 'Register Vendor' },
            'submit' => new Map<String, Object>{ 'type' => 'plain_text', 'text' => 'Submit' },
            'close' => new Map<String, Object>{ 'type' => 'plain_text', 'text' => 'Cancel' },
            'blocks' => new List<Object>{
                buildInput('vendor_name_block', 'vendor_name', 'Vendor Name'),
                buildInput('contact_name_block', 'contact_name', 'Point of Contact'),
                buildInput('email_block', 'email', 'Email'),
                buildPicklist('category_block', 'category', 'Select Category')
            }
        };
    }

    private static Map<String, Object> buildInput(String blockId, String actionId, String label) {
        return new Map<String, Object>{
            'type' => 'input',
            'block_id' => blockId,
            'label' => new Map<String, Object>{ 'type' => 'plain_text', 'text' => label },
            'element' => new Map<String, Object>{
                'type' => 'plain_text_input',
                'action_id' => actionId
            }
        };
    }

    private static Map<String, Object> buildPicklist(String blockId, String actionId, String label) {
        List<Schema.PicklistEntry> picklistEntries = Vendor__c.Vendor_Category__c.getDescribe().getPicklistValues();

        List<Object> categoryOptions = new List<Object>();
        for (Schema.PicklistEntry entry : picklistEntries) {
            categoryOptions.add(new Map<String, Object>{
                'text' => new Map<String, Object>{ 'type' => 'plain_text', 'text' => entry.getLabel() },
                'value' => entry.getValue()
            });
        }

        return new Map<String, Object>{
            'type' => 'input',
            'block_id' => blockId,
            'label' => new Map<String, Object>{ 'type' => 'plain_text', 'text' => label },
            'element' => new Map<String, Object>{
                'type' => 'static_select',
                'action_id' => actionId,
                'placeholder' => new Map<String, Object>{ 'type' => 'plain_text', 'text' => 'Choose a category' },
                'options' => categoryOptions
            }
        };
    }

}
