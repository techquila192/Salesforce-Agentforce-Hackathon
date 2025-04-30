@RestResource(urlMapping='/SlackInteractivityHandler')
global with sharing class SlackInteractivityHandler {

    @HttpPost
    global static void handleSlackPayload() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        String body = req.requestBody.toString();
        SlackRequestProcessor.handleSlackInteractionAsync(body);
    }
    
}
