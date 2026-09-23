param location string
param tags object
param token string
param subnetId string
param gatewaySubnetPrefix string
param frontendIdentityId string
param backendIdentityId string
param backendClientId string
param registryServer string
param projectEndpoint string
param blobEndpoint string
param vaultUri string
@description('Imágenes existentes en el ACR de este despliegue; usar digest o etiqueta inmutable.')
param frontendImage string
param backendImage string
param frontendPort int
param backendPort int
param deployApplications bool
param frontendEnv array
param backendEnv array
param workspaceId string
param siemAuthorizationRuleId string
param siemEventHubName string
param actionGroupId string

resource environment 'Microsoft.App/managedEnvironments@2025-01-01' = {
  name: 'cae-${token}'
  location: location
  tags: tags
  properties: {
    vnetConfiguration: { infrastructureSubnetId: subnetId, internal: true }
    workloadProfiles: [{ name: 'Consumption', workloadProfileType: 'Consumption' }]
    zoneRedundant: true
    appLogsConfiguration: { destination: 'azure-monitor' }
  }
}
resource backend 'Microsoft.App/containerApps@2025-01-01' = if (deployApplications) {
  name: 'backend-${token}'
  location: location
  tags: tags
  identity: { type: 'UserAssigned', userAssignedIdentities: { '${backendIdentityId}': {} } }
  properties: {
    managedEnvironmentId: environment.id
    workloadProfileName: 'Consumption'
    configuration: {
      activeRevisionsMode: 'Single'
      ingress: { external: false, targetPort: backendPort, transport: 'auto', allowInsecure: false }
      registries: [{ server: registryServer, identity: backendIdentityId }]
    }
    template: {
      containers: [
        {
          name: 'backend'
          image: backendImage
          resources: { cpu: json('0.5'), memory: '1Gi' }
          env: concat(
            [
              { name: 'AZURE_CLIENT_ID', value: backendClientId }
              { name: 'AZURE_AI_PROJECT_ENDPOINT', value: projectEndpoint }
              { name: 'AZURE_STORAGE_BLOB_ENDPOINT', value: blobEndpoint }
              { name: 'AZURE_STORAGE_CONTAINER', value: 'uploads' }
              { name: 'AZURE_KEY_VAULT_URL', value: vaultUri }
            ],
            backendEnv
          )
        }
      ]
      scale: { minReplicas: 2, maxReplicas: 3 }
    }
  }
}
resource frontend 'Microsoft.App/containerApps@2025-01-01' = if (deployApplications) {
  name: 'frontend-${token}'
  location: location
  tags: tags
  identity: { type: 'UserAssigned', userAssignedIdentities: { '${frontendIdentityId}': {} } }
  properties: {
    managedEnvironmentId: environment.id
    workloadProfileName: 'Consumption'
    configuration: {
      activeRevisionsMode: 'Single'
      // external=true expone a la VNet; el entorno sigue siendo interno.
      ingress: {
        external: true
        targetPort: frontendPort
        transport: 'auto'
        allowInsecure: false
        ipSecurityRestrictions: [{ name: 'solo-appgateway', action: 'Allow', ipAddressRange: gatewaySubnetPrefix }]
      }
      registries: [{ server: registryServer, identity: frontendIdentityId }]
    }
    template: {
      containers: [
        {
          name: 'frontend'
          image: frontendImage
          resources: { cpu: json('0.5'), memory: '1Gi' }
          env: concat(
            [{ name: 'BACKEND_URL', value: 'https://${backend!.properties.configuration.ingress.fqdn}' }],
            frontendEnv
          )
        }
      ]
      scale: { minReplicas: 2, maxReplicas: 3 }
    }
  }
}
output frontendFqdn string = deployApplications ? frontend!.properties.configuration.ingress.fqdn : ''
output environmentDomain string = environment.properties.defaultDomain
output environmentIp string = environment.properties.staticIp


resource diagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'auditoria-caf'
  scope: environment
  properties: {
    workspaceId: workspaceId
    eventHubAuthorizationRuleId: empty(siemAuthorizationRuleId) ? null : siemAuthorizationRuleId
    eventHubName: empty(siemEventHubName) ? null : siemEventHubName
    logs: [{ categoryGroup: 'allLogs', enabled: true }]
  }
}

resource cpuAlerts 'Microsoft.Insights/metricAlerts@2018-03-01' = [for appName in ['frontend', 'backend']: if (deployApplications) {
  name: 'alerta-cpu-${appName}-${token}'
  location: 'global'
  tags: tags
  properties: {
    description: 'Consumo sostenido superior a 450 millicores por aplicación.'
    severity: 2
    enabled: true
    scopes: [resourceId('Microsoft.App/containerApps', '${appName}-${token}')]
    evaluationFrequency: 'PT1M'
    windowSize: 'PT5M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [{ name: 'cpu', criterionType: 'StaticThresholdCriterion', metricNamespace: 'Microsoft.App/containerApps', metricName: 'UsageNanoCores', operator: 'GreaterThan', threshold: 450000000, timeAggregation: 'Average' }]
    }
    actions: [{ actionGroupId: actionGroupId }]
  }
  dependsOn: [frontend, backend]
}]
