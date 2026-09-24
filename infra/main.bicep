targetScope = 'resourceGroup'

@description('Desplegar únicamente en un grupo nuevo; no modifica los RG de la prueba de concepto.')
@allowed(['eastus'])
param location string = 'eastus'
param tags object = { iniciativa: 'SMARTREVIEW', administradoPor: 'Bicep', OpsDept: 'DTI' }

@minLength(2)
@maxLength(60)
param functionAppName string
param functionPlanName string
@minLength(2)
@maxLength(60)
param frontendAppName string
param frontendPlanName string
param applicationInsightsName string
@minLength(3)
@maxLength(24)
param hostStorageAccountName string
@minLength(3)
@maxLength(24)
param businessStorageAccountName string
param cosmosAccountName string
param openAiAccountName string
param documentIntelligenceAccountName string
param keyVaultName string

param vnetName string
@description('Rango /24 aprobado por IPAM y sin solapamiento con CAF.')
@minLength(1)
@maxLength(1)
param vnetAddressPrefixes array
param subnetPrefixes {
  privateEndpoints: string
  functionsIntegration: string
  frontendIntegration: string
}
@description('ID completo de una tabla de rutas corporativa existente; la plantilla no modifica sus reglas.')
@minLength(1)
param routeTableResourceId string
param logAnalyticsWorkspaceResourceId string
@description('IDs de zonas DNS privadas centralizadas. No se crean zonas ni reglas de reenvío.')
param privateDnsZoneResourceIds {
  blob: string
  queue: string
  table: string
  sites: string
  cosmosSql: string
  openAi: string
  cognitiveServicesAccount: string
  keyVault: string
}

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
param secretNames string[] = []

@description('Registro Entra ID de la API; los consumidores deben migrar de Function keys a tokens Entra.')
param functionAuthenticationClientId string
@description('Registro Entra ID del frontend.')
param frontendAuthenticationClientId string
param tenantId string = subscription().tenantId
param allowedOrigins string[] = []
@secure()
@description('Configuración recuperada del backend. No incluir secretos ni conexiones del host.')
param functionApplicationSettings object = {}
@secure()
@description('Configuración de runtime del frontend. Las variables VITE se resuelven al compilar el paquete.')
param frontendApplicationSettings object = {}
param activateFunctionApp bool = false
param activateFrontendApp bool = false

param apiClientPrefixes string[] = []
param operatorPrefixes string[] = []
param monitorPrefixes string[] = []
param functionPrivateIps string[] = []
param frontendPrivateIps string[] = []
param cosmosPrivateIps string[] = []
@description('Excepciones de salida del backend: purpose=functionsIntegration, destination, ports y justification.')
param extraEgress array = []
@maxLength(13)
param allowedPrincipalIds string[] = []

param inventoryVerified bool = false
param networkVerified bool = false
param defenderVerified bool = false
param siemVerified bool = false
param monitoringPrivateLinkVerified bool = false
param applicationVerified bool = false
param securityApprovalId string = ''
param processesUntrustedFiles bool = true
param fileScanningVerified bool = false
param hostUsesTables bool = false
param hostUsesBlobTriggers bool = false
param hostUsesDurableStorage bool = true

@description('Regla Send de un namespace Event Hub autorizado para el SIEM.')
@minLength(1)
param siemAuthorizationRuleId string
@minLength(1)
param siemEventHubName string
param actionGroupResourceId string = ''
@minValue(1)
param requestsAlertThreshold int = 10000

var businessContainerNames = ['basedocuments', 'resoluciones', 'documents', 'batchs-gpt-temporal', 'outputs']
var cosmosDatabaseName = 'contracts-dco-db'
var cosmosContainerNames = ['contracts', 'settings']

module contracts './modules/contracts.bicep' = {
  name: 'smartreview-contratos'
  params: {
    validSecurity: any(endsWith(string(vnetAddressPrefixes[0]), '/24') && hostStorageAccountName != businessStorageAccountName && !contains(['rg-poc-revisioncontratos-cr', 'rg-poc-analisisdec-cr', 'rg-poc-idatafactory-cr'], toLower(resourceGroup().name)) && (empty(models) || modelsApproved) && !empty(tags.?iniciativa ?? '') && !empty(tags.?DataClassification ?? '') && tags.?OpsDept == 'DTI' && !empty(tags.?UserDept ?? '') && empty(filter(allowedOrigins, origin => contains(origin, '*'))) && !empty(siemAuthorizationRuleId) && !empty(siemEventHubName))
    validSettings: any(empty(filter(items(functionApplicationSettings), setting => startsWith(toLower(setting.key), 'azurewebjobsstorage') || contains(['functions_worker_runtime', 'functions_extension_version', 'applicationinsights_connection_string'], toLower(setting.key)))))
    validActivation: any((!activateFunctionApp || (!empty(models) && (batchEnabled || empty(filter(models, model => contains(model.sku, 'Batch')))) && !empty(cosmosPrivateIps) && !empty(functionPrivateIps) && inventoryVerified && networkVerified && defenderVerified && siemVerified && monitoringPrivateLinkVerified && applicationVerified && !empty(securityApprovalId) && !empty(allowedPrincipalIds) && !empty(apiClientPrefixes) && !empty(monitorPrefixes) && !empty(actionGroupResourceId) && (!processesUntrustedFiles || fileScanningVerified))) && (!activateFrontendApp || (!empty(frontendPrivateIps) && inventoryVerified && networkVerified && siemVerified && applicationVerified && !empty(securityApprovalId) && !empty(allowedPrincipalIds) && !empty(apiClientPrefixes))))
  }
}

