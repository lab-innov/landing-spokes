using '../../infra/esg-spoke/main.bicep'

param location = 'eastus'
param resourceGroupName = 'rg-esg-secure-spoke-dev'
param namePrefix = 'esgdev'
param tags = {
  CC: 'Innovacion'
  OpsDept: 'GPFEI'
  Proyecto: 'PoC ESG'
  UserDept: 'GPFEI'
  Environment: 'dev'
  DataClassification: 'REPLACE-WITH-CLASSIFICATION'
  iniciativa: 'ESG'
}

// Sustituir los marcadores por valores aprobados por plataforma.
param hubVnetResourceId = '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-connectivity/providers/Microsoft.Network/virtualNetworks/vnet-hub-eastus'
param existingRouteTableResourceId = '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-connectivity/providers/Microsoft.Network/routeTables/rt-spoke-eastus'
param existingLogAnalyticsWorkspaceResourceId = '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-management/providers/Microsoft.OperationalInsights/workspaces/law-central-eastus'
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

param dnsServers = ['REPLACE-WITH-CORPORATE-DNS']
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
