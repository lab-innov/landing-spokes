targetScope = 'resourceGroup'

@description('Desplegar únicamente en un grupo nuevo para conservar ECOCAF actual.')
@allowed([
  'eastus'
])
param location string = 'eastus'
param tags object = {
  iniciativa: 'ECOCAF'
  administradoPor: 'Bicep'
  OpsDept: 'DTI'
}
@minLength(2)
@maxLength(60)
param functionAppName string
param planName string
@minLength(2)
@maxLength(60)
param frontendAppName string
param frontendPlanName string
@minLength(3)
@maxLength(24)
param storageAccountName string
@minLength(3)
@maxLength(24)
param businessStorageAccountName string
param cosmosAccountName string
param openAiAccountName string
param documentIntelligenceAccountName string
param vnetName string
@description('Rangos aprobados por IPAM, sin solapamiento con CAF.')
@minLength(1)
param vnetAddressPrefixes array
param subnetPrefixes {
  privateEndpoints: string
  functionsIntegration: string
  frontendIntegration: string
}
@description('ID de tabla de rutas corporativa existente; no se modifica su contenido.')
@minLength(1)
param routeTableResourceId string
param logAnalyticsWorkspaceResourceId string
@description('IDs completos de zonas DNS privadas centralizadas, suministrados por CAF. No se crean zonas locales.')
param privateDnsZoneResourceIds {
  blob: string
  dfs: string
  queue: string
  table: string
  sites: string
  cosmosSql: string
  cognitiveServicesAccount: string
  openAi: string
}
type Model = {
  name: string
  model: string
  version: string
  sku: string
  @minValue(1)
  capacity: int
}
@description('Despliegues de modelo aprobados para ECOCAF; no copiar automáticamente los modelos compartidos de iDataFactory.')
param models Model[] = []
param modelsApproved bool = false
@minLength(1)
param openAiApiVersion string
@description('APIs comunes existentes. Deben tener contrato, autenticación y conectividad privada aprobados.')
param commonServiceUrls {
  audits: string
  notifications: string
  pdfConverter: string
}
param commonServicesVerified bool = false
@description('Confirma que el código dejó de usar claves y cadenas de conexión para Blob, Cosmos, OpenAI y Document Intelligence.')
param identityMigrationVerified bool = false
@description('Registro Entra ID existente para la nueva API; validar los consumidores antes del corte.')
param authenticationClientId string
@description('Registro Entra ID del frontend dedicado.')
param frontendAuthenticationClientId string
param tenantId string = subscription().tenantId
param allowedOrigins array = []
@description('Configuración completa del código recuperado. No incluir AzureWebJobsStorage con cadena de conexión ni secretos en archivos versionados.')
@secure()
param applicationSettings object = {}
@description('Configuración adicional del frontend. El secreto de Easy Auth se suministra fuera de Git.')
@secure()
param frontendApplicationSettings object = {}
@description('Mantener detenida hasta completar DNS, RBAC, código, datos y dependencias.')
param activateFunctionApp bool = false
param activateFrontend bool = false

