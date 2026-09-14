targetScope = 'resourceGroup'

@description('Desplegar únicamente en un grupo nuevo para conservar VINCULADOR actual.')
@allowed(['eastus'])
param location string = 'eastus'
param tags object = {
  iniciativa: 'VINCULADOR'
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
param dataFactoryName string
@description('Permitir servicios confiables solo después de aprobar el recorrido Storage/Event Grid corporativo.')
param allowTrustedStorageServices bool = false
param storageEventExceptionApprovalId string = ''
param orchestrationVerified bool = false
@description('Redes privadas de cómputo Databricks aprobadas; no son las IP del control plane de ADF.')
param processorPrefixes string[] = []
param processorDataPrivateIps string[] = []
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
@allowed([true])
param hostUsesBlobTriggers bool = true
param hostUsesDurableStorage bool = false
param siemAuthorizationRuleId string = ''
param siemEventHubName string = ''
param actionGroupResourceId string = ''
@minValue(1)
param requestsAlertThreshold int = 10000

module contracts './modules/contracts.bicep' = {
  name: 'vinculador-contratos'
  params: {
    validSecurity: any(endsWith(string(vnetAddressPrefixes[0]), '/24') && storageAccountName != businessStorageAccountName && (!allowTrustedStorageServices || !empty(storageEventExceptionApprovalId)) && toLower(resourceGroup().name) != 'rg-poc-vinculador-cr' && (empty(models) || modelsApproved) && !empty(tags.?iniciativa ?? '') && !empty(tags.?DataClassification ?? '') && empty(filter(allowedOrigins, origin => contains(origin, '*'))) && (empty(siemAuthorizationRuleId) == empty(siemEventHubName)))
    validSettings: any(empty(filter(items(applicationSettings), setting => startsWith(toLower(setting.key), 'azurewebjobsstorage') || startsWith(toLower(setting.key), 'blob_storage_connection_string') || contains(['functions_worker_runtime', 'functions_extension_version', 'applicationinsights_connection_string'], toLower(setting.key)))))
    validActivation: any(!activateFunctionApp || (!empty(models) && (batchEnabled || empty(filter(models, model => contains(model.sku, 'Batch')))) && !empty(cosmosPrivateIps) && !empty(processorPrefixes) && !empty(processorDataPrivateIps) && orchestrationVerified && inventoryVerified && networkVerified && defenderVerified && siemVerified && applicationVerified && !empty(securityApprovalId) && !empty(allowedPrincipalIds) && !empty(functionPrivateIps) && !empty(apiClientPrefixes) && !empty(monitorPrefixes) && !empty(actionGroupResourceId) && (!processesUntrustedFiles || fileScanningVerified)))
  }
}

module network './modules/network.bicep' = {
  name: 'vinculador-network'
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
    processorPrefixes: processorPrefixes
    processorDataPrivateIps: processorDataPrivateIps
    extraEgress: extraEgress
    dnsServers: dnsServers
    hubVnetResourceId: hubVnetResourceId
  }
  dependsOn: [contracts]
}

module storage './modules/storage.bicep' = {
  name: 'vinculador-storage'
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
  name: 'vinculador-pe-${service}'
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
  name: 'vinculador-functions'
  params: {
    location: location
    tags: tags
    planName: planName
    functionAppName: functionAppName
    hostStorageAccountName: storage.outputs.name
    businessStorageAccountName: businessStorage.outputs.name
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
  name: 'vinculador-host-access'
  params: {
    storageAccountName: storage.outputs.name
    principalId: runtime.outputs.principalId
    hostUsesTables: hostUsesTables
    hostUsesBlobTriggers: hostUsesBlobTriggers
    hostUsesDurableStorage: hostUsesDurableStorage
  }
}

module functionEndpoint './modules/private-endpoint.bicep' = {
  name: 'vinculador-pe-function'
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

output securityResourceIds object = { hostStorage: storage.outputs.resourceId, businessStorage: businessStorage.outputs.resourceId, functionApp: runtime.outputs.resourceId, cosmos: services.outputs.cosmosId, openAi: services.outputs.openAiId, documentIntelligence: services.outputs.documentIntelligenceId, dataFactory: factory.outputs.resourceId }
output applicationInsightsResourceId string = monitoring.outputs.resourceId
output businessStorageResourceId string = businessStorage.outputs.resourceId
output serviceConnections object = services.outputs.connections

module monitoring './modules/monitoring.bicep' = {
  name: 'vinculador-monitoring'
  params: { location: location, tags: tags, applicationInsightsName: applicationInsightsName, logAnalyticsWorkspaceResourceId: logAnalyticsWorkspaceResourceId }
  dependsOn: [contracts]
}
module businessStorage './modules/storage.bicep' = {
  name: 'vinculador-datos'
  params: {
    location: location
    tags: tags
    storageAccountName: businessStorageAccountName
    allowTrustedServices: allowTrustedStorageServices
    containerNames: ['poc-vinculador-files', 'poc-vinculador-files-processed', 'poc-vinculador-gpt-files', 'poc-vinculador-trigger-data-factory']
    logAnalyticsWorkspaceResourceId: logAnalyticsWorkspaceResourceId
    siemAuthorizationRuleId: siemAuthorizationRuleId
    siemEventHubName: siemEventHubName
  }
  dependsOn: [contracts]
}
module services './modules/services.bicep' = {
  name: 'vinculador-servicios'
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
  { name: '${businessStorageAccountName}-queue', id: businessStorage.outputs.resourceId, group: 'queue' }
]
module serviceEndpoints './modules/private-endpoint.bicep' = [for i in range(0, 5): {
  name: 'vinculador-pe-servicio-${i}'
  params: { name: 'pe-${targets[i].name}', location: location, tags: tags, subnetResourceId: network.outputs.peSubnetId, privateLinkServiceId: targets[i].id, groupIds: [targets[i].group] }
}]
module dataAccess './modules/data-access.bicep' = {
  name: 'vinculador-permisos'
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

module factory './modules/data-factory.bicep' = {
  name: 'vinculador-adf'
  params: { location: location, tags: tags, factoryName: dataFactoryName, logAnalyticsWorkspaceResourceId: logAnalyticsWorkspaceResourceId, siemAuthorizationRuleId: siemAuthorizationRuleId, siemEventHubName: siemEventHubName }
  dependsOn: [contracts]
}
module factoryEndpoint './modules/private-endpoint.bicep' = {
  name: 'vinculador-pe-adf'
  params: { name: 'pe-${dataFactoryName}', location: location, tags: tags, subnetResourceId: network.outputs.peSubnetId, privateLinkServiceId: factory.outputs.resourceId, groupIds: ['dataFactory'] }
}
output dataFactoryResourceId string = factory.outputs.resourceId
output dataFactoryPrincipalId string = factory.outputs.principalId
