targetScope = 'resourceGroup'

@description('Desplegar únicamente en un grupo nuevo para conservar ECOCAF actual.')
param location string = resourceGroup().location
param tags object = {
  iniciativa: 'ECOCAF'
  administradoPor: 'Bicep'
}
@minLength(2)
@maxLength(60)
param functionAppName string
param planName string
@minLength(3)
@maxLength(24)
param storageAccountName string
param vnetName string
@description('Rangos aprobados por IPAM, sin solapamiento con CAF.')
@minLength(1)
param vnetAddressPrefixes array
param subnetPrefixes {
  privateEndpoints: string
  functionsIntegration: string
}
@description('IP privada del firewall CAF; no se crea ni modifica el hub.')
param firewallPrivateIp string
@minLength(1)
param dnsServers array
param hubVnetResourceId string
param logAnalyticsWorkspaceResourceId string
@secure()
param applicationInsightsConnectionString string
@description('Registro Entra ID existente para la nueva API; validar los consumidores antes del corte.')
param authenticationClientId string
param tenantId string = subscription().tenantId
param allowedOrigins array = []
@description('Configuración completa del código recuperado. No incluir AzureWebJobsStorage con cadena de conexión ni secretos en archivos versionados.')
@secure()
param applicationSettings object = {}
@description('Mantener detenida hasta completar DNS, RBAC, código, datos y dependencias.')
param activateFunctionApp bool = false

module network './modules/network.bicep' = {
  name: 'ecocaf-network'
  params: {
    location: location
    tags: tags
    vnetName: vnetName
    vnetAddressPrefixes: vnetAddressPrefixes
    subnetPrefixes: subnetPrefixes
    firewallPrivateIp: firewallPrivateIp
    dnsServers: dnsServers
    hubVnetResourceId: hubVnetResourceId
  }
}

module storage './modules/storage.bicep' = {
  name: 'ecocaf-storage'
  params: {
    location: location
    tags: tags
    storageAccountName: storageAccountName
    containerNames: [
      'azure-webjobs-hosts'
      'azure-webjobs-secrets'
    ]
    logAnalyticsWorkspaceResourceId: logAnalyticsWorkspaceResourceId
  }
}

module storageEndpoints './modules/private-endpoint.bicep' = [for service in ['blob', 'queue', 'table']: {
  name: 'ecocaf-pe-${service}'
  params: {
    name: 'pe-${storageAccountName}-${service}'
    location: location
    tags: tags
    subnetResourceId: network.outputs.peSubnetId
    privateLinkServiceId: storage.outputs.resourceId
    groupIds: [service]
  }
}]

module runtime './modules/function-app.bicep' = {
  name: 'ecocaf-functions'
  params: {
    location: location
    tags: tags
    planName: planName
    functionAppName: functionAppName
    hostStorageAccountName: storage.outputs.name
    integrationSubnetResourceId: network.outputs.functionsIntegrationSubnetId
    tenantId: tenantId
    authenticationClientId: authenticationClientId
    applicationInsightsConnectionString: applicationInsightsConnectionString
    logAnalyticsWorkspaceResourceId: logAnalyticsWorkspaceResourceId
    applicationSettings: applicationSettings
    allowedOrigins: allowedOrigins
    enabled: activateFunctionApp
  }
  dependsOn: [storageEndpoints]
}

module hostAccess './modules/host-access.bicep' = {
  name: 'ecocaf-host-access'
  params: {
    storageAccountName: storage.outputs.name
    principalId: runtime.outputs.principalId
  }
}

module functionEndpoint './modules/private-endpoint.bicep' = {
  name: 'ecocaf-pe-function'
  params: {
    name: 'pe-${functionAppName}'
    location: location
    tags: tags
    subnetResourceId: network.outputs.peSubnetId
    privateLinkServiceId: runtime.outputs.resourceId
    groupIds: ['sites']
  }
}

output functionAppResourceId string = runtime.outputs.resourceId
output functionHostname string = runtime.outputs.hostname
output functionPrincipalId string = runtime.outputs.principalId
output storageAccountResourceId string = storage.outputs.resourceId
output vnetResourceId string = network.outputs.vnetId
