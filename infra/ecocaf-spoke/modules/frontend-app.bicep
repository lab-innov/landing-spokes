targetScope = 'resourceGroup'

param location string
param tags object = {}
param planName string
param appName string
param integrationSubnetResourceId string
param tenantId string
param authenticationClientId string
param allowedPrincipalIds array
@secure()
param applicationSettings object = {}
param enabled bool = false
param logAnalyticsWorkspaceResourceId string
param siemAuthorizationRuleId string
param siemEventHubName string

resource plan 'Microsoft.Web/serverfarms@2024-04-01' = {
  name: planName
  location: location
  tags: tags
  kind: 'linux'
  sku: {
    name: 'B1'
    tier: 'Basic'
    capacity: 1
  }
  properties: {
    reserved: true
    zoneRedundant: false
  }
}

resource app 'Microsoft.Web/sites@2024-04-01' = {
  name: appName
  location: location
  tags: tags
  kind: 'app,linux'
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
      linuxFxVersion: 'NODE|24-lts'
      minTlsVersion: '1.2'
      scmMinTlsVersion: '1.2'
      vnetRouteAllEnabled: true
      appSettings: [for setting in items(applicationSettings): {
        name: setting.key
        value: string(setting.value)
      }]
    }
  }
}

resource authSettings 'Microsoft.Web/sites/config@2024-04-01' = {
  name: 'authsettingsV2'
  parent: app
  properties: {
    platform: {
      enabled: true
      runtimeVersion: '~1'
    }
    globalValidation: {
      requireAuthentication: true
      unauthenticatedClientAction: 'RedirectToLoginPage'
      redirectToProvider: 'azureactivedirectory'
    }
    identityProviders: {
      azureActiveDirectory: {
        enabled: true
        registration: {
          clientId: authenticationClientId
          clientSecretSettingName: 'MICROSOFT_PROVIDER_AUTHENTICATION_SECRET'
          openIdIssuer: '${environment().authentication.loginEndpoint}${tenantId}/v2.0'
        }
        validation: {
          defaultAuthorizationPolicy: {
            allowedPrincipals: {
              identities: allowedPrincipalIds
            }
          }
          allowedAudiences: [
            'api://${authenticationClientId}'
          ]
        }
      }
    }
    login: {
      tokenStore: {
        enabled: true
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
  parent: app
  properties: {
    allow: false
  }
}
resource scmPolicy 'Microsoft.Web/sites/basicPublishingCredentialsPolicies@2024-04-01' = {
  name: 'scm'
  parent: app
  properties: {
    allow: false
  }
}

resource diagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'send-to-central-law'
  scope: app
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

output resourceId string = app.id
output name string = app.name
output hostname string = '${app.name}.azurewebsites.net'
output principalId string = app.identity.principalId
