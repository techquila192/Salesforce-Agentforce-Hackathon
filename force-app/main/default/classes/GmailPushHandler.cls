@RestResource(urlMapping='/GmailPush')
global with sharing class GmailPushHandler {
    
    @HttpPost
    global static void handlePush() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        
        try {
            String body = req.requestBody.toString();
            Map<String, Object> incoming = (Map<String, Object>) JSON.deserializeUntyped(body);
            Map<String, Object> message = (Map<String, Object>) incoming.get('message');
            String data = (String) message.get('data');
            
            // Step 1: Decode base64 to get emailAddress and historyId
            Blob decodedBlob = EncodingUtil.base64Decode(data);
            String decodedJson = decodedBlob.toString();
            Map<String, Object> decodedData = (Map<String, Object>) JSON.deserializeUntyped(decodedJson);

            String emailAddress = (String) decodedData.get('emailAddress');
            Long historyId = (Long) decodedData.get('historyId');

            System.debug('Received email push. Email Address: ' + emailAddress + ' | HistoryId: ' + historyId);
            
            // Step 2: Call future method to handle Gmail API call
            GmailPushHandler.handleGmailChangesAsync(emailAddress, String.valueOf(historyId));

            res.statusCode = 200;
            res.responseBody = Blob.valueOf('Success');
        } catch (Exception ex) {
            System.debug('Error in handlePush: ' + ex);
            res.statusCode = 500;
            res.responseBody = Blob.valueOf('Failure: ' + ex.getMessage());
        }
    }

    @future(callout=true)
    public static void handleGmailChangesAsync(String emailAddress, String historyIdStr) {
        try {
            Long historyId = Long.valueOf(historyIdStr);
            
            // Step 1: Get Access Token
            String accessToken = SendMessageAction.fetchAccessToken();
            Gmail_History__c historySetting = [SELECT History_Id__c FROM Gmail_History__c WHERE Name = 'Test_History' LIMIT 1];
            String startHistoryId = historySetting.History_Id__c;
           
            Http http = new Http();

            // Step 2: Get History (new messages)
            HttpRequest historyRequest = new HttpRequest();
            historyRequest.setEndpoint('https://gmail.googleapis.com/gmail/v1/users/me/history?startHistoryId=' + startHistoryId + '&historyTypes=messageAdded');
            historyRequest.setMethod('GET');
            historyRequest.setHeader('Authorization', 'Bearer ' + accessToken);

            HttpResponse historyResponse = http.send(historyRequest);

            if (historyResponse.getStatusCode() == 200) {
                System.debug(historyResponse.getBody());
                Map<String, Object> historyResult = (Map<String, Object>) JSON.deserializeUntyped(historyResponse.getBody());
                List<Object> historyRecords = (List<Object>) historyResult.get('history');

                if (!historyRecords.isEmpty()) {
                    for (Object historyObj : historyRecords) {
                        Map<String, Object> historyEntry = (Map<String, Object>) historyObj;
                        List<Object> messagesAdded = (List<Object>) historyEntry.get('messagesAdded');

                        if (messagesAdded != null && !messagesAdded.isEmpty()) {
                            for (Object messageAddedObj : messagesAdded) {
                                Map<String, Object> messageAdded = (Map<String, Object>) messageAddedObj;
                                Map<String, Object> messageInfo = (Map<String, Object>) messageAdded.get('message');

                                List<Object> labelIds = (List<Object>) messageInfo.get('labelIds');

                                // Skip if it's a SENT message
                                if (labelIds != null && labelIds.contains('SENT')) {
                                    continue;
                                }

                                String messageId = (String) messageInfo.get('id');

                                // Step 3: Fetch full message
                                HttpRequest messageRequest = new HttpRequest();
                                messageRequest.setEndpoint('https://gmail.googleapis.com/gmail/v1/users/me/messages/' + messageId + '?format=full');
                                messageRequest.setMethod('GET');
                                messageRequest.setHeader('Authorization', 'Bearer ' + accessToken);

                                HttpResponse messageResponse = http.send(messageRequest);

                                if (messageResponse.getStatusCode() == 200) {
                                    Map<String, Object> messageDetails = (Map<String, Object>) JSON.deserializeUntyped(messageResponse.getBody());

                                    // ➡️ Extract threadId
                                    String threadId = (String) messageDetails.get('threadId');
                                    
                                    // ➡️ Extract Subject
                                    List<Object> headers = (List<Object>) ((Map<String, Object>) messageDetails.get('payload')).get('headers');
                                    String subject = '';
                                    for (Object headerObj : headers) {
                                        Map<String, Object> header = (Map<String, Object>) headerObj;
                                        if (header.get('name') == 'Subject') {
                                            subject = (String) header.get('value');
                                            break;
                                        }
                                    }

                                    // ➡️ Extract Body (text/plain part)
                                    String body = '';
                                    Map<String, Object> payload = (Map<String, Object>) messageDetails.get('payload');
                                    List<Object> parts = (List<Object>) payload.get('parts');

                                    if (parts != null) {
                                        for (Object partObj : parts) {
                                            Map<String, Object> part = (Map<String, Object>) partObj;
                                            if (part.get('mimeType') == 'text/plain') {
                                                String base64Data = (String) ((Map<String, Object>) part.get('body')).get('data');
                                                base64Data = base64Data.replace('-', '+').replace('_', '/');
                                                body = EncodingUtil.base64Decode(base64Data).toString();
                                                break;
                                            }
                                        }
                                    } else if (payload.containsKey('body')) {
                                        // In case there's no 'parts', sometimes body is directly under payload
                                        Map<String, Object> bodyMap = (Map<String, Object>) payload.get('body');
                                        if (bodyMap.containsKey('data')) {
                                            String base64Data = (String) bodyMap.get('data');
                                            base64Data = base64Data.replace('-', '+').replace('_', '/');
                                            body = EncodingUtil.base64Decode(base64Data).toString();
                                        }
                                    }

                                    System.debug('Email Subject: ' + subject);
                                    System.debug('Email Body: ' + body);
                                    System.debug('Thread ID: ' + threadId);

                                    // ➡️ Find AgentSession by threadId
                                    List<Agent_Session__c> sessions = [SELECT Id, Session_Id__c, Slack_Id__c, Thread_Id__c FROM Agent_Session__c WHERE Thread_Id__c =: threadId LIMIT 1];
                                    if (!sessions.isEmpty()) {
                                        Agent_Session__c agentSession = sessions[0];
                                        String metadata = (String) agentSession.Slack_Id__c;
                                        List<String> mdtParts = metadata.split(':');
                                        String threadTs = mdtParts.size() > 0 ? mdtParts[0] : null;
                                        String channelId = mdtParts.size() > 1 ? mdtParts[1] : null;


                                        String summarizationMessage = 'Summarize the following email message. Communicate and narrate, in passive voice, the content of the message to the buyer. Exclude any unrelated content.\n' +
                                                                      'Subject: ' + subject + '\n' +
                                                                      'Message: ' + body + '\n';
                                        String agentReply = AgentApiUtils.sendMessageToAgent(agentSession.Session_Id__c, summarizationMessage);
                                        agentReply = 'Summarized Incoming Message from Vendor: \n\n' + agentReply;
                                        SlackUtils.sendThreadMessage(channelId, threadTs, agentReply);
                                    }
                                }
                            }
                        }
                    }
                    // After processing all, update history id
                    historySetting.History_Id__c = historyIdStr;
                    update historySetting;
                }
            }
        } catch (Exception ex) {
            System.debug('Error in handleGmailChangesAsync: ' + ex);
        }
    }
}