module network './modules/network.bicep' = {
  name: 'smartreview-red'
  params: { location: location, tags: tags, vnetName: vnetName, vnetAddressPrefixes: vnetAddressPrefixes, subnetPrefixes: subnetPrefixes, routeTableResourceId: routeTableResourceId, apiClientPrefixes: apiClientPrefixes, operatorPrefixes: operatorPrefixes, monitorPrefixes: monitorPrefixes, functionPrivateIps: functionPrivateIps, frontendPrivateIps: frontendPrivateIps, cosmosPrivateIps: cosmosPrivateIps, extraEgress: extraEgress }
  dependsOn: [contracts]
}

module hostStorage './modules/storage.bicep' = {
  name: 'smartreview-storage-host'
  params: { location: location, tags: tags, storageAccountName: hostStorageAccountName, skuName: 'Standard_LRS', containerNames: ['azure-webjobs-hosts', 'azure-webjobs-secrets'], logAnalyticsWorkspaceResourceId: logAnalyticsWorkspaceResourceId, siemAuthorizationRuleId: siemAuthorizationRuleId, siemEventHubName: siemEventHubName }
  dependsOn: [contracts]
}
module businessStorage './modules/storage.bicep' = {
  name: 'smartreview-storage-datos'
  params: { location: location, tags: tags, storageAccountName: businessStorageAccountName, skuName: 'Standard_RAGRS', containerNames: businessContainerNames, logAnalyticsWorkspaceResourceId: logAnalyticsWorkspaceResourceId, siemAuthorizationRuleId: siemAuthorizationRuleId, siemEventHubName: siemEventHubName }
  dependsOn: [contracts]
}
module services './modules/services.bicep' = {
  name: 'smartreview-servicios'
  params: { location: location, tags: tags, cosmosName: cosmosAccountName, cosmosDatabaseName: cosmosDatabaseName, cosmosContainerNames: cosmosContainerNames, openAiName: openAiAccountName, documentName: documentIntelligenceAccountName, vaultName: keyVaultName, models: models, workspaceId: logAnalyticsWorkspaceResourceId, siemAuthorizationRuleId: siemAuthorizationRuleId, siemEventHubName: siemEventHubName }
  dependsOn: [contracts]
}
module applicationInsights './modules/application-insights.bicep' = {
  name: 'smartreview-telemetria'
  params: { name: applicationInsightsName, location: location, tags: tags, workspaceResourceId: logAnalyticsWorkspaceResourceId }
  dependsOn: [contracts]
}

module hostStorageEndpoints './modules/private-endpoint.bicep' = [for service in ['blob', 'queue', 'table']: {
  name: 'smartreview-pe-host-${service}'
  params: { name: 'pe-${hostStorageAccountName}-${service}', location: location, tags: tags, subnetResourceId: network.outputs.peSubnetId, privateLinkServiceId: hostStorage.outputs.resourceId, groupIds: [service], privateDnsZoneResourceIds: [privateDnsZoneResourceIds[service]] }
}]
var serviceTargets = [
  { name: businessStorageAccountName, id: resourceId('Microsoft.Storage/storageAccounts', businessStorageAccountName), group: 'blob', zoneId: privateDnsZoneResourceIds.blob }
  { name: cosmosAccountName, id: resourceId('Microsoft.DocumentDB/databaseAccounts', cosmosAccountName), group: 'Sql', zoneId: privateDnsZoneResourceIds.cosmosSql }
  { name: openAiAccountName, id: resourceId('Microsoft.CognitiveServices/accounts', openAiAccountName), group: 'account', zoneId: privateDnsZoneResourceIds.openAi }
  { name: documentIntelligenceAccountName, id: resourceId('Microsoft.CognitiveServices/accounts', documentIntelligenceAccountName), group: 'account', zoneId: privateDnsZoneResourceIds.cognitiveServicesAccount }
  { name: keyVaultName, id: resourceId('Microsoft.KeyVault/vaults', keyVaultName), group: 'vault', zoneId: privateDnsZoneResourceIds.keyVault }
]
module serviceEndpoints './modules/private-endpoint.bicep' = [for (target, index) in serviceTargets: {
  name: 'smartreview-pe-servicio-${index}'
  params: { name: 'pe-${target.name}', location: location, tags: tags, subnetResourceId: network.outputs.peSubnetId, privateLinkServiceId: target.id, groupIds: [target.group], privateDnsZoneResourceIds: [target.zoneId] }
  dependsOn: [businessStorage, services]
}]

