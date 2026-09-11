targetScope = 'resourceGroup'

param location string
param tags object = {}
param accountName string
param projectName string
param agentSubnetResourceId string
param modelDeployments array
param deployGroundingWithBing bool
param groundingName string
param groundingConnectionName string
param groundingComplianceExceptionId string
param logAnalyticsWorkspaceResourceId string
param siemAuthorizationRuleId string
param siemEventHubName string

resource account 'Microsoft.CognitiveServices/accounts@2025-06-01' = {
  name: accountName
  location: location
  tags: union(tags, deployGroundingWithBing ? {
    GroundingComplianceException: groundingComplianceExceptionId
  } : {})
  kind: 'AIServices'
  identity: {
    type: 'SystemAssigned'
  }
  sku: {
    name: 'S0'
  }
  properties: {
    allowProjectManagement: true
    customSubDomainName: toLower(accountName)
    disableLocalAuth: true
    publicNetworkAccess: 'Disabled'
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
      ipRules: []
      virtualNetworkRules: []
    }
    networkInjections: [
      {
        scenario: 'agent'
        subnetArmId: agentSubnetResourceId
        useMicrosoftManagedNetwork: false
      }
    ]
  }
}

resource project 'Microsoft.CognitiveServices/accounts/projects@2025-06-01' = {
  name: projectName
  parent: account
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    description: 'Proyecto Foundry privado de ESG'
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
    versionUpgradeOption: 'NoAutoUpgrade'
  }
}]

#disable-next-line BCP081
resource grounding 'Microsoft.Bing/accounts@2025-05-01-preview' = if (deployGroundingWithBing) {
  name: groundingName
  location: 'global'
  tags: union(tags, {
    GroundingComplianceException: groundingComplianceExceptionId
  })
  kind: 'Bing.Grounding'
  sku: {
    name: 'G1'
  }
}

#disable-next-line BCP081
resource groundingConnection 'Microsoft.CognitiveServices/accounts/projects/connections@2025-06-01' = if (deployGroundingWithBing) {
  name: groundingConnectionName
  parent: project
  properties: {
    category: 'GroundingWithBingSearch'
    target: grounding!.properties.endpoint
    authType: 'ApiKey'
    credentials: {
      key: grounding!.listKeys().key1
    }
    isSharedToAll: false
    metadata: {
      ApiType: 'Azure'
      Location: grounding!.location
      ResourceId: grounding!.id
    }
  }
}

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

output accountResourceId string = account.id
output accountName string = account.name
output accountPrincipalId string = account.identity.principalId
output projectResourceId string = project.id
output projectPrincipalId string = project.identity.principalId
output projectEndpoint string = 'https://${account.name}.services.ai.azure.com/api/projects/${project.name}'
output groundingResourceId string = deployGroundingWithBing ? grounding!.id : ''
output groundingConnectionId string = deployGroundingWithBing ? groundingConnection!.id : ''
