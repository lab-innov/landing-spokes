param usesBlobTrigger bool = true
param principalId string
param storageName string
param cosmosName string
param openAiName string
param documentName string
param batchEnabled bool
resource storage 'Microsoft.Storage/storageAccounts@2023-05-01' existing = { name: storageName }
resource blobs 'Microsoft.Storage/storageAccounts/blobServices@2023-05-01' existing = { name: 'default', parent: storage }
resource containers 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' existing = [for name in ['poc-vinculador-files', 'poc-vinculador-files-processed', 'poc-vinculador-gpt-files', 'poc-vinculador-trigger-data-factory']: { name: name, parent: blobs }]
resource blobRoles 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for (name, i) in ['poc-vinculador-files', 'poc-vinculador-files-processed', 'poc-vinculador-gpt-files', 'poc-vinculador-trigger-data-factory']: {
  name: guid(storage.id, name, principalId, usesBlobTrigger && name == 'poc-vinculador-files' ? 'blob-owner' : 'blob-contributor')
  scope: containers[i]
  properties: { principalId: principalId, principalType: 'ServicePrincipal', roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', usesBlobTrigger && name == 'poc-vinculador-files' ? 'b7e6dc6d-f1e8-4753-8033-0f276bb0955b' : 'ba92f5b4-2d11-453d-a403-e96b0029c9fe') }
}]
resource cosmos 'Microsoft.DocumentDB/databaseAccounts@2024-05-15' existing = { name: cosmosName }
resource cosmosRole 'Microsoft.DocumentDB/databaseAccounts/sqlRoleAssignments@2024-05-15' = {
  name: guid(cosmos.id, principalId, 'vinculador-db')
  parent: cosmos
  properties: { principalId: principalId, roleDefinitionId: '${cosmos.id}/sqlRoleDefinitions/00000000-0000-0000-0000-000000000002', scope: '${cosmos.id}/dbs/vinculador-db' }
}
resource openAi 'Microsoft.CognitiveServices/accounts@2025-06-01' existing = { name: openAiName }
resource document 'Microsoft.CognitiveServices/accounts@2025-06-01' existing = { name: documentName }
resource openAiRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(openAi.id, principalId, 'inferencia')
  scope: openAi
  properties: { principalId: principalId, principalType: 'ServicePrincipal', roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd') }
}
resource documentRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(document.id, principalId, 'analisis')
  scope: document
  properties: { principalId: principalId, principalType: 'ServicePrincipal', roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'a97b65f3-24c7-4388-baec-2e87135dc908') }
}
resource batchRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' = if (batchEnabled) {
  name: guid(resourceGroup().id, 'vinculador-batch')
  properties: {
    roleName: 'VINCULADOR Batch ${uniqueString(resourceGroup().id)}'
    description: 'Crear y consultar lotes y archivos de la cuenta OpenAI de VINCULADOR.'
    type: 'CustomRole'
    assignableScopes: [resourceGroup().id]
    permissions: [{
      actions: []
      notActions: []
      dataActions: [
        'Microsoft.CognitiveServices/accounts/OpenAI/batch-jobs/write'
        'Microsoft.CognitiveServices/accounts/OpenAI/batches/read'
        'Microsoft.CognitiveServices/accounts/OpenAI/batches/cancel/action'
        'Microsoft.CognitiveServices/accounts/OpenAI/files/write'
        'Microsoft.CognitiveServices/accounts/OpenAI/files/read'
        'Microsoft.CognitiveServices/accounts/OpenAI/files/delete'
      ]
      notDataActions: []
    }]
  }
}
resource batchAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (batchEnabled) {
  name: guid(openAi.id, principalId, 'batch')
  scope: openAi
  properties: { principalId: principalId, principalType: 'ServicePrincipal', roleDefinitionId: batchRole!.id }
}

resource queueRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (usesBlobTrigger) {
  name: guid(storage.id, principalId, 'cola-trigger')
  scope: storage
  properties: { principalId: principalId, principalType: 'ServicePrincipal', roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '974c5e8b-45b9-4653-ba55-5f855dd0fb88') }
}
