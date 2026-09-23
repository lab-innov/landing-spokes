targetScope = 'resourceGroup'

param location string
param tags object = {}
param planName string
param functionAppName string
param hostStorageAccountName string
param businessStorageAccountName string
@secure()
param applicationSettings object = {}
param allowedOrigins array = []
param enabled bool = false
param integrationSubnetResourceId string
param tenantId string
param authenticationClientId string
param allowedPrincipalIds array
param actionGroupResourceId string
param requestsAlertThreshold int
param logAnalyticsWorkspaceResourceId string
param siemAuthorizationRuleId string
param siemEventHubName string

resource plan 'Microsoft.Web/serverfarms@2024-04-01' = {
  name: planName
  location: location
  tags: tags
  kind: 'linux'
  sku: {
    name: 'P1v3'
    tier: 'PremiumV3'
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
    enabled: enabled
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
      cors: {
        allowedOrigins: allowedOrigins
        supportCredentials: false
      }
      appSettings: [for setting in items(union(applicationSettings, {
        AzureWebJobsStorage__accountName: hostStorageAccountName
        AzureWebJobsStorage__credential: 'managedidentity'
        BLOB_STORAGE_CONNECTION_STRING__blobServiceUri: 'https://${businessStorageAccountName}.blob.${environment().suffixes.storage}'
        BLOB_STORAGE_CONNECTION_STRING__queueServiceUri: 'https://${businessStorageAccountName}.queue.${environment().suffixes.storage}'
        BLOB_STORAGE_CONNECTION_STRING__credential: 'managedidentity'
        FUNCTIONS_EXTENSION_VERSION: '~4'
        FUNCTIONS_WORKER_RUNTIME: 'python'
      })): {
        name: setting.key
        value: string(setting.value)
      }]
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
          defaultAuthorizationPolicy: { allowedPrincipals: { identities: allowedPrincipalIds } }
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

output resourceId string = functionApp.id
output name string = functionApp.name
output hostname string = '${functionApp.name}.azurewebsites.net'
output principalId string = functionApp.identity.principalId

resource operationalAlerts 'Microsoft.Insights/metricAlerts@2018-03-01' = [for alert in [
  { name: 'errores-http', metric: 'Http5xx', threshold: 5, severity: 2 }
  { name: 'volumen-solicitudes', metric: 'Requests', threshold: requestsAlertThreshold, severity: 3 }
]: if (!empty(actionGroupResourceId)) {
  name: '${functionAppName}-${alert.name}'
  location: 'global'
  tags: tags
  properties: {
    enabled: true
    severity: alert.severity
    scopes: [functionApp.id]
    evaluationFrequency: 'PT1M'
    windowSize: 'PT5M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [{ name: alert.name, metricName: alert.metric, metricNamespace: 'Microsoft.Web/sites', operator: 'GreaterThan', threshold: alert.threshold, timeAggregation: 'Total', criterionType: 'StaticThresholdCriterion' }]
    }
    actions: [{ actionGroupId: actionGroupResourceId }]
  }
}]
