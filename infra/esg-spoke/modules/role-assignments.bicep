targetScope = 'resourceGroup'

param workloadStorageName string
param functionStorageName string
param cosmosAccountName string
param foundryAccountName string
param openAiAccountName string
param documentIntelligenceAccountName string
param databricksWorkspaceName string
param functionPrincipalId string
param dataFactoryPrincipalId string
param foundryProjectPrincipalId string
param databricksAccessConnectorPrincipalId string

var storageBlobDataOwnerRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b7e6dc6d-f1e8-4753-8033-0f276bb0955b')
var storageBlobDataContributorRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'ba92f5b4-2d11-453d-a403-e96b0029c9fe')
var storageQueueDataContributorRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '974c5e8b-45b9-4653-ba55-5f855dd0fb88')
var storageTableDataContributorRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '0a9a7e1f-b9d0-4cc4-a60d-0319b160aaa3')
var storageAccountContributorRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '17d1049b-9a84-46fb-8f53-869881c3d3ab')
var cognitiveServicesUserRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'a97b65f3-24c7-4388-baec-2e87135dc908')
var openAiUserRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd')
var contributorRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b24988ac-6180-42a0-ab88-20f7382dd24c')

resource workloadStorage 'Microsoft.Storage/storageAccounts@2023-05-01' existing = {
  name: workloadStorageName
}

resource functionStorage 'Microsoft.Storage/storageAccounts@2023-05-01' existing = {
  name: functionStorageName
}

resource cosmos 'Microsoft.DocumentDB/databaseAccounts@2024-05-15' existing = {
  name: cosmosAccountName
}

resource foundry 'Microsoft.CognitiveServices/accounts@2025-06-01' existing = {
  name: foundryAccountName
}

resource openAi 'Microsoft.CognitiveServices/accounts@2025-06-01' existing = {
  name: openAiAccountName
}

resource documentIntelligence 'Microsoft.CognitiveServices/accounts@2025-06-01' existing = {
  name: documentIntelligenceAccountName
}

resource databricks 'Microsoft.Databricks/workspaces@2024-05-01' existing = {
  name: databricksWorkspaceName
}

resource functionStorageBlobOwner 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(functionStorage.id, functionPrincipalId, storageBlobDataOwnerRoleId)
  scope: functionStorage
  properties: {
    principalId: functionPrincipalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: storageBlobDataOwnerRoleId
  }
}

resource functionStorageQueueContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(functionStorage.id, functionPrincipalId, storageQueueDataContributorRoleId)
  scope: functionStorage
  properties: {
    principalId: functionPrincipalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: storageQueueDataContributorRoleId
  }
}

resource functionStorageTableContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(functionStorage.id, functionPrincipalId, storageTableDataContributorRoleId)
  scope: functionStorage
  properties: {
    principalId: functionPrincipalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: storageTableDataContributorRoleId
  }
}

resource functionStorageAccountContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(functionStorage.id, functionPrincipalId, storageAccountContributorRoleId)
  scope: functionStorage
  properties: {
    principalId: functionPrincipalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: storageAccountContributorRoleId
  }
}

resource functionWorkloadStorageContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(workloadStorage.id, functionPrincipalId, storageBlobDataContributorRoleId)
  scope: workloadStorage
  properties: {
    principalId: functionPrincipalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: storageBlobDataContributorRoleId
  }
}

resource dataFactoryStorageContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(workloadStorage.id, dataFactoryPrincipalId, storageBlobDataContributorRoleId)
  scope: workloadStorage
  properties: {
    principalId: dataFactoryPrincipalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: storageBlobDataContributorRoleId
  }
}

resource foundryStorageContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(workloadStorage.id, foundryProjectPrincipalId, storageBlobDataContributorRoleId)
  scope: workloadStorage
  properties: {
    principalId: foundryProjectPrincipalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: storageBlobDataContributorRoleId
  }
}

resource databricksStorageContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(workloadStorage.id, databricksAccessConnectorPrincipalId, storageBlobDataContributorRoleId)
  scope: workloadStorage
  properties: {
    principalId: databricksAccessConnectorPrincipalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: storageBlobDataContributorRoleId
  }
}

resource functionFoundryUser 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(foundry.id, functionPrincipalId, cognitiveServicesUserRoleId)
  scope: foundry
  properties: {
    principalId: functionPrincipalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: cognitiveServicesUserRoleId
  }
}

resource functionOpenAiUser 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(openAi.id, functionPrincipalId, openAiUserRoleId)
  scope: openAi
  properties: {
    principalId: functionPrincipalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: openAiUserRoleId
  }
}

resource functionDocumentIntelligenceUser 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(documentIntelligence.id, functionPrincipalId, cognitiveServicesUserRoleId)
  scope: documentIntelligence
  properties: {
    principalId: functionPrincipalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: cognitiveServicesUserRoleId
  }
}

resource dataFactoryDatabricksContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(databricks.id, dataFactoryPrincipalId, contributorRoleId)
  scope: databricks
  properties: {
    principalId: dataFactoryPrincipalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: contributorRoleId
  }
}

resource functionCosmosDataContributor 'Microsoft.DocumentDB/databaseAccounts/sqlRoleAssignments@2024-05-15' = {
  name: guid(cosmos.id, functionPrincipalId, 'cosmos-data-contributor')
  parent: cosmos
  properties: {
    principalId: functionPrincipalId
    roleDefinitionId: '${cosmos.id}/sqlRoleDefinitions/00000000-0000-0000-0000-000000000002'
    scope: cosmos.id
  }
}
