param location string
param tags object
param cosmosName string
param openAiName string
param documentName string
param models array
param workspaceId string
param siemAuthorizationRuleId string
param siemEventHubName string
module cosmos './cosmos-db.bicep' = {
  name: 'cosmos-vinculador'
  params: { location: location, tags: tags, accountName: cosmosName, databaseName: 'vinculador-db', logAnalyticsWorkspaceResourceId: workspaceId, siemAuthorizationRuleId: siemAuthorizationRuleId, siemEventHubName: siemEventHubName }
}
module openAi './cognitive-account.bicep' = {
  name: 'openai-vinculador'
  params: { location: location, tags: tags, accountName: openAiName, kind: 'OpenAI', modelDeployments: models, logAnalyticsWorkspaceResourceId: workspaceId, siemAuthorizationRuleId: siemAuthorizationRuleId, siemEventHubName: siemEventHubName }
}
module document './cognitive-account.bicep' = {
  name: 'documentos-vinculador'
  params: { location: location, tags: tags, accountName: documentName, kind: 'FormRecognizer', modelDeployments: [], logAnalyticsWorkspaceResourceId: workspaceId, siemAuthorizationRuleId: siemAuthorizationRuleId, siemEventHubName: siemEventHubName }
}
output cosmosId string = cosmos.outputs.resourceId
output openAiId string = openAi.outputs.resourceId
output documentIntelligenceId string = document.outputs.resourceId
output connections object = {
  cosmos: 'https://${cosmosName}.documents.azure.com:443/'
  openAi: 'https://${openAiName}.openai.azure.com/'
  documentIntelligence: 'https://${documentName}.cognitiveservices.azure.com/'
}
