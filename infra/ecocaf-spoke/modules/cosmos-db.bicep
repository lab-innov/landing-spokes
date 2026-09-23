targetScope = 'resourceGroup'

param location string
param tags object = {}
param accountName string
param logAnalyticsWorkspaceResourceId string
param siemAuthorizationRuleId string
param siemEventHubName string

resource account 'Microsoft.DocumentDB/databaseAccounts@2024-05-15' = {
  name: accountName
  location: location
  tags: tags
  kind: 'GlobalDocumentDB'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    databaseAccountOfferType: 'Standard'
    disableKeyBasedMetadataWriteAccess: true
    disableLocalAuth: true
    enableAutomaticFailover: false
    enableFreeTier: false
    minimalTlsVersion: 'Tls12'
    publicNetworkAccess: 'Disabled'
    networkAclBypass: 'None'
    locations: [
      {
        locationName: location
        failoverPriority: 0
        isZoneRedundant: false
      }
    ]
    capabilities: [
      {
        name: 'EnableServerless'
      }
    ]
    consistencyPolicy: {
      defaultConsistencyLevel: 'Session'
    }
    backupPolicy: {
      type: 'Continuous'
      continuousModeProperties: {
        tier: 'Continuous7Days'
      }
    }
  }
}

var databaseDefinitions = [
  {
    name: 'EcoCAF'
    containers: [
      'Documents'
      'Proyectos'
    ]
  }
  {
    name: 'Auditoria'
    containers: [
      'Logs'
    ]
  }
]

resource databases 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2024-05-15' = [for definition in databaseDefinitions: {
  name: definition.name
  parent: account
  properties: {
    resource: {
      id: definition.name
    }
  }
}]

var containerDefinitions = [
  {
    databaseIndex: 0
    name: 'Documents'
  }
  {
    databaseIndex: 0
    name: 'Proyectos'
  }
  {
    databaseIndex: 1
    name: 'Logs'
  }
]

resource containers 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2024-05-15' = [for item in containerDefinitions: {
  name: item.name
  parent: databases[item.databaseIndex]
  properties: {
    resource: {
      id: item.name
      partitionKey: {
        paths: [
          '/id'
        ]
        kind: 'Hash'
        version: 2
      }
      indexingPolicy: {
        automatic: true
        indexingMode: 'consistent'
        includedPaths: [
          {
            path: '/*'
          }
        ]
        excludedPaths: [
          {
            path: '/"_etag"/?'
          }
        ]
      }
      conflictResolutionPolicy: {
        mode: 'LastWriterWins'
        conflictResolutionPath: '/_ts'
      }
    }
  }
}]

resource diagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'send-to-central-law'
  scope: account
  properties: {
    workspaceId: logAnalyticsWorkspaceResourceId
    eventHubAuthorizationRuleId: empty(siemAuthorizationRuleId) ? null : siemAuthorizationRuleId
    eventHubName: empty(siemEventHubName) ? null : siemEventHubName
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

output resourceId string = account.id
output name string = account.name
output principalId string = account.identity.principalId