@description('Redes autorizadas para la API por VPN/APIM y para los operadores privados.')
param apiClientPrefixes string[] = []
param operatorPrefixes string[] = []
param monitorPrefixes string[] = []
@description('IP reales del endpoint sites, obtenidas después de la fundación.')
param functionPrivateIps string[] = []
@description('IP reales del endpoint sites del frontend, obtenidas después de la fundación.')
param frontendPrivateIps string[] = []
@description('Excepciones de salida TCP: purpose=functionsIntegration, destination, ports, justification.')
param extraEgress array = []
@description('Object IDs de usuarios o identidades autorizadas; no son client IDs ni grupos.')
@maxLength(13)
param allowedPrincipalIds string[] = []
@maxLength(50)
param frontendAllowedPrincipalIds string[] = []
param inventoryVerified bool = false
param networkVerified bool = false
param defenderVerified bool = false
param siemVerified bool = false
param applicationVerified bool = false
param frontendApplicationVerified bool = false
param securityApprovalId string = ''
@description('Declarar según inventario si la aplicación procesa archivos no confiables, incluso en almacenamiento externo.')
@allowed([
  true
])
param processesUntrustedFiles bool = true
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
    validSecurity: any(storageAccountName != businessStorageAccountName && (empty(models) || modelsApproved) && !empty(tags.?iniciativa ?? '') && !empty(tags.?DataClassification ?? '') && tags.?OpsDept == 'DTI' && !empty(tags.?UserDept ?? '') && empty(filter(allowedOrigins, origin => contains(origin, '*'))) && (empty(siemAuthorizationRuleId) == empty(siemEventHubName)))
    validSettings: any(empty(filter(items(applicationSettings), setting => startsWith(toLower(setting.key), 'azurewebjobsstorage') || endsWith(toLower(setting.key), '_key') || endsWith(toLower(setting.key), '_connection_string') || contains(['functions_worker_runtime', 'functions_extension_version', 'applicationinsights_connection_string'], toLower(setting.key)))))
    validActivation: any((!activateFunctionApp || (!empty(models) && modelsApproved && commonServicesVerified && identityMigrationVerified && inventoryVerified && networkVerified && defenderVerified && siemVerified && applicationVerified && !empty(securityApprovalId) && !empty(allowedPrincipalIds) && !empty(functionPrivateIps) && !empty(apiClientPrefixes) && !empty(monitorPrefixes) && !empty(actionGroupResourceId) && (!processesUntrustedFiles || fileScanningVerified))) && (!activateFrontend || (activateFunctionApp && frontendApplicationVerified && !empty(frontendAllowedPrincipalIds) && !empty(frontendPrivateIps) && contains(frontendApplicationSettings, 'MICROSOFT_PROVIDER_AUTHENTICATION_SECRET'))))
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
    apiClientPrefixes: apiClientPrefixes
    operatorPrefixes: operatorPrefixes
    monitorPrefixes: monitorPrefixes
    functionPrivateIps: functionPrivateIps
    frontendPrivateIps: frontendPrivateIps
    extraEgress: extraEgress
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
    privateDnsZoneResourceIds: [privateDnsZoneResourceIds[service]]
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
    businessStorageAccountName: businessStorage.outputs.name
    cosmosAccountName: cosmosAccountName
    openAiAccountName: openAiAccountName
    documentIntelligenceAccountName: documentIntelligenceAccountName
    openAiApiVersion: openAiApiVersion
    commonServiceUrls: commonServiceUrls
    integrationSubnetResourceId: network.outputs.functionsIntegrationSubnetId
    tenantId: tenantId
    authenticationClientId: authenticationClientId
    allowedPrincipalIds: allowedPrincipalIds
    actionGroupResourceId: actionGroupResourceId
    requestsAlertThreshold: requestsAlertThreshold
    logAnalyticsWorkspaceResourceId: logAnalyticsWorkspaceResourceId
    siemAuthorizationRuleId: siemAuthorizationRuleId
    siemEventHubName: siemEventHubName
    applicationSettings: applicationSettings
    allowedOrigins: union(allowedOrigins, [
      'https://${frontendAppName}.azurewebsites.net'
    ])
    enabled: activateFunctionApp
  }
  dependsOn: [storageEndpoints, serviceEndpoints]
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
    privateDnsZoneResourceIds: [privateDnsZoneResourceIds.sites]
  }
}

module businessStorage './modules/storage.bicep' = {
  name: 'ecocaf-datos'
  params: {
    location: location
    tags: tags
    storageAccountName: businessStorageAccountName
    containerNames: [
      'ecocaf'
    ]
    isHnsEnabled: true
    logAnalyticsWorkspaceResourceId: logAnalyticsWorkspaceResourceId
    siemAuthorizationRuleId: siemAuthorizationRuleId
    siemEventHubName: siemEventHubName
  }
  dependsOn: [contracts]
}

