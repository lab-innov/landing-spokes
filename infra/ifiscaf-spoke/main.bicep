targetScope = 'subscription'

type modelDeploymentType = {
  name: string
  model: string
  version: string
  sku: string
  capacity: int
  raiPolicy: string
}

type subnetPrefixesType = {
  privateEndpoints: string
  functionsIntegration: string
  databricksPublic: string
  databricksPrivate: string
}

type cosmosLocationType = {
  locationName: string
  failoverPriority: int
  isZoneRedundant: bool
}

@description('Azure region for all IFISCAF spoke resources.')
param location string = 'eastus'

@description('New resource group for the parallel secure IFISCAF spoke.')
param resourceGroupName string

@description('Short lowercase workload prefix used in resource names.')
@minLength(2)
@maxLength(12)
param namePrefix string = 'ifiscaf'

@description('Tags applied to every resource.')
param tags object

@description('Existing platform-managed route table resource ID associated with every spoke subnet.')
@minLength(1)
param existingRouteTableResourceId string

@description('Existing central Log Analytics workspace resource ID.')
@minLength(1)
param existingLogAnalyticsWorkspaceResourceId string

@description('IDs completos de zonas DNS privadas centralizadas en RG-PRIVATEDNS-PR, indexados por groupId.')
param privateDnsZoneResourceIds object

@description('Microsoft Entra tenant ID used by Function App authentication.')
@minLength(1)
param tenantId string

@description('Client ID of the Entra application registration representing the private Function API.')
@minLength(1)
param functionAuthenticationClientId string

@description('Spoke VNet address prefixes allocated by corporate IPAM.')
param vnetAddressPrefixes array

@description('CIDRs for private endpoints, Function integration, and both Databricks VNet-injection subnets.')
param subnetPrefixes subnetPrefixesType

@description('Existing shared synthetic-data storage account resource ID.')
@minLength(1)
param sharedSyntheticStorageAccountResourceId string

@description('Container in the shared synthetic-data storage account.')
param sharedSyntheticContainerName string = 'datasintetica'

@description('Azure OpenAI model deployments. Validate regional availability and quota before deployment.')
param openAiModelDeployments modelDeploymentType[] = [
  {
    name: 'gpt-4o-batch'
    model: 'gpt-4o'
    version: '2024-08-06'
    sku: 'GlobalBatch'
    capacity: 60009
    raiPolicy: 'Microsoft.DefaultV2'
  }
]

@description('Deployment name used by the Function application after its managed-identity migration.')
param functionOpenAiDeploymentName string = 'gpt-4o-batch'

@description('Cosmos DB account regions. The default preserves the current East US and West US topology.')
param cosmosLocations cosmosLocationType[] = [
  {
    locationName: 'East US'
    failoverPriority: 0
    isZoneRedundant: false
  }
  {
    locationName: 'West US'
    failoverPriority: 1
    isZoneRedundant: false
  }
]

var token = toLower(uniqueString(subscription().id, resourceGroupName, location))
var normalizedPrefix = toLower(replace(namePrefix, '-', ''))
var sharedStorageResourceIdSegments = split(sharedSyntheticStorageAccountResourceId, '/')
var sharedStorageSubscriptionId = sharedStorageResourceIdSegments[2]
var sharedStorageResourceGroupName = sharedStorageResourceIdSegments[4]
var sharedStorageAccountName = sharedStorageResourceIdSegments[8]
var names = {
  vnet: 'vnet-${namePrefix}-secure-${token}'
  workloadStorage: take('st${normalizedPrefix}data${token}', 24)
  functionStorage: take('st${normalizedPrefix}func${token}', 24)
  openAiAccount: take('oai-${namePrefix}-${token}', 64)
  documentIntelligence: take('di-${namePrefix}-${token}', 64)
  cosmos: take('cosmos-${namePrefix}-${token}', 44)
  databricks: take('dbw-${namePrefix}-${token}', 64)
  databricksAccessConnector: take('dbac-${namePrefix}-${token}', 64)
  databricksManagedResourceGroup: take('rg-dbw-${namePrefix}-${token}', 90)
  dataFactory: take('adf-${namePrefix}-${token}', 63)
  functionPlan: take('asp-${namePrefix}-${token}', 40)
  functionApp: take('func-${namePrefix}-${token}', 60)
}

resource spokeResourceGroup 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: resourceGroupName
  location: location
  tags: tags
}

module network './modules/network.bicep' = {
  name: 'ifiscaf-network'
  scope: spokeResourceGroup
  params: {
    location: location
    tags: tags
    vnetName: names.vnet
    vnetAddressPrefixes: vnetAddressPrefixes
    subnetPrefixes: subnetPrefixes
    routeTableResourceId: existingRouteTableResourceId
  }
}

module workloadStorage './modules/storage-account.bicep' = {
  name: 'ifiscaf-workload-storage'
  scope: spokeResourceGroup
  params: {
    location: location
    tags: tags
    storageAccountName: names.workloadStorage
    containerNames: [
      'source'
      'sypdocuments'
    ]
    isHnsEnabled: true
    logAnalyticsWorkspaceResourceId: existingLogAnalyticsWorkspaceResourceId
  }
}

