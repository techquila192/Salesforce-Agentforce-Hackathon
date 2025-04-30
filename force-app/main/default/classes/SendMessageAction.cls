public with sharing class SendMessageAction {
    public class Input {
        @InvocableVariable(label='Vendor Email' required=true)
        public String vendorEmail;

        @InvocableVariable(label='Message Content' required=true)
        public String messageContent;

        @InvocableVariable(label='Message Subject' required=true)
        public String messageSubject;

        @InvocableVariable(label='Sender Email' required=true)
        public String senderEmail;

        @InvocableVariable(label='Session Id' required=true)
        public String messagingSessionId;
    
    }

    public class Output {
        @InvocableVariable(label='Message Sent')
        public Boolean messageSent;
    }

    @InvocableMethod(label='Send Vendor Message')
    public static List<Output> sendMessageToSlack(List<Input> inputs) {
        List<Output> results = new List<Output>();
        for (Input input : inputs) {
            String threadId = sendEmail(input.vendorEmail, input.senderEmail, input.messageSubject, input.messageContent);
            Agent_Session__c agentSession = [SELECT Id, Session_Id__c, Slack_Id__c FROM Agent_Session__c WHERE Session_Id__c = :input.messagingSessionId LIMIT 1];
            agentSession.Thread_Id__c = threadId;
            update agentSession;
            Output output = new Output();
            output.messageSent = true; 
            results.add(output);
        }
        return results;
    }

    public static String fetchAccessToken() {
        Gmail_Token__mdt token = [
            SELECT Refresh_Token__c, Client_Id__c, Client_Secret__c 
            FROM Gmail_Token__mdt 
            WHERE DeveloperName = 'Test_token' 
            LIMIT 1
        ];

        String refreshToken = token.Refresh_Token__c;
        String clientId = token.Client_Id__c;
        String clientSecret = token.Client_Secret__c;

        HttpRequest req = new HttpRequest();
        req.setEndpoint('https://oauth2.googleapis.com/token');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/x-www-form-urlencoded');

        String body = 'client_id=' + EncodingUtil.urlEncode(clientId, 'UTF-8') +
                      '&client_secret=' + EncodingUtil.urlEncode(clientSecret, 'UTF-8') +
                      '&refresh_token=' + EncodingUtil.urlEncode(refreshToken, 'UTF-8') +
                      '&grant_type=refresh_token';
        req.setBody(body);

        Http http = new Http();
        HttpResponse res = http.send(req);

        if (res.getStatusCode() == 200) {
            Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            return (String) result.get('access_token');
        } else {
            System.debug('Access token fetch failed: ' + res.getBody());
            return null;
        }
    }

    public static String sendEmail(String recipientEmail, String fromEmail, String subject, String messageBody) {
        String accessToken = fetchAccessToken();
        if (accessToken == null) {
            System.debug('No access token, aborting email send.');
            return '';
        }
    
        // Build MIME message
        String rawMime = 'From: ' + fromEmail + '\n' +
                         'To: ' + recipientEmail + '\n' +
                         'Subject: ' + subject + '\n\n' +
                         messageBody;
    
        Blob rawBytes = Blob.valueOf(rawMime);
        String base64Encoded = EncodingUtil.base64Encode(rawBytes)
                                   .replace('+','-').replace('/','_').replaceAll('=+$', '');
    
        HttpRequest req = new HttpRequest();
        req.setEndpoint('https://gmail.googleapis.com/gmail/v1/users/me/messages/send');
        req.setMethod('POST');
        req.setHeader('Authorization', 'Bearer ' + accessToken);
        req.setHeader('Content-Type', 'application/json');
        req.setBody('{"raw":"' + base64Encoded + '"}');
    
        Http http = new Http();
        HttpResponse res = http.send(req);
    
        if (res.getStatusCode() == 200) {
            Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            return (String) result.get('threadId');
        } else {
            System.debug('Failed to send email: ' + res.getBody());
            return '';
        }
    }
    
}