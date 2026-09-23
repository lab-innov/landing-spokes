using './main.bicep'

// Ejemplo no desplegable: sustituir todos los PENDIENTE con datos aprobados por CAF.
param location = 'eastus'
param functionAppName = 'func-ecocaf-private-PENDIENTE'
param planName = 'asp-ecocaf-private-PENDIENTE'
param storageAccountName = 'PENDIENTE'
param vnetName = 'vnet-ecocaf-PENDIENTE'
param vnetAddressPrefixes = ['PENDIENTE-IPAM']
param subnetPrefixes = {
  privateEndpoints: 'PENDIENTE-IPAM'
  functionsIntegration: 'PENDIENTE-IPAM'
}
param routeTableResourceId = 'PENDIENTE-ID-TABLA-CAF'
param logAnalyticsWorkspaceResourceId = 'PENDIENTE-ID-LOG-ANALYTICS'
param privateDnsZoneResourceIds = {
  blob: 'PENDIENTE-ID-ZONA-PRIVATELINK-BLOB'
  queue: 'PENDIENTE-ID-ZONA-PRIVATELINK-QUEUE'
  table: 'PENDIENTE-ID-ZONA-PRIVATELINK-TABLE'
  sites: 'PENDIENTE-ID-ZONA-PRIVATELINK-AZUREWEBSITES'
}
param authenticationClientId = 'PENDIENTE-REGISTRO-ENTRA'
param applicationSettings = {}
param allowedOrigins = []
param activateFunctionApp = false

param tags = { iniciativa: 'ECOCAF', administradoPor: 'Bicep', DataClassification: 'PENDIENTE-CLASIFICACION', OpsDept: 'DTI', UserDept: 'PENDIENTE-AREA-FUNCIONAL' }
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
param processesUntrustedFiles = false
param fileScanningVerified = false
param actionGroupResourceId = ''
param siemAuthorizationRuleId = ''
param siemEventHubName = ''
