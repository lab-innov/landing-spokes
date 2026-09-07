using '../../infra/ifiscaf-spoke/main.bicep'

param location = 'eastus'
param resourceGroupName = 'rg-ifiscaf-secure-spoke-dev'
param namePrefix = 'ifisdev'
param tags = {
  CC: 'Innovacion'
  OpsDept: 'GPFEI'
  Proyecto: 'PoC IFISCAF'
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

// Existing shared input. The deployment requires RBAC and private-endpoint approval on this account.
param sharedSyntheticStorageAccountResourceId = '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/RG-POC-iDataFactory-CR/providers/Microsoft.Storage/storageAccounts/sapocidatafactorycr'
param sharedSyntheticContainerName = 'datasintetica'

// Example only. Corporate IPAM must approve non-overlapping production CIDRs.
param vnetAddressPrefixes = [
  '10.181.0.0/21'
]
param subnetPrefixes = {
  privateEndpoints: '10.181.0.0/24'
  functionsIntegration: '10.181.1.0/26'
  databricksPublic: '10.181.2.0/26'
  databricksPrivate: '10.181.3.0/26'
}
