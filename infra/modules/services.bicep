param location string
param tags object
@minLength(13)
@maxLength(13)
param token string
param foundrySubnetId string
param backendPrincipalId string
param frontendPrincipalId string
@description('Despliegues de modelos aprobados: name, model, version, sku, capacity.')
param models array
param workspaceId string
param siemAuthorizationRuleId string
param siemEventHubName string

resource storage 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: 'st${token}'
  location: location
  tags: tags
  kind: 'StorageV2'
  sku: { name: 'Standard_ZRS' }
  properties: {
    allowBlobPublicAccess: false
    allowSharedKeyAccess: false
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    publicNetworkAccess: 'Disabled'
    networkAcls: { defaultAction: 'Deny', bypass: 'None' }
  }
}
resource blob 'Microsoft.Storage/storageAccounts/blobServices@2023-05-01' = {
  parent: storage
  name: 'default'
  properties: {
    isVersioningEnabled: true
    deleteRetentionPolicy: { enabled: true, days: 14 }
    containerDeleteRetentionPolicy: { enabled: true, days: 14 }
  }
}
resource uploads 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = {
  parent: blob
  name: 'uploads'
  properties: { publicAccess: 'None' }
}
resource vault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: 'kv-${token}'
  location: location
  tags: tags
  properties: {
    tenantId: tenant().tenantId
    sku: { family: 'A', name: 'standard' }
    enableRbacAuthorization: true
    enableSoftDelete: true
    enablePurgeProtection: true
    softDeleteRetentionInDays: 90
    publicNetworkAccess: 'Disabled'
    accessPolicies: []
    networkAcls: { defaultAction: 'Deny', bypass: 'None' }
  }
}
resource registry 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: 'acr${token}'
  location: location
  tags: tags
  sku: { name: 'Premium' }
  properties: {
    adminUserEnabled: false
    publicNetworkAccess: 'Disabled'
    networkRuleBypassOptions: 'AzureServices'
  }
}
resource foundry 'Microsoft.CognitiveServices/accounts@2026-01-15-preview' = {
  name: 'aif-${token}'
  location: location
  tags: tags
  kind: 'AIServices'
  sku: { name: 'S0' }
  identity: { type: 'SystemAssigned' }
  properties: {
    allowProjectManagement: true
    customSubDomainName: 'aif-${token}'
    disableLocalAuth: true
    publicNetworkAccess: 'Disabled'
    networkAcls: { defaultAction: 'Deny', bypass: 'None' }
    networkInjections: [{ scenario: 'agent', subnetArmId: foundrySubnetId, useMicrosoftManagedNetwork: false }]
  }
}
resource project 'Microsoft.CognitiveServices/accounts/projects@2025-04-01-preview' = {
  parent: foundry
  name: 'agents'
  location: location
  tags: tags
  identity: { type: 'SystemAssigned' }
  properties: { displayName: 'Agentes CAF', description: 'Aplicación de agentes sin RAG' }
}
@batchSize(1)
resource deployments 'Microsoft.CognitiveServices/accounts/deployments@2025-06-01' = [
  for model in models: {
    parent: foundry
    name: model.name
    sku: { name: model.sku, capacity: model.capacity }
    properties: {
      model: { format: 'OpenAI', name: model.model, version: model.version }
      versionUpgradeOption: 'NoAutoUpgrade'
    }
  }
]
resource blobRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(uploads.id, backendPrincipalId, 'blob-contributor')
  scope: uploads
  properties: {
    principalId: backendPrincipalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
    )
  }
}
resource foundryRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(project.id, backendPrincipalId, 'foundry-user')
  scope: project
  properties: {
    principalId: backendPrincipalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      '53ca6127-db72-4b80-b1b0-d745d6d5456d'
    )
  }
}
resource acrRoles 'Microsoft.Authorization/roleAssignments@2022-04-01' = [
  for principal in [frontendPrincipalId, backendPrincipalId]: {
    name: guid(registry.id, principal, 'acr-pull')
    scope: registry
    properties: {
      principalId: principal
      principalType: 'ServicePrincipal'
      roleDefinitionId: subscriptionResourceId(
        'Microsoft.Authorization/roleDefinitions',
        '7f951dda-4ed3-4680-a7ca-43fe172d538d'
      )
    }
  }
]
output targets array = [
  { name: 'foundry', id: foundry.id, group: 'account' }
  { name: 'blob', id: storage.id, group: 'blob' }
  { name: 'vault', id: vault.id, group: 'vault' }
  { name: 'acr', id: registry.id, group: 'registry' }
  { name: 'agentBlob', id: agentStorage.id, group: 'blob' }
  { name: 'cosmos', id: cosmos.id, group: 'Sql' }
  { name: 'search', id: search.id, group: 'searchService' }
]
output registryServer string = registry.properties.loginServer
output registryId string = registry.id
output vaultUri string = vault.properties.vaultUri
output blobEndpoint string = storage.properties.primaryEndpoints.blob
output projectId string = project.id
output projectEndpoint string = 'https://${foundry.properties.customSubDomainName}.services.ai.azure.com/api/projects/${project.name}'
output accountName string = foundry.name
output projectPrincipalId string = project.identity.principalId
output agentStorageName string = agentStorage.name
output cosmosName string = cosmos.name
output searchName string = search.name

