targetScope = 'resourceGroup'

param location string
param tags object = {}
param factoryName string
param workloadStorageResourceId string
param databricksWorkspaceResourceId string
param logAnalyticsWorkspaceResourceId string
param siemAuthorizationRuleId string
param siemEventHubName string

resource factory 'Microsoft.DataFactory/factories@2018-06-01' = {
  name: factoryName
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    publicNetworkAccess: 'Disabled'
  }
}

resource managedVnet 'Microsoft.DataFactory/factories/managedVirtualNetworks@2018-06-01' = {
  name: 'default'
  parent: factory
  properties: {}
}

resource autoResolveIr 'Microsoft.DataFactory/factories/integrationRuntimes@2018-06-01' = {
  name: 'AutoResolveIntegrationRuntime'
  parent: factory
  properties: {
    type: 'Managed'
    typeProperties: {
      computeProperties: {
        location: 'AutoResolve'
        dataFlowProperties: {
          computeType: 'General'
          coreCount: 8
          timeToLive: 0
        }
      }
    }
    managedVirtualNetwork: {
      referenceName: managedVnet.name
      type: 'ManagedVirtualNetworkReference'
    }
  }
}

resource storageManagedPrivateEndpoint 'Microsoft.DataFactory/factories/managedVirtualNetworks/managedPrivateEndpoints@2018-06-01' = {
  name: 'workload-storage-blob'
  parent: managedVnet
  properties: {
    privateLinkResourceId: workloadStorageResourceId
    groupId: 'blob'
  }
}

resource databricksManagedPrivateEndpoint 'Microsoft.DataFactory/factories/managedVirtualNetworks/managedPrivateEndpoints@2018-06-01' = {
  name: 'databricks-ui-api'
  parent: managedVnet
  properties: {
    privateLinkResourceId: databricksWorkspaceResourceId
    groupId: 'databricks_ui_api'
  }
}

resource diagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'send-to-central-law'
  scope: factory
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

output resourceId string = factory.id
output name string = factory.name
output principalId string = factory.identity.principalId