module functionStorage './modules/storage-account.bicep' = {
  name: 'ifiscaf-function-storage'
  scope: spokeResourceGroup
  params: {
    location: location
    tags: tags
    storageAccountName: names.functionStorage
    containerNames: []
    isHnsEnabled: false
    logAnalyticsWorkspaceResourceId: existingLogAnalyticsWorkspaceResourceId
  }
}

module openAi './modules/cognitive-account.bicep' = {
  name: 'ifiscaf-openai'
  scope: spokeResourceGroup
  params: {
    location: location
    tags: tags
    accountName: names.openAiAccount
    kind: 'OpenAI'
    modelDeployments: openAiModelDeployments
    logAnalyticsWorkspaceResourceId: existingLogAnalyticsWorkspaceResourceId
  }
}

module documentIntelligence './modules/cognitive-account.bicep' = {
  name: 'ifiscaf-document-intelligence'
  scope: spokeResourceGroup
  params: {
    location: location
    tags: tags
    accountName: names.documentIntelligence
    kind: 'FormRecognizer'
    modelDeployments: []
    logAnalyticsWorkspaceResourceId: existingLogAnalyticsWorkspaceResourceId
  }
}

module cosmos './modules/cosmos-db.bicep' = {
  name: 'ifiscaf-cosmos'
  scope: spokeResourceGroup
  params: {
    location: location
    tags: tags
    accountName: names.cosmos
    databaseName: 'IfisCAF'
    containerName: 'Reportes'
    containerThroughput: 400
    accountLocations: cosmosLocations
    logAnalyticsWorkspaceResourceId: existingLogAnalyticsWorkspaceResourceId
  }
}

module databricks './modules/databricks.bicep' = {
  name: 'ifiscaf-databricks'
  scope: spokeResourceGroup
  params: {
    location: location
    tags: tags
    workspaceName: names.databricks
    accessConnectorName: names.databricksAccessConnector
    vnetResourceId: network.outputs.vnetId
    publicSubnetName: network.outputs.databricksPublicSubnetName
    privateSubnetName: network.outputs.databricksPrivateSubnetName
    managedResourceGroupName: names.databricksManagedResourceGroup
    logAnalyticsWorkspaceResourceId: existingLogAnalyticsWorkspaceResourceId
  }
}

module dataFactory './modules/data-factory.bicep' = {
  name: 'ifiscaf-data-factory'
  scope: spokeResourceGroup
  params: {
    location: location
    tags: tags
    factoryName: names.dataFactory
    workloadStorageResourceId: workloadStorage.outputs.resourceId
    sharedSyntheticStorageResourceId: sharedSyntheticStorageAccountResourceId
    databricksWorkspaceResourceId: databricks.outputs.resourceId
    logAnalyticsWorkspaceResourceId: existingLogAnalyticsWorkspaceResourceId
  }
}

module functionApp './modules/function-app.bicep' = {
  name: 'ifiscaf-function-app'
  scope: spokeResourceGroup
  params: {
    location: location
    tags: tags
    planName: names.functionPlan
    functionAppName: names.functionApp
    hostStorageAccountName: functionStorage.outputs.name
    workloadStorageAccountName: workloadStorage.outputs.name
    sourceContainerName: 'source'
    documentsContainerName: 'sypdocuments'
    cosmosAccountName: cosmos.outputs.name
    cosmosDatabaseName: cosmos.outputs.databaseName
    cosmosContainerName: cosmos.outputs.containerName
    openAiAccountName: openAi.outputs.name
    openAiDeploymentName: functionOpenAiDeploymentName
    documentIntelligenceAccountName: documentIntelligence.outputs.name
    integrationSubnetResourceId: network.outputs.functionsIntegrationSubnetId
    tenantId: tenantId
    authenticationClientId: functionAuthenticationClientId
    logAnalyticsWorkspaceResourceId: existingLogAnalyticsWorkspaceResourceId
  }
}

