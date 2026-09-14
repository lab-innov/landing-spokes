param accountName string
param projectPrincipalId string
param storageName string
param cosmosName string
param searchName string
resource account 'Microsoft.CognitiveServices/accounts@2026-01-15-preview' existing = { name: accountName }
resource project 'Microsoft.CognitiveServices/accounts/projects@2025-04-01-preview' existing = {
  parent: account
  name: 'agents'
}
resource storage 'Microsoft.Storage/storageAccounts@2023-05-01' existing = { name: storageName }
resource cosmos 'Microsoft.DocumentDB/databaseAccounts@2024-11-15' existing = { name: cosmosName }
resource search 'Microsoft.Search/searchServices@2024-03-01-preview' existing = { name: searchName }
resource storageConnection 'Microsoft.CognitiveServices/accounts/projects/connections@2025-04-01-preview' = {
  parent: project
  name: 'agent-storage'
  properties: {
    category: 'AzureStorageAccount'
    target: storage.properties.primaryEndpoints.blob
    authType: 'AAD'
    metadata: { ApiType: 'Azure', ResourceId: storage.id, location: storage.location }
  }
}
resource cosmosConnection 'Microsoft.CognitiveServices/accounts/projects/connections@2025-04-01-preview' = {
  parent: project
  name: 'agent-threads'
  properties: {
    category: 'CosmosDB'
    target: cosmos.properties.documentEndpoint
    authType: 'AAD'
    metadata: { ApiType: 'Azure', ResourceId: cosmos.id, location: cosmos.location }
  }
}
resource searchConnection 'Microsoft.CognitiveServices/accounts/projects/connections@2025-04-01-preview' = {
  parent: project
  name: 'agent-vectors'
  properties: {
    category: 'CognitiveSearch'
    target: 'https://${search.name}.search.windows.net'
    authType: 'AAD'
    metadata: { ApiType: 'Azure', ResourceId: search.id, location: search.location }
  }
}
resource capability 'Microsoft.CognitiveServices/accounts/projects/capabilityHosts@2025-04-01-preview' = {
  parent: project
  name: 'agents'
  properties: {
    // La API exige este campo; el esquema Bicep aún no lo incluye (muestra oficial 15).
    #disable-next-line BCP037
    capabilityHostKind: 'Agents'
    storageConnections: [storageConnection.name]
    threadStorageConnections: [cosmosConnection.name]
    vectorStoreConnections: [searchConnection.name]
  }
}
resource cosmosData 'Microsoft.DocumentDB/databaseAccounts/sqlRoleAssignments@2024-11-15' = {
  parent: cosmos
  name: guid(cosmos.id, projectPrincipalId, 'threads-data')
  properties: {
    principalId: projectPrincipalId
    roleDefinitionId: '${cosmos.id}/sqlRoleDefinitions/00000000-0000-0000-0000-000000000002'
    scope: '${cosmos.id}/dbs/enterprise_memory'
  }
  dependsOn: [capability]
}
