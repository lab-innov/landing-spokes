using '../infra/main.bicep'

// Ejemplo no desplegable: sustituir todos los PENDIENTE con datos aprobados por CAF.
param location = 'eastus'
param functionAppName = 'func-mop-PENDIENTE'
param planName = 'asp-mop-PENDIENTE'
param storageAccountName = 'PENDIENTE'
param vnetName = 'vnet-mop-PENDIENTE'
param vnetAddressPrefixes = ['PENDIENTE-IPAM']
param subnetPrefixes = {
  privateEndpoints: 'PENDIENTE-IPAM'
  functionsIntegration: 'PENDIENTE-IPAM'
}
param routeTableResourceId = 'PENDIENTE-ID-TABLA-CAF'
param logAnalyticsWorkspaceResourceId = 'PENDIENTE-ID-LOG-ANALYTICS'
param privateDnsZoneResourceIds = {
  blob: 'PENDIENTE-ID-ZONA-BLOB'
  queue: 'PENDIENTE-ID-ZONA-QUEUE'
  table: 'PENDIENTE-ID-ZONA-TABLE'
  sites: 'PENDIENTE-ID-ZONA-AZUREWEBSITES'
  cosmosSql: 'PENDIENTE-ID-ZONA-COSMOS-SQL'
  cognitiveServicesAccount: 'PENDIENTE-ID-ZONA-COGNITIVE-SERVICES'
}
param businessStorageAccountName = 'PENDIENTE'
param cosmosAccountName = 'PENDIENTE'
param openAiAccountName = 'PENDIENTE'
param documentIntelligenceAccountName = 'PENDIENTE'
param authenticationClientId = 'PENDIENTE-REGISTRO-ENTRA'
param applicationSettings = {}
param allowedOrigins = []
param activateFunctionApp = false

param tags = { iniciativa: 'MOP', administradoPor: 'Bicep', DataClassification: 'PENDIENTE-CLASIFICACION', OpsDept: 'DTI', UserDept: 'PENDIENTE-AREA-FUNCIONAL' }
param apiClientPrefixes = []
param operatorPrefixes = []
param monitorPrefixes = []
param functionPrivateIps = []
param allowedPrincipalIds = []
param extraEgress = []
param inventoryVerified = false
param networkVerified = false
param defenderVerified = false
param siemVerified = false
param applicationVerified = false
param securityApprovalId = ''
param processesUntrustedFiles = true
param fileScanningVerified = false
param actionGroupResourceId = ''
param siemAuthorizationRuleId = ''
param siemEventHubName = ''

param models = []
param modelsApproved = false
param batchEnabled = false
param cosmosPrivateIps = []
param hostUsesDurableStorage = true
