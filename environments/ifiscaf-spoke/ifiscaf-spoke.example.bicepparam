using '../../infra/ifiscaf-spoke/main.bicep'

param location = 'eastus'
param resourceGroupName = 'rg-ifiscaf-secure-spoke-dev'
param namePrefix = 'ifisdev'
param tags = {
  CC: 'Innovacion'
  OpsDept: 'DTI'
  Proyecto: 'PoC IFISCAF'
  UserDept: 'GPFEI'
  Environment: 'dev'
  DataClassification: 'confirm-before-deployment'
}

// Replace every platform placeholder with values approved by the connectivity team.
param existingRouteTableResourceId = '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-connectivity/providers/Microsoft.Network/routeTables/rt-spoke-eastus'
param existingLogAnalyticsWorkspaceResourceId = '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-management/providers/Microsoft.OperationalInsights/workspaces/law-central-eastus'
param privateDnsZoneResourceIds = {
  blob: '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/RG-PRIVATEDNS-PR/providers/Microsoft.Network/privateDnsZones/privatelink.blob.core.windows.net'
  dfs: '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/RG-PRIVATEDNS-PR/providers/Microsoft.Network/privateDnsZones/privatelink.dfs.core.windows.net'
  queue: '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/RG-PRIVATEDNS-PR/providers/Microsoft.Network/privateDnsZones/privatelink.queue.core.windows.net'
  table: '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/RG-PRIVATEDNS-PR/providers/Microsoft.Network/privateDnsZones/privatelink.table.core.windows.net'
  cognitiveServicesAccount: '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/RG-PRIVATEDNS-PR/providers/Microsoft.Network/privateDnsZones/privatelink.cognitiveservices.azure.com'
  openAi: '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/RG-PRIVATEDNS-PR/providers/Microsoft.Network/privateDnsZones/privatelink.openai.azure.com'
  Sql: '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/RG-PRIVATEDNS-PR/providers/Microsoft.Network/privateDnsZones/privatelink.documents.azure.com'
  sites: '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/RG-PRIVATEDNS-PR/providers/Microsoft.Network/privateDnsZones/privatelink.azurewebsites.net'
  dataFactory: '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/RG-PRIVATEDNS-PR/providers/Microsoft.Network/privateDnsZones/privatelink.datafactory.azure.net'
  portal: '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/RG-PRIVATEDNS-PR/providers/Microsoft.Network/privateDnsZones/privatelink.adf.azure.com'
  databricks_ui_api: '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/RG-PRIVATEDNS-PR/providers/Microsoft.Network/privateDnsZones/privatelink.azuredatabricks.net'
  browser_authentication: '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/RG-PRIVATEDNS-PR/providers/Microsoft.Network/privateDnsZones/privatelink.azuredatabricks.net'
}
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
