@RestResource(urlMapping='/SlackEventHandler')
global with sharing class SlackEventHandler {
    @HttpPost
    global static void handleSlackPayload() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        String body = req.requestBody.toString();
        SlackEventProcessor.handleSlackEventAsync(body);
    }
}