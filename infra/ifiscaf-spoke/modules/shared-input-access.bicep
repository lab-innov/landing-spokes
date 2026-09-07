targetScope = 'resourceGroup'

param sharedStorageAccountName string
param sharedContainerName string
param databricksAccessConnectorPrincipalId string

var storageBlobDataReaderRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '2a2b9908-6ea1-4ae2-8e65-a410df84e7d1')

resource sharedStorage 'Microsoft.Storage/storageAccounts@2023-05-01' existing = {
  name: sharedStorageAccountName
}

resource sharedBlobService 'Microsoft.Storage/storageAccounts/blobServices@2023-05-01' existing = {
  name: 'default'
  parent: sharedStorage
}

resource sharedContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' existing = {
  name: sharedContainerName
  parent: sharedBlobService
}

resource databricksSharedInputReader 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(sharedContainer.id, databricksAccessConnectorPrincipalId, storageBlobDataReaderRoleId)
  scope: sharedContainer
  properties: {
    principalId: databricksAccessConnectorPrincipalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: storageBlobDataReaderRoleId
  }
}

output containerResourceId string = sharedContainer.id
output roleAssignmentId string = databricksSharedInputReader.id