module services './modules/services.bicep' = {
  name: 'ecocaf-servicios'
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

var serviceTargets = [
  {
    name: businessStorageAccountName
    id: resourceId('Microsoft.Storage/storageAccounts', businessStorageAccountName)
    group: 'blob'
    zoneId: privateDnsZoneResourceIds.blob
  }
  {
    name: '${businessStorageAccountName}-dfs'
    id: resourceId('Microsoft.Storage/storageAccounts', businessStorageAccountName)
    group: 'dfs'
    zoneId: privateDnsZoneResourceIds.dfs
  }
  {
    name: cosmosAccountName
    id: resourceId('Microsoft.DocumentDB/databaseAccounts', cosmosAccountName)
    group: 'Sql'
    zoneId: privateDnsZoneResourceIds.cosmosSql
  }
  {
    name: openAiAccountName
    id: resourceId('Microsoft.CognitiveServices/accounts', openAiAccountName)
    group: 'account'
    zoneId: privateDnsZoneResourceIds.openAi
  }
  {
    name: documentIntelligenceAccountName
    id: resourceId('Microsoft.CognitiveServices/accounts', documentIntelligenceAccountName)
    group: 'account'
    zoneId: privateDnsZoneResourceIds.cognitiveServicesAccount
  }
]

module serviceEndpoints './modules/private-endpoint.bicep' = [for (target, index) in serviceTargets: {
  name: 'ecocaf-pe-servicio-${index}'
  params: {
    name: 'pe-${target.name}'
    location: location
    tags: tags
    subnetResourceId: network.outputs.peSubnetId
    privateLinkServiceId: target.id
    groupIds: [target.group]
    privateDnsZoneResourceIds: [target.zoneId]
  }
  dependsOn: [businessStorage, services]
}]

module dataAccess './modules/data-access.bicep' = {
  name: 'ecocaf-permisos-datos'
  params: {
    principalId: runtime.outputs.principalId
    storageName: businessStorage.outputs.name
    cosmosName: cosmosAccountName
    openAiName: openAiAccountName
    documentName: documentIntelligenceAccountName
  }
  dependsOn: [services]
}

module frontend './modules/frontend-app.bicep' = {
  name: 'ecocaf-frontend'
  params: {
    location: location
    tags: tags
    planName: frontendPlanName
    appName: frontendAppName
    integrationSubnetResourceId: network.outputs.frontendIntegrationSubnetId
    tenantId: tenantId
    authenticationClientId: frontendAuthenticationClientId
    allowedPrincipalIds: frontendAllowedPrincipalIds
    applicationSettings: frontendApplicationSettings
    enabled: activateFrontend
    logAnalyticsWorkspaceResourceId: logAnalyticsWorkspaceResourceId
    siemAuthorizationRuleId: siemAuthorizationRuleId
    siemEventHubName: siemEventHubName
  }
  dependsOn: [contracts]
}

module frontendEndpoint './modules/private-endpoint.bicep' = {
  name: 'ecocaf-pe-frontend'
  params: {
    name: 'pe-${frontendAppName}'
    location: location
    tags: tags
    subnetResourceId: network.outputs.peSubnetId
    privateLinkServiceId: frontend.outputs.resourceId
    groupIds: ['sites']
    privateDnsZoneResourceIds: [privateDnsZoneResourceIds.sites]
  }
}

output functionAppResourceId string = runtime.outputs.resourceId
output functionHostname string = runtime.outputs.hostname
output functionPrincipalId string = runtime.outputs.principalId
output frontendResourceId string = frontend.outputs.resourceId
output frontendHostname string = frontend.outputs.hostname
output hostStorageAccountResourceId string = storage.outputs.resourceId
output businessStorageAccountResourceId string = businessStorage.outputs.resourceId
output cosmosAccountResourceId string = services.outputs.cosmosId
output openAiAccountResourceId string = services.outputs.openAiId
output documentIntelligenceAccountResourceId string = services.outputs.documentIntelligenceId
output serviceConnections object = services.outputs.connections
output vnetResourceId string = network.outputs.vnetId

output securityResourceIds object = {
  hostStorage: storage.outputs.resourceId
  businessStorage: businessStorage.outputs.resourceId
  functionApp: runtime.outputs.resourceId
  frontend: frontend.outputs.resourceId
  cosmos: services.outputs.cosmosId
  openAi: services.outputs.openAiId
  documentIntelligence: services.outputs.documentIntelligenceId
}
