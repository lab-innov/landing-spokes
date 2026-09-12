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
@description('ID de tabla de rutas corporativa existente; no se modifica su contenido.')
@minLength(1)
param routeTableResourceId string
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

@description('Redes autorizadas para la API por VPN/APIM y para los operadores privados.')
param apiClientPrefixes string[] = []
param operatorPrefixes string[] = []
param monitorPrefixes string[] = []
@description('IP reales del endpoint sites, obtenidas después de la fundación.')
param functionPrivateIps string[] = []
param useRemoteGateways bool = false
@description('Excepciones de salida TCP: purpose=functionsIntegration, destination, ports, justification.')
param extraEgress array = []
@description('Object IDs de usuarios o identidades autorizadas; no son client IDs ni grupos.')
@maxLength(13)
param allowedPrincipalIds string[] = []
param inventoryVerified bool = false
param networkVerified bool = false
param defenderVerified bool = false
param siemVerified bool = false
param applicationVerified bool = false
param securityApprovalId string = ''
@description('Declarar según inventario si la aplicación procesa archivos no confiables, incluso en almacenamiento externo.')
param processesUntrustedFiles bool = false
param fileScanningVerified bool = false
@description('Activar solo si el código requiere tablas para diagnóstico o Durable Functions.')
param hostUsesTables bool = false
param hostUsesBlobTriggers bool = false
param hostUsesDurableStorage bool = false
param siemAuthorizationRuleId string = ''
param siemEventHubName string = ''
param actionGroupResourceId string = ''
@minValue(1)
param requestsAlertThreshold int = 10000

module contracts './modules/contracts.bicep' = {
  name: 'ecocaf-contratos'
  params: {
    validSecurity: any(!empty(tags.?iniciativa ?? '') && !empty(tags.?DataClassification ?? '') && empty(filter(allowedOrigins, origin => contains(origin, '*'))) && (empty(siemAuthorizationRuleId) == empty(siemEventHubName)))
    validSettings: any(empty(filter(items(applicationSettings), setting => startsWith(toLower(setting.key), 'azurewebjobsstorage') || contains(['functions_worker_runtime', 'functions_extension_version', 'applicationinsights_connection_string'], toLower(setting.key)))))
    validActivation: any(!activateFunctionApp || (inventoryVerified && networkVerified && defenderVerified && siemVerified && applicationVerified && !empty(securityApprovalId) && !empty(allowedPrincipalIds) && !empty(functionPrivateIps) && !empty(apiClientPrefixes) && !empty(monitorPrefixes) && !empty(actionGroupResourceId) && (!processesUntrustedFiles || fileScanningVerified)))
  }
}

module network './modules/network.bicep' = {
  name: 'ecocaf-network'
  params: {
    location: location
    tags: tags
    vnetName: vnetName
    vnetAddressPrefixes: vnetAddressPrefixes
    subnetPrefixes: subnetPrefixes
    routeTableResourceId: routeTableResourceId
    useRemoteGateways: useRemoteGateways
    apiClientPrefixes: apiClientPrefixes
    operatorPrefixes: operatorPrefixes
    monitorPrefixes: monitorPrefixes
    functionPrivateIps: functionPrivateIps
    extraEgress: extraEgress
    dnsServers: dnsServers
    hubVnetResourceId: hubVnetResourceId
  }
  dependsOn: [contracts]
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
    siemAuthorizationRuleId: siemAuthorizationRuleId
    siemEventHubName: siemEventHubName
  }
  dependsOn: [contracts]
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
    allowedPrincipalIds: allowedPrincipalIds
    actionGroupResourceId: actionGroupResourceId
    requestsAlertThreshold: requestsAlertThreshold
    applicationInsightsConnectionString: applicationInsightsConnectionString
    logAnalyticsWorkspaceResourceId: logAnalyticsWorkspaceResourceId
    siemAuthorizationRuleId: siemAuthorizationRuleId
    siemEventHubName: siemEventHubName
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
    hostUsesTables: hostUsesTables
    hostUsesBlobTriggers: hostUsesBlobTriggers
    hostUsesDurableStorage: hostUsesDurableStorage
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

output securityResourceIds object = { hostStorage: storage.outputs.resourceId, functionApp: runtime.outputs.resourceId }
