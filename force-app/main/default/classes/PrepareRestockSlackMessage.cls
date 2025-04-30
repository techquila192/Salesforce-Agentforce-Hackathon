public with sharing class PrepareRestockSlackMessage {
    public class Input {
        @InvocableVariable(required=true)
        public String agentJson;
    }

    public class Output {
        @InvocableVariable
        public String jsonString;
    }

    public class OutputItem {
        public Object buttons;
        public Object items;
    }

    @InvocableMethod(label='Build Slack Buttons for Missing Items')
    public static List<Output> buildButtons(List<Input> inputs) {
        List<Output> results = new List<Output>();

        for (Input input : inputs) {
            Object raw = JSON.deserializeUntyped(input.agentJson);
            List<Map<String, Object>> items = new List<Map<String, Object>>();

            if (raw instanceof List<Object>) {
                for (Object o : (List<Object>) raw) {
                    if (o instanceof Map<String, Object>) {
                        items.add((Map<String, Object>) o);
                    }
                }
            }

            // Group items by category
            Map<String, List<Map<String, Object>>> categoryMap = new Map<String, List<Map<String, Object>>>();
            for (Map<String, Object> item : items) {
                String category = (String) item.get('category');
                if (!categoryMap.containsKey(category)) {
                    categoryMap.put(category, new List<Map<String, Object>>());
                }
                categoryMap.get(category).add(item);
            }

            List<Object> buttons = new List<Object>();

            for (String category : categoryMap.keySet()) {
                List<Map<String, Object>> categoryItems = categoryMap.get(category);

                // Prepare the compact list of item name and quantity
                List<Map<String, Object>> compactItemList = new List<Map<String, Object>>();
                for (Map<String, Object> item : categoryItems) {
                    compactItemList.add(new Map<String, Object>{
                        'item' => item.get('item'),
                        'quantity' => item.get('quantity')
                    });
                }

                String compactJson = JSON.serialize(compactItemList);

                // Button block
                Map<String, Object> button = new Map<String, Object>{
                    'type' => 'button',
                    'action_id' => 'open_modal_' + category.replaceAll('\\s+', '_'),
                    'text' => new Map<String, Object>{
                        'type' => 'plain_text',
                        'text' => '📦 Restock: ' + category.capitalize()
                    },
                    'style' => 'primary',
                    'value' => EncodingUtil.base64Encode(Blob.valueOf(compactJson))
                };

                buttons.add(button);
            }

            OutputItem outputItem = new OutputItem();
            outputItem.buttons = buttons;
            outputItem.items = raw;

            Output output = new Output();
            output.jsonString = JSON.serialize(outputItem);
            results.add(output);
        }

        return results;
    }
}
