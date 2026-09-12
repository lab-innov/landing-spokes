using '../infra/main.bicep'

// Ejemplo no desplegable: sustituir todos los PENDIENTE con datos aprobados por CAF.
param location = 'eastus'
param functionAppName = 'func-analisisdec-PENDIENTE'
param planName = 'asp-analisisdec-PENDIENTE'
param storageAccountName = 'PENDIENTE'
param vnetName = 'vnet-analisisdec-PENDIENTE'
param vnetAddressPrefixes = ['PENDIENTE-IPAM']
param subnetPrefixes = {
  privateEndpoints: 'PENDIENTE-IPAM'
  functionsIntegration: 'PENDIENTE-IPAM'
}
param routeTableResourceId = 'PENDIENTE-ID-TABLA-CAF'
param dnsServers = ['PENDIENTE-DNS-CAF']
param hubVnetResourceId = 'PENDIENTE-ID-HUB'
param logAnalyticsWorkspaceResourceId = 'PENDIENTE-ID-LOG-ANALYTICS'
param applicationInsightsName = 'PENDIENTE'
param businessStorageAccountName = 'PENDIENTE'
param cosmosAccountName = 'PENDIENTE'
param openAiAccountName = 'PENDIENTE'
param documentIntelligenceAccountName = 'PENDIENTE'
param keyVaultName = 'PENDIENTE'
param authenticationClientId = 'PENDIENTE-REGISTRO-ENTRA'
param applicationSettings = {}
param allowedOrigins = []
param activateFunctionApp = false

param tags = { iniciativa: 'ANALISISDEC', administradoPor: 'Bicep', DataClassification: 'PENDIENTE-CLASIFICACION' }
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
param secretNames = []
param hostUsesDurableStorage = true
