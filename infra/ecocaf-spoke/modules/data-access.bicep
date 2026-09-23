targetScope = 'resourceGroup'

param principalId string
param storageName string
param cosmosName string
param openAiName string
param documentName string

resource storage 'Microsoft.Storage/storageAccounts@2023-05-01' existing = {
  name: storageName
}
resource blobs 'Microsoft.Storage/storageAccounts/blobServices@2023-05-01' existing = {
  name: 'default'
  parent: storage
}
resource documents 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' existing = {
  name: 'ecocaf'
  parent: blobs
}
resource blobRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(documents.id, principalId, 'datos-ecocaf')
  scope: documents
  properties: {
    principalId: principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'ba92f5b4-2d11-453d-a403-e96b0029c9fe')
  }
}

resource cosmos 'Microsoft.DocumentDB/databaseAccounts@2024-05-15' existing = {
  name: cosmosName
}
resource cosmosRoles 'Microsoft.DocumentDB/databaseAccounts/sqlRoleAssignments@2024-05-15' = [for databaseName in ['EcoCAF', 'Auditoria']: {
  name: guid(cosmos.id, principalId, databaseName)
  parent: cosmos
  properties: {
    principalId: principalId
    roleDefinitionId: '${cosmos.id}/sqlRoleDefinitions/00000000-0000-0000-0000-000000000002'
    scope: '${cosmos.id}/dbs/${databaseName}'
  }
}]

resource openAi 'Microsoft.CognitiveServices/accounts@2025-06-01' existing = {
  name: openAiName
}
resource document 'Microsoft.CognitiveServices/accounts@2025-06-01' existing = {
  name: documentName
}
resource openAiRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(openAi.id, principalId, 'inferencia-ecocaf')
  scope: openAi
  properties: {
    principalId: principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd')
  }
}
resource documentRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(document.id, principalId, 'analisis-ecocaf')
  scope: document
  properties: {
    principalId: principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'a97b65f3-24c7-4388-baec-2e87135dc908')
  }
}
