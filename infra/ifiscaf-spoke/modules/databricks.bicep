targetScope = 'resourceGroup'

param location string
param tags object = {}
param workspaceName string
param accessConnectorName string
param vnetResourceId string
param publicSubnetName string
param privateSubnetName string
param managedResourceGroupName string
param logAnalyticsWorkspaceResourceId string

resource workspace 'Microsoft.Databricks/workspaces@2024-05-01' = {
  name: workspaceName
  location: location
  tags: tags
  sku: {
    name: 'premium'
  }
  properties: {
    managedResourceGroupId: subscriptionResourceId('Microsoft.Resources/resourceGroups', managedResourceGroupName)
    publicNetworkAccess: 'Disabled'
    requiredNsgRules: 'AllRules'
    parameters: {
      customVirtualNetworkId: {
        value: vnetResourceId
      }
      customPublicSubnetName: {
        value: publicSubnetName
      }
      customPrivateSubnetName: {
        value: privateSubnetName
      }
      enableNoPublicIp: {
        value: true
      }
    }
  }
}

resource accessConnector 'Microsoft.Databricks/accessConnectors@2023-05-01' = {
  name: accessConnectorName
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {}
}

resource diagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'send-to-central-law'
  scope: workspace
  properties: {
    workspaceId: logAnalyticsWorkspaceResourceId
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
      }
    ]
    metrics: []
  }
}

output resourceId string = workspace.id
output name string = workspace.name
output workspaceUrl string = workspace.properties.workspaceUrl
output accessConnectorResourceId string = accessConnector.id
output accessConnectorPrincipalId string = accessConnector.identity.principalId