module runtime './modules/function-app.bicep' = {
  name: 'smartreview-backend'
  params: { location: location, tags: tags, planName: functionPlanName, functionAppName: functionAppName, hostStorageAccountName: hostStorage.outputs.name, integrationSubnetResourceId: network.outputs.functionsIntegrationSubnetId, tenantId: tenantId, authenticationClientId: functionAuthenticationClientId, allowedPrincipalIds: allowedPrincipalIds, actionGroupResourceId: actionGroupResourceId, requestsAlertThreshold: requestsAlertThreshold, logAnalyticsWorkspaceResourceId: logAnalyticsWorkspaceResourceId, siemAuthorizationRuleId: siemAuthorizationRuleId, siemEventHubName: siemEventHubName, applicationInsightsConnectionString: applicationInsights.outputs.connectionString, applicationSettings: functionApplicationSettings, allowedOrigins: allowedOrigins, enabled: activateFunctionApp }
  dependsOn: [hostStorageEndpoints, serviceEndpoints]
}
module frontend './modules/web-app.bicep' = {
  name: 'smartreview-frontend'
  params: { location: location, tags: tags, planName: frontendPlanName, webAppName: frontendAppName, integrationSubnetResourceId: network.outputs.frontendIntegrationSubnetId, tenantId: tenantId, authenticationClientId: frontendAuthenticationClientId, allowedPrincipalIds: allowedPrincipalIds, logAnalyticsWorkspaceResourceId: logAnalyticsWorkspaceResourceId, siemAuthorizationRuleId: siemAuthorizationRuleId, siemEventHubName: siemEventHubName, applicationSettings: frontendApplicationSettings, enabled: activateFrontendApp }
  dependsOn: [serviceEndpoints]
}
module functionEndpoint './modules/private-endpoint.bicep' = {
  name: 'smartreview-pe-backend'
  params: { name: 'pe-${functionAppName}', location: location, tags: tags, subnetResourceId: network.outputs.peSubnetId, privateLinkServiceId: runtime.outputs.resourceId, groupIds: ['sites'], privateDnsZoneResourceIds: [privateDnsZoneResourceIds.sites] }
}
module frontendEndpoint './modules/private-endpoint.bicep' = {
  name: 'smartreview-pe-frontend'
  params: { name: 'pe-${frontendAppName}', location: location, tags: tags, subnetResourceId: network.outputs.peSubnetId, privateLinkServiceId: frontend.outputs.resourceId, groupIds: ['sites'], privateDnsZoneResourceIds: [privateDnsZoneResourceIds.sites] }
}

module hostAccess './modules/host-access.bicep' = {
  name: 'smartreview-permisos-host'
  params: { storageAccountName: hostStorage.outputs.name, principalId: runtime.outputs.principalId, hostUsesTables: hostUsesTables, hostUsesBlobTriggers: hostUsesBlobTriggers, hostUsesDurableStorage: hostUsesDurableStorage }
}
module dataAccess './modules/data-access.bicep' = {
  name: 'smartreview-permisos-datos'
  params: { principalId: runtime.outputs.principalId, storageName: businessStorage.outputs.name, containerNames: businessContainerNames, cosmosName: cosmosAccountName, cosmosDatabaseName: cosmosDatabaseName, openAiName: openAiAccountName, documentName: documentIntelligenceAccountName, vaultName: keyVaultName, secretNames: secretNames, batchEnabled: batchEnabled }
  dependsOn: [services]
}

output functionAppResourceId string = runtime.outputs.resourceId
output functionHostname string = runtime.outputs.hostname
output frontendAppResourceId string = frontend.outputs.resourceId
output frontendHostname string = frontend.outputs.hostname
output vnetResourceId string = network.outputs.vnetId
output serviceConnections object = services.outputs.connections
output securityResourceIds object = { hostStorage: hostStorage.outputs.resourceId, businessStorage: businessStorage.outputs.resourceId, functionApp: runtime.outputs.resourceId, frontendApp: frontend.outputs.resourceId, cosmos: services.outputs.cosmosId, openAi: services.outputs.openAiId, documentIntelligence: services.outputs.documentIntelligenceId, vault: services.outputs.vaultId, applicationInsights: applicationInsights.outputs.resourceId }
