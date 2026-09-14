param location string
param tags object
param token string
param subnetId string
param privateIp string
param hostname string
param backendFqdn string
param identityId string
@description('URI sin versión del secreto; no contiene el certificado ni credenciales.')
#disable-next-line secure-secrets-in-params
param certificateSecretId string
param healthPath string
param workspaceId string
param siemAuthorizationRuleId string
param siemEventHubName string
param actionGroupId string
var gatewayId = resourceId('Microsoft.Network/applicationGateways', 'agw-${token}')
resource waf 'Microsoft.Network/ApplicationGatewayWebApplicationFirewallPolicies@2024-05-01' = {
  name: 'waf-${token}'
  location: location
  tags: tags
  properties: {
    policySettings: { state: 'Enabled', mode: 'Prevention' }
    managedRules: { managedRuleSets: [{ ruleSetType: 'OWASP', ruleSetVersion: '3.2' }] }
  }
}
resource gateway 'Microsoft.Network/applicationGateways@2024-05-01' = {
  name: 'agw-${token}'
  location: location
  zones: ['1', '2', '3']
  tags: tags
  identity: { type: 'UserAssigned', userAssignedIdentities: { '${identityId}': {} } }
  properties: {
    sku: { name: 'WAF_v2', tier: 'WAF_v2' }
    autoscaleConfiguration: { minCapacity: 2, maxCapacity: 3 }
    enableHttp2: true
    firewallPolicy: { id: waf.id }
    sslPolicy: { policyType: 'Predefined', policyName: 'AppGwSslPolicy20220101S' }
    gatewayIPConfigurations: [{ name: 'network', properties: { subnet: { id: subnetId } } }]
    frontendIPConfigurations: [
      {
        name: 'private'
        properties: { privateIPAddress: privateIp, privateIPAllocationMethod: 'Static', subnet: { id: subnetId } }
      }
    ]
    frontendPorts: [{ name: 'https', properties: { port: 443 } }]
    sslCertificates: [{ name: 'caf', properties: { keyVaultSecretId: certificateSecretId } }]
    backendAddressPools: [{ name: 'frontend', properties: { backendAddresses: [{ fqdn: backendFqdn }] } }]
    probes: [
      {
        name: 'frontend-health'
        properties: {
          protocol: 'Https'
          path: healthPath
          pickHostNameFromBackendHttpSettings: true
          interval: 30
          timeout: 30
          unhealthyThreshold: 3
          match: { statusCodes: ['200-399'] }
        }
      }
    ]
    backendHttpSettingsCollection: [
      {
        name: 'frontend-https'
        properties: {
          port: 443
          protocol: 'Https'
          cookieBasedAffinity: 'Disabled'
          pickHostNameFromBackendAddress: true
          requestTimeout: 240
          probe: { id: '${gatewayId}/probes/frontend-health' }
        }
      }
    ]
    httpListeners: [
      {
        name: 'caf-https'
        properties: {
          frontendIPConfiguration: { id: '${gatewayId}/frontendIPConfigurations/private' }
          frontendPort: { id: '${gatewayId}/frontendPorts/https' }
          protocol: 'Https'
          hostName: hostname
          requireServerNameIndication: true
          sslCertificate: { id: '${gatewayId}/sslCertificates/caf' }
        }
      }
    ]
    requestRoutingRules: [
      {
        name: 'frontend'
        properties: {
          priority: 100
          ruleType: 'Basic'
          httpListener: { id: '${gatewayId}/httpListeners/caf-https' }
          backendAddressPool: { id: '${gatewayId}/backendAddressPools/frontend' }
          backendHttpSettings: { id: '${gatewayId}/backendHttpSettingsCollection/frontend-https' }
        }
      }
    ]
  }
}
resource diagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'auditoria-caf'
  scope: gateway
  properties: {
    workspaceId: workspaceId
    eventHubAuthorizationRuleId: empty(siemAuthorizationRuleId) ? null : siemAuthorizationRuleId
    eventHubName: empty(siemEventHubName) ? null : siemEventHubName
    logs: [{ categoryGroup: 'allLogs', enabled: true }]
    metrics: [{ category: 'AllMetrics', enabled: true }]
  }
}
output url string = 'https://${hostname}'

resource unhealthy 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'alerta-gateway-${token}'
  location: 'global'
  tags: tags
  properties: {
    description: 'Backend no saludable durante cinco minutos.'
    severity: 1
    enabled: true
    scopes: [gateway.id]
    evaluationFrequency: 'PT1M'
    windowSize: 'PT5M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [{ name: 'backend', criterionType: 'StaticThresholdCriterion', metricNamespace: 'Microsoft.Network/applicationGateways', metricName: 'UnhealthyHostCount', operator: 'GreaterThan', threshold: 0, timeAggregation: 'Average' }]
    }
    actions: [{ actionGroupId: actionGroupId }]
  }
}
