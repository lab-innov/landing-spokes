targetScope = 'resourceGroup'

@description('Desplegar únicamente en un grupo nuevo para conservar MOP actual.')
@allowed(['eastus'])
param location string = 'eastus'
param tags object = {
  iniciativa: 'MOP'
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
@maxLength(1)
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
param applicationInsightsName string
param businessStorageAccountName string
param cosmosAccountName string
param openAiAccountName string
param documentIntelligenceAccountName string
param cosmosPrivateIps string[] = []
type Model = {
  name: string
  model: string
  version: string
  sku: string
  @minValue(1)
  capacity: int
}
param models Model[] = []
param modelsApproved bool = false
param batchEnabled bool = false
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
param processesUntrustedFiles bool = true
param fileScanningVerified bool = false
@description('Activar solo si el código requiere tablas para diagnóstico o Durable Functions.')
param hostUsesTables bool = false
param hostUsesBlobTriggers bool = false
@allowed([true])
param hostUsesDurableStorage bool = true
param siemAuthorizationRuleId string = ''
param siemEventHubName string = ''
param actionGroupResourceId string = ''
@minValue(1)
param requestsAlertThreshold int = 10000

module contracts './modules/contracts.bicep' = {
  name: 'mop-contratos'
  params: {
    validSecurity: any(endsWith(string(vnetAddressPrefixes[0]), '/24') && storageAccountName != businessStorageAccountName && toLower(resourceGroup().name) != 'rg-poc-premop-cr' && (empty(models) || modelsApproved) && !empty(tags.?iniciativa ?? '') && !empty(tags.?DataClassification ?? '') && empty(filter(allowedOrigins, origin => contains(origin, '*'))) && (empty(siemAuthorizationRuleId) == empty(siemEventHubName)))
    validSettings: any(empty(filter(items(applicationSettings), setting => startsWith(toLower(setting.key), 'azurewebjobsstorage') || contains(['functions_worker_runtime', 'functions_extension_version', 'applicationinsights_connection_string'], toLower(setting.key)))))
    validActivation: any(!activateFunctionApp || (!empty(models) && (batchEnabled || empty(filter(models, model => contains(model.sku, 'Batch')))) && !empty(cosmosPrivateIps) && inventoryVerified && networkVerified && defenderVerified && siemVerified && applicationVerified && !empty(securityApprovalId) && !empty(allowedPrincipalIds) && !empty(functionPrivateIps) && !empty(apiClientPrefixes) && !empty(monitorPrefixes) && !empty(actionGroupResourceId) && (!processesUntrustedFiles || fileScanningVerified)))
  }
}

module network './modules/network.bicep' = {
  name: 'mop-network'
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
    cosmosPrivateIps: cosmosPrivateIps
    extraEgress: extraEgress
    dnsServers: dnsServers
    hubVnetResourceId: hubVnetResourceId
  }
  dependsOn: [contracts]
}

module storage './modules/storage.bicep' = {
  name: 'mop-storage'
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
  name: 'mop-pe-${service}'
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
  name: 'mop-functions'
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
    applicationInsightsConnectionString: monitoring.outputs.connectionString
    logAnalyticsWorkspaceResourceId: logAnalyticsWorkspaceResourceId
    siemAuthorizationRuleId: siemAuthorizationRuleId
    siemEventHubName: siemEventHubName
    applicationSettings: applicationSettings
    allowedOrigins: allowedOrigins
    enabled: activateFunctionApp
  }
  dependsOn: [storageEndpoints, serviceEndpoints]
}

module hostAccess './modules/host-access.bicep' = {
  name: 'mop-host-access'
  params: {
    storageAccountName: storage.outputs.name
    principalId: runtime.outputs.principalId
    hostUsesTables: hostUsesTables
    hostUsesBlobTriggers: hostUsesBlobTriggers
    hostUsesDurableStorage: hostUsesDurableStorage
  }
}

module functionEndpoint './modules/private-endpoint.bicep' = {
  name: 'mop-pe-function'
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

output securityResourceIds object = { hostStorage: storage.outputs.resourceId, businessStorage: businessStorage.outputs.resourceId, functionApp: runtime.outputs.resourceId, cosmos: services.outputs.cosmosId, openAi: services.outputs.openAiId, documentIntelligence: services.outputs.documentIntelligenceId }
output applicationInsightsResourceId string = monitoring.outputs.resourceId
output businessStorageResourceId string = businessStorage.outputs.resourceId
output serviceConnections object = services.outputs.connections

module monitoring './modules/monitoring.bicep' = {
  name: 'mop-monitoring'
  params: { location: location, tags: tags, applicationInsightsName: applicationInsightsName, logAnalyticsWorkspaceResourceId: logAnalyticsWorkspaceResourceId }
  dependsOn: [contracts]
}
module businessStorage './modules/storage.bicep' = {
  name: 'mop-datos'
  params: {
    location: location
    tags: tags
    storageAccountName: businessStorageAccountName
    storageSku: 'Standard_RAGRS'
    containerNames: ['base-templates', 'documents']
    logAnalyticsWorkspaceResourceId: logAnalyticsWorkspaceResourceId
    siemAuthorizationRuleId: siemAuthorizationRuleId
    siemEventHubName: siemEventHubName
  }
  dependsOn: [contracts]
}
module services './modules/services.bicep' = {
  name: 'mop-servicios'
  params: {
    location: location
    tags: tags
    cosmosName: cosmosAccountName
    openAiName: openAiAccountName
    documentName: documentIntelligenceAccountName
    models: models
    workspaceId: logAnalyticsWorkspaceResourceId
    siemAuthorizationRuleId: siemAuthorizationRuleId
    siemEventHubName: siemEventHubName
  }
  dependsOn: [contracts]
}
var targets = [
  { name: businessStorageAccountName, id: businessStorage.outputs.resourceId, group: 'blob' }
  { name: cosmosAccountName, id: services.outputs.cosmosId, group: 'Sql' }
  { name: openAiAccountName, id: services.outputs.openAiId, group: 'account' }
  { name: documentIntelligenceAccountName, id: services.outputs.documentIntelligenceId, group: 'account' }
]
module serviceEndpoints './modules/private-endpoint.bicep' = [for i in range(0, 4): {
  name: 'mop-pe-servicio-${i}'
  params: { name: 'pe-${targets[i].name}', location: location, tags: tags, subnetResourceId: network.outputs.peSubnetId, privateLinkServiceId: targets[i].id, groupIds: [targets[i].group] }
}]
module dataAccess './modules/data-access.bicep' = {
  name: 'mop-permisos'
  params: {
    principalId: runtime.outputs.principalId
    storageName: businessStorage.outputs.name
    cosmosName: cosmosAccountName
    openAiName: openAiAccountName
    documentName: documentIntelligenceAccountName
    batchEnabled: batchEnabled
  }
  dependsOn: [services]
}
