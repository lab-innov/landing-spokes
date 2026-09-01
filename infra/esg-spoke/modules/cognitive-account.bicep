targetScope = 'resourceGroup'

param location string
param tags object = {}
param accountName string
param kind string
param modelDeployments array = []
param logAnalyticsWorkspaceResourceId string

resource account 'Microsoft.CognitiveServices/accounts@2025-06-01' = {
  name: accountName
  location: location
  tags: tags
  kind: kind
  identity: {
    type: 'SystemAssigned'
  }
  sku: {
    name: 'S0'
  }
  properties: {
    customSubDomainName: toLower(accountName)
    disableLocalAuth: true
    publicNetworkAccess: 'Disabled'
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
      ipRules: []
      virtualNetworkRules: []
    }
  }
}

resource deployments 'Microsoft.CognitiveServices/accounts/deployments@2024-10-01' = [for deployment in modelDeployments: {
  name: deployment.name
  parent: account
  sku: {
    name: deployment.sku
    capacity: deployment.capacity
  }
  properties: {
    model: {
      format: 'OpenAI'
      name: deployment.model
      version: deployment.version
    }
    raiPolicyName: deployment.raiPolicy
    versionUpgradeOption: 'OnceNewDefaultVersionAvailable'
  }
}]

resource diagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'send-to-central-law'
  scope: account
  properties: {
    workspaceId: logAnalyticsWorkspaceResourceId
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