// Persistencia exclusiva del servicio Foundry Standard, separada de uploads.
resource agentStorage 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: 'stag${token}'
  location: location
  tags: tags
  kind: 'StorageV2'
  sku: { name: 'Standard_ZRS' }
  properties: {
    allowBlobPublicAccess: false
    allowSharedKeyAccess: false
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    publicNetworkAccess: 'Disabled'
    networkAcls: { defaultAction: 'Deny', bypass: 'None' }
  }
}
resource cosmos 'Microsoft.DocumentDB/databaseAccounts@2024-11-15' = {
  name: 'cosmos-${token}'
  location: location
  tags: tags
  kind: 'GlobalDocumentDB'
  properties: {
    databaseAccountOfferType: 'Standard'
    disableLocalAuth: true
    publicNetworkAccess: 'Disabled'
    consistencyPolicy: { defaultConsistencyLevel: 'Session' }
    locations: [{ locationName: location, failoverPriority: 0, isZoneRedundant: true }]
    backupPolicy: { type: 'Continuous', continuousModeProperties: { tier: 'Continuous7Days' } }
  }
}
resource search 'Microsoft.Search/searchServices@2024-03-01-preview' = {
  name: 'srch-${token}'
  location: location
  tags: tags
  sku: { name: 'standard' }
  properties: {
    publicNetworkAccess: 'disabled'
    disableLocalAuth: true
    replicaCount: 3
    partitionCount: 1
    hostingMode: 'default'
    semanticSearch: 'disabled'
  }
}
resource agentStorageRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(agentStorage.id, project.id, 'blob-owner')
  scope: agentStorage
  properties: {
    principalId: project.identity.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      'b7e6dc6d-f1e8-4753-8033-0f276bb0955b'
    )
  }
}
resource cosmosOperator 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(cosmos.id, project.id, 'cosmos-operator')
  scope: cosmos
  properties: {
    principalId: project.identity.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      '230815da-be43-4aae-9cb4-875f7bd000aa'
    )
  }
}
resource searchRoles 'Microsoft.Authorization/roleAssignments@2022-04-01' = [
  for role in ['8ebe5a00-799e-43f5-93ac-243d3dce84a7', '7ca78c08-252a-4471-8644-bb5ff32d4ba0']: {
    name: guid(search.id, project.id, role)
    scope: search
    properties: {
      principalId: project.identity.principalId
      principalType: 'ServicePrincipal'
      roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', role)
    }
  }
]

resource foundryDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'auditoria-caf'
  scope: foundry
  properties: {
    workspaceId: workspaceId
    eventHubAuthorizationRuleId: empty(siemAuthorizationRuleId) ? null : siemAuthorizationRuleId
    eventHubName: empty(siemEventHubName) ? null : siemEventHubName
    logs: [{ categoryGroup: 'allLogs', enabled: true }]
  }
}

resource storageDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'auditoria-caf'
  scope: blob
  properties: {
    workspaceId: workspaceId
    eventHubAuthorizationRuleId: empty(siemAuthorizationRuleId) ? null : siemAuthorizationRuleId
    eventHubName: empty(siemEventHubName) ? null : siemEventHubName
    logs: [{ categoryGroup: 'allLogs', enabled: true }]
  }
}

resource agentBlobService 'Microsoft.Storage/storageAccounts/blobServices@2023-05-01' existing = {
  parent: agentStorage
  name: 'default'
}

resource agentStorageDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'auditoria-caf'
  scope: agentBlobService
  properties: {
    workspaceId: workspaceId
    eventHubAuthorizationRuleId: empty(siemAuthorizationRuleId) ? null : siemAuthorizationRuleId
    eventHubName: empty(siemEventHubName) ? null : siemEventHubName
    logs: [{ categoryGroup: 'allLogs', enabled: true }]
  }
}

resource vaultDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'auditoria-caf'
  scope: vault
  properties: {
    workspaceId: workspaceId
    eventHubAuthorizationRuleId: empty(siemAuthorizationRuleId) ? null : siemAuthorizationRuleId
    eventHubName: empty(siemEventHubName) ? null : siemEventHubName
    logs: [{ categoryGroup: 'allLogs', enabled: true }]
  }
}

resource registryDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'auditoria-caf'
  scope: registry
  properties: {
    workspaceId: workspaceId
    eventHubAuthorizationRuleId: empty(siemAuthorizationRuleId) ? null : siemAuthorizationRuleId
    eventHubName: empty(siemEventHubName) ? null : siemEventHubName
    logs: [{ categoryGroup: 'allLogs', enabled: true }]
  }
}

resource cosmosDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'auditoria-caf'
  scope: cosmos
  properties: {
    workspaceId: workspaceId
    eventHubAuthorizationRuleId: empty(siemAuthorizationRuleId) ? null : siemAuthorizationRuleId
    eventHubName: empty(siemEventHubName) ? null : siemEventHubName
    logs: [{ categoryGroup: 'allLogs', enabled: true }]
  }
}

resource searchDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'auditoria-caf'
  scope: search
  properties: {
    workspaceId: workspaceId
    eventHubAuthorizationRuleId: empty(siemAuthorizationRuleId) ? null : siemAuthorizationRuleId
    eventHubName: empty(siemEventHubName) ? null : siemEventHubName
    logs: [{ categoryGroup: 'allLogs', enabled: true }]
  }
}

resource storageProtection 'Microsoft.Security/defenderForStorageSettings@2025-06-01' = {
  name: 'current'
  scope: storage
  properties: {
    isEnabled: true
    overrideSubscriptionLevelSettings: false
  }
}
resource agentStorageProtection 'Microsoft.Security/defenderForStorageSettings@2025-06-01' = {
  name: 'current'
  scope: agentStorage
  properties: { isEnabled: true, overrideSubscriptionLevelSettings: false }
}
output vaultName string = vault.name
output securityResourceIds object = {
  storage: storage.id
  agentStorage: agentStorage.id
  vault: vault.id
  registry: registry.id
  cosmos: cosmos.id
  foundry: foundry.id
}
