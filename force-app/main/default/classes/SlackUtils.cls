public with sharing class SlackUtils {

    private static final String SLACK_NAMED_CREDENTIAL = 'SlackBot'; // Your Named Credential name
    private static final String SLACK_ADMIN_CREDENTIAL = 'SlackAdmin';

    // Send a message to a Slack channel
    public static void sendMessage(String channelId, String message) {
        Http http = new Http();
        HttpRequest request = new HttpRequest();
        request.setEndpoint('callout:' + SLACK_NAMED_CREDENTIAL + '/api/chat.postMessage');
        request.setMethod('POST');
        request.setHeader('Content-Type', 'application/json; charset=utf-8');

        Map<String, Object> payload = new Map<String, Object>{
            'channel' => channelId,
            'text' => message
        };

        request.setBody(JSON.serialize(payload));
        HttpResponse response = http.send(request);
        System.debug('Slack Response: ' + response.getBody());
    }

    public static void sendThreadMessage(String channelId, String threadTs, String message) {
        Http http = new Http();
        HttpRequest request = new HttpRequest();
        request.setEndpoint('callout:' + SLACK_NAMED_CREDENTIAL + '/api/chat.postMessage');
        request.setMethod('POST');
        request.setHeader('Content-Type', 'application/json; charset=utf-8');

        Map<String, Object> payload = new Map<String, Object>{
            'channel' => channelId,
            'text' => message,
            'thread_ts' => threadTs
        };

        request.setBody(JSON.serialize(payload));
        HttpResponse response = http.send(request);
        System.debug('Slack Response: ' + response.getBody());
    }

    public static void sendBlocksThreadMessage(String channelId, String threadTs, List<Object> blocks) {
        Http http = new Http();
        HttpRequest request = new HttpRequest();
        request.setEndpoint('callout:' + SLACK_NAMED_CREDENTIAL + '/api/chat.postMessage');
        request.setMethod('POST');
        request.setHeader('Content-Type', 'application/json; charset=utf-8');

        Map<String, Object> payload = new Map<String, Object>{
            'channel' => channelId,
            'blocks' => blocks,
            'thread_ts' => threadTs
        };

        request.setBody(JSON.serialize(payload));
        HttpResponse response = http.send(request);
        System.debug('Slack Response: ' + response.getBody());
    }

    public static Map<String, Object> sendBlockMessage(String channelId, List<Object> blocks) {
        Http http = new Http();
        HttpRequest request = new HttpRequest();
        request.setEndpoint('callout:' + SLACK_NAMED_CREDENTIAL + '/api/chat.postMessage');
        request.setMethod('POST');
        request.setHeader('Content-Type', 'application/json; charset=utf-8');

        //Map<String, Object> blockPayload = (Map<String, Object>) JSON.deserializeUntyped(blockJson);
        //List<Object> blocks = (List<Object>) blockPayload.get('blocks');

        //List<Object> blocks = (List<Object>) blockJson.get('blocks');


        Map<String, Object> payload = new Map<String, Object>{
            'channel' => channelId,
            'blocks' => blocks,
            'text' => 'Block Kit not formatted correctly'
        };

        request.setBody(JSON.serialize(payload));
        HttpResponse response = http.send(request);
        System.debug('Slack Response: ' + response.getBody());
        return (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
    }

    public static void updateSlackMessage(String channelId, String messageTs, List<Object> updatedBlocks) {
        Map<String, Object> payload = new Map<String, Object>{
            'channel' => channelId,
            'ts' => messageTs,
            'blocks' => updatedBlocks
        };

        HttpRequest req = new HttpRequest();
        req.setMethod('POST');
        req.setEndpoint('callout:' + SLACK_NAMED_CREDENTIAL + '/api/chat.update');
        req.setHeader('Content-Type', 'application/json');
        req.setBody(JSON.serialize(payload));

        Http http = new Http();
        HttpResponse res = http.send(req);
        System.debug('Slack update response: ' + res.getBody());
    }

    public static void openModal(String triggerId, Map<String, Object> modalPayload) {
        Map<String, Object> payload = new Map<String, Object>{
            'trigger_id' => triggerId,
            'view' => modalPayload
        };

        Http http = new Http();
        HttpRequest req = new HttpRequest();
        req.setMethod('POST');
        req.setEndpoint('callout:' + SLACK_NAMED_CREDENTIAL + '/api/views.open');
        req.setHeader('Content-Type', 'application/json; charset=utf-8');
        req.setBody(JSON.serialize(payload));

        HttpResponse res = http.send(req);
        System.debug('Slack Modal Response: ' + res.getBody());
    }

    // Create a private channel
    public static String createPrivateChannel(String channelName) {
        Http http = new Http();
        HttpRequest request = new HttpRequest();
        request.setEndpoint('callout:' + SLACK_ADMIN_CREDENTIAL + '/api/conversations.create');
        request.setMethod('POST');
        request.setHeader('Content-Type', 'application/json; charset=utf-8');

        Map<String, Object> payload = new Map<String, Object>{
            'name' => channelName,
            'is_private' => true
        };

        request.setBody(JSON.serialize(payload));
        HttpResponse response = http.send(request);
        System.debug('Create Channel Response: ' + response.getBody());

        Map<String, Object> resMap = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
        if ((Boolean) resMap.get('ok')) {
            Map<String, Object> channel = (Map<String, Object>) resMap.get('channel');
            return (String) channel.get('id');
        }
        return null;
    }

    // Add a user to the private channel
    public static void addUserToChannel(String channelId, String userId) {
        Http http = new Http();
        HttpRequest request = new HttpRequest();
        request.setEndpoint('callout:' + SLACK_ADMIN_CREDENTIAL + '/api/conversations.invite');
        request.setMethod('POST');
        request.setHeader('Content-Type', 'application/json; charset=utf-8');

        String agentUserId =  getSlackBotUserId();
        String allUsers = userId + ',' + agentUserId;
        Map<String, Object> payload = new Map<String, Object>{
            'channel' => channelId,
            'users' => allUsers
        };

        request.setBody(JSON.serialize(payload));
        HttpResponse response = http.send(request);
        System.debug('Add User Response: ' + response.getBody());
    }

    public static String getSlackUserIdByEmail(String email) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:' + SLACK_NAMED_CREDENTIAL + '/api/users.lookupByEmail?email='+email);
        req.setMethod('GET');
        req.setHeader('Content-Type', 'application/x-www-form-urlencoded');

        Http http = new Http();
        HttpResponse res = http.send(req);
        System.debug('Slack Response: ' + res.getBody());

        if (res.getStatusCode() == 200) {
            Map<String, Object> resMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            if ((Boolean) resMap.get('ok')) {
                Map<String, Object> user = (Map<String, Object>) resMap.get('user');
                return (String) user.get('id');
            }
        }
        return null;
    }

    public static String getSlackBotUserId() {
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:' + SLACK_NAMED_CREDENTIAL + '/api/auth.test');
        req.setMethod('GET');
        
        Http http = new Http();
        HttpResponse res = http.send(req);
        
        if (res.getStatusCode() == 200) {
            Map<String, Object> jsonResponse = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            if ((Boolean) jsonResponse.get('ok')) {
                return (String) jsonResponse.get('user_id');
            } else {
                String error = (String) jsonResponse.get('error');
                throw new CalloutException('Slack auth.test failed: ' + error);
            }
        } else {
            throw new CalloutException('Slack callout failed with status: ' + res.getStatus());
        }
    }
}
