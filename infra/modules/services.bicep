param location string
param tags object
param cosmosName string
param openAiName string
param documentName string
param vaultName string
param models array
param workspaceId string
param siemAuthorizationRuleId string
param siemEventHubName string
module cosmos './cosmos-db.bicep' = {
  name: 'cosmos-analisisdec'
  params: { location: location, tags: tags, accountName: cosmosName, databaseName: 'analysis-dec-db', logAnalyticsWorkspaceResourceId: workspaceId, siemAuthorizationRuleId: siemAuthorizationRuleId, siemEventHubName: siemEventHubName }
}
module openAi './cognitive-account.bicep' = {
  name: 'openai-analisisdec'
  params: { location: location, tags: tags, accountName: openAiName, kind: 'OpenAI', modelDeployments: models, logAnalyticsWorkspaceResourceId: workspaceId, siemAuthorizationRuleId: siemAuthorizationRuleId, siemEventHubName: siemEventHubName }
}
module document './cognitive-account.bicep' = {
  name: 'documentos-analisisdec'
  params: { location: location, tags: tags, accountName: documentName, kind: 'FormRecognizer', modelDeployments: [], logAnalyticsWorkspaceResourceId: workspaceId, siemAuthorizationRuleId: siemAuthorizationRuleId, siemEventHubName: siemEventHubName }
}
resource vault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: vaultName
  location: location
  tags: tags
  properties: {
    tenantId: subscription().tenantId
    sku: { family: 'A', name: 'standard' }
    enableRbacAuthorization: true
    enableSoftDelete: true
    softDeleteRetentionInDays: 90
    enablePurgeProtection: true
    publicNetworkAccess: 'Disabled'
    networkAcls: { defaultAction: 'Deny', bypass: 'None' }
  }
}
resource diagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'auditoria-caf'
  scope: vault
  properties: {
    workspaceId: workspaceId
    eventHubAuthorizationRuleId: empty(siemAuthorizationRuleId) ? null : siemAuthorizationRuleId
    eventHubName: empty(siemEventHubName) ? null : siemEventHubName
    logs: [{ categoryGroup: 'allLogs', enabled: true }]
  }
}
output cosmosId string = cosmos.outputs.resourceId
output openAiId string = openAi.outputs.resourceId
output documentIntelligenceId string = document.outputs.resourceId
output vaultId string = vault.id
output connections object = {
  cosmos: 'https://${cosmosName}.documents.azure.com:443/'
  openAi: 'https://${openAiName}.openai.azure.com/'
  documentIntelligence: 'https://${documentName}.cognitiveservices.azure.com/'
  keyVault: vault.properties.vaultUri
}
