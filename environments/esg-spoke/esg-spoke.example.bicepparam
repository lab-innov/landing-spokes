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
  DataClassification: 'confirm-before-deployment'
}

// Replace every platform placeholder with values approved by the connectivity team.
param hubVnetResourceId = '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-connectivity/providers/Microsoft.Network/virtualNetworks/vnet-hub-eastus'
param existingRouteTableResourceId = '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-connectivity/providers/Microsoft.Network/routeTables/rt-spoke-eastus'
param existingLogAnalyticsWorkspaceResourceId = '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-management/providers/Microsoft.OperationalInsights/workspaces/law-central-eastus'
param tenantId = '00000000-0000-0000-0000-000000000000'
param functionAuthenticationClientId = '00000000-0000-0000-0000-000000000000'

// Example only. Corporate IPAM must approve non-overlapping production CIDRs.
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