var privateEndpointSpecs = [
  {
    name: 'pe-${names.workloadStorage}-blob'
    resourceId: workloadStorage.outputs.resourceId
    groupIds: [
      'blob'
    ]
  }
  {
    name: 'pe-${names.workloadStorage}-dfs'
    resourceId: workloadStorage.outputs.resourceId
    groupIds: [
      'dfs'
    ]
  }
  {
    name: 'pe-${names.functionStorage}-blob'
    resourceId: functionStorage.outputs.resourceId
    groupIds: [
      'blob'
    ]
  }
  {
    name: 'pe-${names.functionStorage}-queue'
    resourceId: functionStorage.outputs.resourceId
    groupIds: [
      'queue'
    ]
  }
  {
    name: 'pe-${names.functionStorage}-table'
    resourceId: functionStorage.outputs.resourceId
    groupIds: [
      'table'
    ]
  }
  {
    name: 'pe-${names.openAiAccount}'
    resourceId: openAi.outputs.resourceId
    groupIds: [
      'account'
    ]
  }
  {
    name: 'pe-${names.documentIntelligence}'
    resourceId: documentIntelligence.outputs.resourceId
    groupIds: [
      'account'
    ]
  }
  {
    name: 'pe-${names.cosmos}'
    resourceId: cosmos.outputs.resourceId
    groupIds: [
      'Sql'
    ]
  }
  {
    name: 'pe-${names.functionApp}-site'
    resourceId: functionApp.outputs.resourceId
    groupIds: [
      'sites'
    ]
  }
  {
    name: 'pe-${names.dataFactory}-factory'
    resourceId: dataFactory.outputs.resourceId
    groupIds: [
      'dataFactory'
    ]
  }
  {
    name: 'pe-${names.dataFactory}-portal'
    resourceId: dataFactory.outputs.resourceId
    groupIds: [
      'portal'
    ]
  }
  {
    name: 'pe-${names.databricks}-ui'
    resourceId: databricks.outputs.resourceId
    groupIds: [
      'databricks_ui_api'
    ]
  }
  {
    name: 'pe-${names.databricks}-auth'
    resourceId: databricks.outputs.resourceId
    groupIds: [
      'browser_authentication'
    ]
  }
  {
    name: 'pe-shared-synthetic-storage-blob'
    resourceId: sharedSyntheticStorageAccountResourceId
    groupIds: [
      'blob'
    ]
  }
]

module privateEndpoints './modules/private-endpoints.bicep' = {
  name: 'ifiscaf-private-endpoints'
  scope: spokeResourceGroup
  params: {
    location: location
    tags: tags
    subnetResourceId: network.outputs.peSubnetId
    endpoints: privateEndpointSpecs
    privateDnsZoneResourceIds: privateDnsZoneResourceIds
  }
}

module roleAssignments './modules/role-assignments.bicep' = {
  name: 'ifiscaf-role-assignments'
  scope: spokeResourceGroup
  params: {
    workloadStorageName: workloadStorage.outputs.name
    functionStorageName: functionStorage.outputs.name
    cosmosAccountName: cosmos.outputs.name
    openAiAccountName: openAi.outputs.name
    documentIntelligenceAccountName: documentIntelligence.outputs.name
    databricksWorkspaceName: databricks.outputs.name
    functionPrincipalId: functionApp.outputs.principalId
    dataFactoryPrincipalId: dataFactory.outputs.principalId
    databricksAccessConnectorPrincipalId: databricks.outputs.accessConnectorPrincipalId
  }
}

module sharedInputAccess './modules/shared-input-access.bicep' = {
  name: 'ifiscaf-shared-input-access'
  scope: resourceGroup(sharedStorageSubscriptionId, sharedStorageResourceGroupName)
  params: {
    sharedStorageAccountName: sharedStorageAccountName
    sharedContainerName: sharedSyntheticContainerName
    databricksAccessConnectorPrincipalId: databricks.outputs.accessConnectorPrincipalId
  }
}

output resourceGroupId string = spokeResourceGroup.id
output vnetId string = network.outputs.vnetId
output routeTableResourceId string = existingRouteTableResourceId
output centralLogAnalyticsWorkspaceResourceId string = existingLogAnalyticsWorkspaceResourceId
output privateEndpointIds array = privateEndpoints.outputs.resourceIds
output openAiAccountId string = openAi.outputs.resourceId
output documentIntelligenceAccountId string = documentIntelligence.outputs.resourceId
output workloadStorageAccountId string = workloadStorage.outputs.resourceId
output functionStorageAccountId string = functionStorage.outputs.resourceId
output cosmosDbAccountId string = cosmos.outputs.resourceId
output databricksWorkspaceId string = databricks.outputs.resourceId
output databricksWorkspaceUrl string = databricks.outputs.workspaceUrl
output databricksAccessConnectorId string = databricks.outputs.accessConnectorResourceId
output dataFactoryId string = dataFactory.outputs.resourceId
output dataFactoryName string = dataFactory.outputs.name
output functionAppId string = functionApp.outputs.resourceId
output functionAppHostname string = functionApp.outputs.hostname
output functionPrincipalId string = functionApp.outputs.principalId
output dataFactoryPrincipalId string = dataFactory.outputs.principalId
output sharedSyntheticContainerId string = sharedInputAccess.outputs.containerResourceId
output dnsOwnership string = 'Zonas centralizadas y grupos DNS asociados por este despliegue; no se crean zonas privadas.'
output platformActions array = [
  'Crear la conexión de Virtual WAN de producción fuera de este despliegue.'
  'Confirmar enlaces del resolver central para cada zona privada.'
  'Approve the private endpoint to the shared synthetic-data storage account.'
  'Approve Data Factory managed private endpoints to IFIS storage, shared storage, and Databricks.'
  'Configurar Dynatrace según el proceso de plataforma; no se crea Application Insights.'
  'Add the Data Factory managed identity to Databricks and grant Can Attach To on the Asset Bundle cluster.'
]
