targetScope = 'resourceGroup'

param location string
param tags object = {}
param planName string
param functionAppName string
param hostStorageAccountName string
param workloadStorageAccountName string
param sourceContainerName string = 'source'
param documentsContainerName string = 'sypdocuments'
param cosmosAccountName string
param cosmosDatabaseName string = 'IfisCAF'
param cosmosContainerName string = 'Reportes'
param openAiAccountName string
param openAiDeploymentName string
param documentIntelligenceAccountName string
param integrationSubnetResourceId string
param tenantId string
param authenticationClientId string
param logAnalyticsWorkspaceResourceId string

resource plan 'Microsoft.Web/serverfarms@2024-04-01' = {
  name: planName
  location: location
  tags: tags
  kind: 'linux'
  sku: {
    name: 'P1v4'
    tier: 'PremiumV4'
    capacity: 1
  }
  properties: {
    reserved: true
    zoneRedundant: false
  }
}

resource functionApp 'Microsoft.Web/sites@2024-04-01' = {
  name: functionAppName
  location: location
  tags: tags
  kind: 'functionapp,linux'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: plan.id
    httpsOnly: true
    publicNetworkAccess: 'Disabled'
    virtualNetworkSubnetId: integrationSubnetResourceId
    clientCertEnabled: false
    siteConfig: {
      alwaysOn: true
      ftpsState: 'Disabled'
      http20Enabled: true
      linuxFxVersion: 'Python|3.13'
      minTlsVersion: '1.2'
      scmMinTlsVersion: '1.2'
      vnetRouteAllEnabled: true
      appSettings: [
        {
          name: 'AzureWebJobsStorage__accountName'
          value: hostStorageAccountName
        }
        {
          name: 'AzureWebJobsStorage__credential'
          value: 'managedidentity'
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'python'
        }
        {
          name: 'BLOB_STORAGE_ACCOUNT_URL'
          value: 'https://${workloadStorageAccountName}.blob.${environment().suffixes.storage}'
        }
        {
          name: 'BLOB_STORAGE_CONTAINER_NAME'
          value: documentsContainerName
        }
        {
          name: 'BLOB_STORAGE_SOURCE_CONTAINER_NAME'
          value: sourceContainerName
        }
        {
          name: 'COSMOS_DB_ENDPOINT'
          value: 'https://${cosmosAccountName}.documents.azure.com:443/'
        }
        {
          name: 'COSMOS_DB_DATABASE'
          value: cosmosDatabaseName
        }
        {
          name: 'COSMOS_DB_CONTAINER'
          value: cosmosContainerName
        }
        {
          name: 'AZURE_OPENAI_ENDPOINT'
          value: 'https://${openAiAccountName}.openai.azure.com/'
        }
        {
          name: 'AZURE_OPENAI_DEPLOYMENT'
          value: openAiDeploymentName
        }
        {
          name: 'DOCUMENT_INTELLIGENCE_ENDPOINT'
          value: 'https://${documentIntelligenceAccountName}.cognitiveservices.azure.com/'
        }
      ]
    }
  }
}

resource authSettings 'Microsoft.Web/sites/config@2024-04-01' = {
  name: 'authsettingsV2'
  parent: functionApp
  properties: {
    platform: {
      enabled: true
      runtimeVersion: '~1'
    }
    globalValidation: {
      requireAuthentication: true
      unauthenticatedClientAction: 'Return401'
    }
    identityProviders: {
      azureActiveDirectory: {
        enabled: true
        registration: {
          clientId: authenticationClientId
          openIdIssuer: '${environment().authentication.loginEndpoint}${tenantId}/v2.0'
        }
        validation: {
          allowedAudiences: [
            'api://${authenticationClientId}'
          ]
        }
      }
    }
    httpSettings: {
      requireHttps: true
      routes: {
        apiPrefix: '/.auth'
      }
    }
  }
}

resource ftpPolicy 'Microsoft.Web/sites/basicPublishingCredentialsPolicies@2024-04-01' = {
  name: 'ftp'
  parent: functionApp
  properties: {
    allow: false
  }
}

resource scmPolicy 'Microsoft.Web/sites/basicPublishingCredentialsPolicies@2024-04-01' = {
  name: 'scm'
  parent: functionApp
  properties: {
    allow: false
  }
}

resource diagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'send-to-central-law'
  scope: functionApp
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

output resourceId string = functionApp.id
output name string = functionApp.name
output hostname string = '${functionApp.name}.azurewebsites.net'
output principalId string = functionApp.identity.principalId
