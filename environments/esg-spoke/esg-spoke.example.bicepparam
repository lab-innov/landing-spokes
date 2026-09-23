using '../../infra/esg-spoke/main.bicep'

param location = 'eastus'
param resourceGroupName = 'rg-esg-secure-spoke-dev'
param namePrefix = 'esgdev'
param tags = {
  CC: 'Innovacion'
  OpsDept: 'DTI'
  Proyecto: 'PoC ESG'
  UserDept: 'GPFEI'
  Environment: 'dev'
  DataClassification: 'REPLACE-WITH-CLASSIFICATION'
  iniciativa: 'ESG'
}

// Sustituir los marcadores por valores aprobados por plataforma.
param existingRouteTableResourceId = '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-connectivity/providers/Microsoft.Network/routeTables/rt-spoke-eastus'
param existingLogAnalyticsWorkspaceResourceId = '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-management/providers/Microsoft.OperationalInsights/workspaces/law-central-eastus'
param privateDnsZoneResourceIds = {
  blob: '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/RG-PRIVATEDNS-PR/providers/Microsoft.Network/privateDnsZones/privatelink.blob.core.windows.net'
  queue: '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/RG-PRIVATEDNS-PR/providers/Microsoft.Network/privateDnsZones/privatelink.queue.core.windows.net'
  table: '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/RG-PRIVATEDNS-PR/providers/Microsoft.Network/privateDnsZones/privatelink.table.core.windows.net'
  cognitiveServicesAccount: '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/RG-PRIVATEDNS-PR/providers/Microsoft.Network/privateDnsZones/privatelink.cognitiveservices.azure.com'
  openAi: '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/RG-PRIVATEDNS-PR/providers/Microsoft.Network/privateDnsZones/privatelink.openai.azure.com'
  aiServices: '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/RG-PRIVATEDNS-PR/providers/Microsoft.Network/privateDnsZones/privatelink.services.ai.azure.com'
  Sql: '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/RG-PRIVATEDNS-PR/providers/Microsoft.Network/privateDnsZones/privatelink.documents.azure.com'
  sites: '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/RG-PRIVATEDNS-PR/providers/Microsoft.Network/privateDnsZones/privatelink.azurewebsites.net'
  dataFactory: '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/RG-PRIVATEDNS-PR/providers/Microsoft.Network/privateDnsZones/privatelink.datafactory.azure.net'
  portal: '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/RG-PRIVATEDNS-PR/providers/Microsoft.Network/privateDnsZones/privatelink.adf.azure.com'
  databricks_ui_api: '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/RG-PRIVATEDNS-PR/providers/Microsoft.Network/privateDnsZones/privatelink.azuredatabricks.net'
  browser_authentication: '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/RG-PRIVATEDNS-PR/providers/Microsoft.Network/privateDnsZones/privatelink.azuredatabricks.net'
}
param tenantId = '00000000-0000-0000-0000-000000000000'
param functionAuthenticationClientId = '00000000-0000-0000-0000-000000000000'

// Ejemplo: IPAM debe asignar los CIDR reales sin solapamientos.
param vnetAddressPrefixes = [
  '10.180.0.0/21'
]
param subnetPrefixes = {
  privateEndpoints: '10.180.0.0/24'
  foundryAgents: '10.180.1.0/24'
  functionsIntegration: '10.180.2.0/26'
  databricksPublic: '10.180.3.0/26'
  databricksPrivate: '10.180.4.0/26'
}

param deployGroundingWithBing = true
param groundingComplianceExceptionId = 'REPLACE-WITH-APPROVED-EXCEPTION-ID'

// Selección histórica: confirmar versión, modalidad, cuota y residencia antes de activar.
param foundryModelDeployments = [
  {
    name: 'gpt-4'
    model: 'gpt-4.1'
    version: '2025-04-14'
    sku: 'GlobalStandard'
    capacity: 100
    raiPolicy: 'Microsoft.DefaultV2'
  }
  {
    name: 'gpt-5-mini'
    model: 'gpt-5-mini'
    version: '2025-08-07'
    sku: 'GlobalStandard'
    capacity: 150
    raiPolicy: 'Microsoft.DefaultV2'
  }
  {
    name: 'o4-mini'
    model: 'o4-mini'
    version: '2025-04-16'
    sku: 'GlobalStandard'
    capacity: 150
    raiPolicy: 'Microsoft.DefaultV2'
  }
]

// Selección histórica: confirmar versión, modalidad, cuota y residencia antes de activar.
param openAiModelDeployments = [
  {
    name: 'gpt-4o'
    model: 'gpt-4o'
    version: '2024-08-06'
    sku: 'GlobalStandard'
    capacity: 51
    raiPolicy: 'Microsoft.DefaultV2'
  }
  {
    name: 'gpt-4o-batch'
    model: 'gpt-4o'
    version: '2024-08-06'
    sku: 'GlobalBatch'
    capacity: 65979
    raiPolicy: 'Microsoft.DefaultV2'
  }
]

param apiClientPrefixes = []
param operatorPrefixes = []
param monitorPrefixes = []
param cosmosPrivateIps = []
param functionPrivateIps = []
param functionAllowedPrincipalIds = []
param extraEgress = []
param activateWorkload = false
param networkVerified = false
param defenderVerified = false
param siemVerified = false
param applicationVerified = false
param uploadGateVerified = false
param scanUploads = true
param securityApprovalId = ''
param modelsApproved = false
param siemAuthorizationRuleId = ''
param siemEventHubName = ''

param actionGroupResourceId = ''
