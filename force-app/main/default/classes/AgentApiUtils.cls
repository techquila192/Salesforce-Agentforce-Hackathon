public with sharing class AgentApiUtils {

    public static String AGENT_API_NAMED_CREDENTIAL = 'AgentApi';

    public static String startAgentSession() {

        Agent_Api_Config__mdt agentConfig = [
            SELECT Agent_Id__c 
            FROM Agent_Api_Config__mdt 
            WHERE DeveloperName = 'Event_Manager_Config' 
            LIMIT 1
        ];

        String agentId =  agentConfig.Agent_Id__c;
        // Construct the endpoint relative to the named credential
        String endpoint = '/einstein/ai-agent/v1/agents/' + agentId + '/sessions';

        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:'+ AGENT_API_NAMED_CREDENTIAL + endpoint);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');

        // Replace with your Salesforce domain
        String instanceUrl = URL.getOrgDomainUrl().toExternalForm();
        String externalSessionKey = UUID.randomUUID().toString();

        Map<String, Object> bodyMap = new Map<String, Object>{
            'externalSessionKey' => externalSessionKey,
            'instanceConfig' => new Map<String, Object>{ 'endpoint' => instanceUrl },
            'streamingCapabilities' => new Map<String, Object>{ 'chunkTypes' => new List<String>{'Text'} },
            'bypassUser' => true
        };

        String body = JSON.serialize(bodyMap);
        req.setBody(body);

        Http http = new Http();
        HttpResponse res = http.send(req);

        if (res.getStatusCode() == 201 || res.getStatusCode() == 200) {
            // Parse the JSON response
            Map<String, Object> resMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            // Extract sessionId
            String sessionId = (String) resMap.get('sessionId');
            return sessionId;
        } else {
            System.debug('Agent API Error: ' + res.getBody());
            throw new CalloutException('Failed to start agent session: ' + res.getStatusCode());
        }
    }

    public static String sendMessageToAgent(String sessionId, String messageContent) {
        String endpoint = '/einstein/ai-agent/v1/sessions/' + sessionId + '/messages';

        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:'+ AGENT_API_NAMED_CREDENTIAL + endpoint);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');

        Long sequenceId = DateTime.now().getTime();

        Map<String, Object> payload = new Map<String, Object>{
            'message' => new Map<String, Object>{
                'sequenceId' => sequenceId,
                'type' => 'Text',
                'text' => messageContent
            },
            'variables' => new List<Object>() // Send empty list for now
        };

        req.setBody(JSON.serialize(payload));
        req.setTimeout(20*1000);

        Http http = new Http();
        HttpResponse res = http.send(req);

        if (res.getStatusCode() != 200) {
            System.debug('Error from Agent API: ' + res.getBody());
            throw new CalloutException('Failed to send message to agent.');
        }

        // Extract just the messages string portion from the response
        Map<String, Object> fullResponse = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        if (fullResponse.containsKey('messages')) {
            List<Object> messages = (List<Object>)fullResponse.get('messages');
            if(messages.size() > 0){
                Map<String, Object> msgMap = (Map<String, Object>) messages[0];
                String agentReply = (String)msgMap.get('message');
                return agentReply;
            }
            else {
                return 'Empty response list';
            }
             // Return messages as a JSON string
        } else {
            return 'No messages in response';
        }
    }
}