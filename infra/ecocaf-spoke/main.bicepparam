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
param firewallPrivateIp = 'PENDIENTE-CAF'
param dnsServers = ['PENDIENTE-DNS-CAF']
param hubVnetResourceId = 'PENDIENTE-ID-HUB'
param logAnalyticsWorkspaceResourceId = 'PENDIENTE-ID-LOG-ANALYTICS'
param applicationInsightsConnectionString = 'PENDIENTE-APPLICATION-INSIGHTS'
param authenticationClientId = 'PENDIENTE-REGISTRO-ENTRA'
param applicationSettings = {}
param allowedOrigins = []
param activateFunctionApp = false
