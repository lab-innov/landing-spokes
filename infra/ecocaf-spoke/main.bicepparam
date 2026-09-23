using './main.bicep'

// Ejemplo no desplegable: sustituir todos los PENDIENTE con datos aprobados por CAF.
param location = 'eastus'
param functionAppName = 'func-ecocaf-private-PENDIENTE'
param planName = 'asp-ecocaf-private-PENDIENTE'
param frontendAppName = 'app-ecocaf-private-PENDIENTE'
param frontendPlanName = 'asp-ecocaf-web-PENDIENTE'
param storageAccountName = 'PENDIENTE'
param businessStorageAccountName = 'PENDIENTE'
param cosmosAccountName = 'cosmos-ecocaf-PENDIENTE'
param openAiAccountName = 'oai-ecocaf-PENDIENTE'
param documentIntelligenceAccountName = 'di-ecocaf-PENDIENTE'
param vnetName = 'vnet-ecocaf-PENDIENTE'
param vnetAddressPrefixes = ['PENDIENTE-IPAM']
param subnetPrefixes = {
  privateEndpoints: 'PENDIENTE-IPAM'
  functionsIntegration: 'PENDIENTE-IPAM'
  frontendIntegration: 'PENDIENTE-IPAM'
}
param routeTableResourceId = 'PENDIENTE-ID-TABLA-CAF'
param logAnalyticsWorkspaceResourceId = 'PENDIENTE-ID-LOG-ANALYTICS'
param privateDnsZoneResourceIds = {
  blob: 'PENDIENTE-ID-ZONA-PRIVATELINK-BLOB'
  dfs: 'PENDIENTE-ID-ZONA-PRIVATELINK-DFS'
  queue: 'PENDIENTE-ID-ZONA-PRIVATELINK-QUEUE'
  table: 'PENDIENTE-ID-ZONA-PRIVATELINK-TABLE'
  sites: 'PENDIENTE-ID-ZONA-PRIVATELINK-AZUREWEBSITES'
  cosmosSql: 'PENDIENTE-ID-ZONA-PRIVATELINK-COSMOS-SQL'
  cognitiveServicesAccount: 'PENDIENTE-ID-ZONA-PRIVATELINK-COGNITIVESERVICES'
  openAi: 'PENDIENTE-ID-ZONA-PRIVATELINK-OPENAI'
}
param authenticationClientId = 'PENDIENTE-REGISTRO-ENTRA'
param frontendAuthenticationClientId = 'PENDIENTE-REGISTRO-ENTRA-FRONTEND'
param models = []
param modelsApproved = false
param openAiApiVersion = 'PENDIENTE-VERSION-API-OPENAI'
param commonServiceUrls = {
  audits: 'PENDIENTE-URL-AUDITORIA'
  notifications: 'PENDIENTE-URL-NOTIFICACIONES'
  pdfConverter: 'PENDIENTE-URL-CONVERSION-PDF'
}
param commonServicesVerified = false
param identityMigrationVerified = false
param applicationSettings = {}
param frontendApplicationSettings = {}
param allowedOrigins = []
param activateFunctionApp = false
param activateFrontend = false

param tags = { iniciativa: 'ECOCAF', administradoPor: 'Bicep', DataClassification: 'PENDIENTE-CLASIFICACION', OpsDept: 'DTI', UserDept: 'DATBC' }
param apiClientPrefixes = []
param operatorPrefixes = []
param monitorPrefixes = []
param functionPrivateIps = []
param frontendPrivateIps = []
param allowedPrincipalIds = []
param frontendAllowedPrincipalIds = []
param extraEgress = []
param inventoryVerified = false
param networkVerified = false
param defenderVerified = false
param siemVerified = false
param applicationVerified = false
param frontendApplicationVerified = false
param securityApprovalId = ''
param processesUntrustedFiles = true
param fileScanningVerified = false
param actionGroupResourceId = ''
param siemAuthorizationRuleId = ''
param siemEventHubName = ''
