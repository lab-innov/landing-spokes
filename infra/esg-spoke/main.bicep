targetScope = 'subscription'

type modelDeploymentType = {
  name: string
  model: string
  version: string
  sku: string
  @minValue(1)
  capacity: int
  raiPolicy: string
}

type subnetPrefixesType = {
  privateEndpoints: string
  foundryAgents: string
  functionsIntegration: string
  databricksPublic: string
  databricksPrivate: string
}

@description('Región Azure para los recursos del spoke ESG.')
param location string = 'eastus'

@description('Nuevo grupo de recursos para la migración paralela de ESG.')
param resourceGroupName string

@description('Prefijo corto en minúsculas para nombres de recursos.')
@minLength(2)
@maxLength(12)
param namePrefix string = 'esg'

@description('Etiquetas de todos los recursos; iniciativa y clasificación son obligatorias.')
param tags object

@description('ID de VNet hub corporativa; plataforma crea el peering inverso.')
@minLength(1)
param hubVnetResourceId string

@description('ID de tabla de rutas corporativa asociada a las subredes ESG.')
@minLength(1)
param existingRouteTableResourceId string

@description('ID de Log Analytics central existente.')
@minLength(1)
param existingLogAnalyticsWorkspaceResourceId string

@description('Tenant Entra de la autenticación de la Function.')
@minLength(1)
param tenantId string

@description('Client ID del registro Entra de la API privada.')
@minLength(1)
param functionAuthenticationClientId string

@description('Prefijos de VNet asignados por IPAM corporativo.')
param vnetAddressPrefixes array

@description('CIDR de las cinco subredes ESG; no reutilizar el /24 del patrón Foundry web.')
param subnetPrefixes subnetPrefixesType

@description('Crear Grounding con salida pública expresamente aprobada.')
param deployGroundingWithBing bool = false

@description('Identificador de excepción corporativa requerido al habilitar Grounding.')
param groundingComplianceExceptionId string = ''

@description('Modelos Foundry explícitos; confirmar región, versión y cuota.')
param foundryModelDeployments modelDeploymentType[] = []

@description('Modelos OpenAI separados conservados para la funcionalidad ESG.')
param openAiModelDeployments modelDeploymentType[] = []

@description('DNS corporativos que resuelven las zonas privadas CAF.')
@minLength(1)
param dnsServers string[]
param useRemoteGateways bool = false
@description('Redes autorizadas para llamar a la Function por VPN/APIM.')
param apiClientPrefixes string[] = []
param operatorPrefixes string[] = []
param monitorPrefixes string[] = []
@description('IP reales de los endpoints Cosmos y Function, descubiertas tras la fundación.')
param cosmosPrivateIps string[] = []
param functionPrivateIps string[] = []
@description('Salidas adicionales TCP autorizadas por CAF: purpose, destination, ports, justification.')
param extraEgress array = []
@description('Object IDs de usuarios o identidades autorizados en la Function; no son client IDs ni grupos.')
@maxLength(13)
param functionAllowedPrincipalIds string[] = []
@description('Activar la Function después de la fundación y las pruebas de seguridad.')
param activateWorkload bool = false
param networkVerified bool = false
param defenderVerified bool = false
param siemVerified bool = false
param applicationVerified bool = false
param scanUploads bool = true
param uploadGateVerified bool = false
param securityApprovalId string = ''
@description('Destino SIEM corporativo opcional; ambos campos vacíos usan el pipeline de Log Analytics.')
param siemAuthorizationRuleId string = ''
param siemEventHubName string = ''
param actionGroupResourceId string = ''
@minValue(1)
param functionRequestsAlertThreshold int = 10000
@description('Confirmación explícita de modelos/versiones, cuotas y residencia de datos.')
param modelsApproved bool = false
@description('Permisos adicionales del host cuando el código utiliza triggers Blob o Durable Functions.')
param functionUsesBlobTriggers bool = false
param functionUsesDurableStorage bool = false

var token = toLower(uniqueString(subscription().id, resourceGroupName, location))
var normalizedPrefix = toLower(replace(namePrefix, '-', ''))
var names = {
  vnet: 'vnet-${namePrefix}-secure-${token}'
  applicationInsights: 'appi-${namePrefix}-secure-${token}'
  workloadStorage: take('st${normalizedPrefix}data${token}', 24)
  functionStorage: take('st${normalizedPrefix}func${token}', 24)
  foundryAccount: take('aif-${namePrefix}-${token}', 64)
  foundryProject: 'esg-project'
  openAiAccount: take('oai-${namePrefix}-${token}', 64)
  documentIntelligence: take('di-${namePrefix}-${token}', 64)
  cosmos: take('cosmos-${namePrefix}-${token}', 44)
  databricks: take('dbw-${namePrefix}-${token}', 64)
  databricksAccessConnector: take('dbac-${namePrefix}-${token}', 64)
  databricksManagedResourceGroup: take('rg-dbw-${namePrefix}-${token}', 90)
  dataFactory: take('adf-${namePrefix}-${token}', 63)
  functionPlan: take('asp-${namePrefix}-${token}', 40)
  functionApp: take('func-${namePrefix}-${token}', 60)
  grounding: take('grounding-${namePrefix}-${token}', 64)
}

resource spokeResourceGroup 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: resourceGroupName
  location: location
  tags: tags
}

module contracts './modules/contracts.bicep' = {
  name: 'esg-contratos'
  scope: spokeResourceGroup
  params: {
    validSecurity: any(toLower(resourceGroupName) != 'rg-poc-esg-cr' && !empty(tags.?DataClassification ?? '') && !empty(tags.?iniciativa ?? '') && (empty(siemAuthorizationRuleId) == empty(siemEventHubName)))
    validGrounding: any(!deployGroundingWithBing || (!empty(groundingComplianceExceptionId) && !startsWith(groundingComplianceExceptionId, 'REPLACE')))
    validModels: any(modelsApproved || (empty(foundryModelDeployments) && empty(openAiModelDeployments)))
    validActivation: any(!activateWorkload || (!empty(actionGroupResourceId) && networkVerified && defenderVerified && siemVerified && applicationVerified && (!scanUploads || uploadGateVerified) && !empty(securityApprovalId) && !empty(functionAllowedPrincipalIds) && !empty(functionPrivateIps) && !empty(cosmosPrivateIps) && !empty(apiClientPrefixes) && !empty(monitorPrefixes)))
  }
}

module network './modules/network.bicep' = {
  name: 'esg-network'
  scope: spokeResourceGroup
  params: {
    location: location
    tags: tags
    vnetName: names.vnet
    vnetAddressPrefixes: vnetAddressPrefixes
    subnetPrefixes: subnetPrefixes
    routeTableResourceId: existingRouteTableResourceId
    hubVnetResourceId: hubVnetResourceId
    dnsServers: dnsServers
    useRemoteGateways: useRemoteGateways
    apiClientPrefixes: apiClientPrefixes
    operatorPrefixes: operatorPrefixes
    monitorPrefixes: monitorPrefixes
    cosmosPrivateIps: cosmosPrivateIps
    functionPrivateIps: functionPrivateIps
    extraEgress: extraEgress
  }
  dependsOn: [contracts]
}

module monitoring './modules/monitoring.bicep' = {
  name: 'esg-monitoring'
  scope: spokeResourceGroup
  params: {
    location: location
    tags: tags
    applicationInsightsName: names.applicationInsights
    logAnalyticsWorkspaceResourceId: existingLogAnalyticsWorkspaceResourceId
  }
  dependsOn: [contracts]
}

module workloadStorage './modules/storage-account.bicep' = {
  name: 'esg-workload-storage'
  scope: spokeResourceGroup
  params: {
    location: location
    tags: tags
    storageAccountName: names.workloadStorage
    containerNames: [
      'esg-files'
      'poc-esg-trigger-data-factory'
    ]
    logAnalyticsWorkspaceResourceId: existingLogAnalyticsWorkspaceResourceId
    siemAuthorizationRuleId: siemAuthorizationRuleId
    siemEventHubName: siemEventHubName
  }
  dependsOn: [contracts]
}

module functionStorage './modules/storage-account.bicep' = {
  name: 'esg-function-storage'
  scope: spokeResourceGroup
  params: {
    location: location
    tags: tags
    storageAccountName: names.functionStorage
    containerNames: []
    logAnalyticsWorkspaceResourceId: existingLogAnalyticsWorkspaceResourceId
    siemAuthorizationRuleId: siemAuthorizationRuleId
    siemEventHubName: siemEventHubName
  }
  dependsOn: [contracts]
}

module foundry './modules/ai-foundry.bicep' = {
  name: 'esg-foundry'
  scope: spokeResourceGroup
  params: {
    location: location
    tags: tags
    accountName: names.foundryAccount
    projectName: names.foundryProject
    agentSubnetResourceId: network.outputs.foundryAgentSubnetId
    modelDeployments: foundryModelDeployments
    deployGroundingWithBing: deployGroundingWithBing
    groundingName: names.grounding
    groundingConnectionName: 'grounding-web-search'
    groundingComplianceExceptionId: groundingComplianceExceptionId
    logAnalyticsWorkspaceResourceId: existingLogAnalyticsWorkspaceResourceId
    siemAuthorizationRuleId: siemAuthorizationRuleId
    siemEventHubName: siemEventHubName
  }
  dependsOn: [contracts]
}

module openAi './modules/cognitive-account.bicep' = {
  name: 'esg-openai'
  scope: spokeResourceGroup
  params: {
    location: location
    tags: tags
    accountName: names.openAiAccount
    kind: 'OpenAI'
    modelDeployments: openAiModelDeployments
    logAnalyticsWorkspaceResourceId: existingLogAnalyticsWorkspaceResourceId
    siemAuthorizationRuleId: siemAuthorizationRuleId
    siemEventHubName: siemEventHubName
  }
  dependsOn: [contracts]
}

module documentIntelligence './modules/cognitive-account.bicep' = {
  name: 'esg-document-intelligence'
  scope: spokeResourceGroup
  params: {
    location: location
    tags: tags
    accountName: names.documentIntelligence
    kind: 'FormRecognizer'
    modelDeployments: []
    logAnalyticsWorkspaceResourceId: existingLogAnalyticsWorkspaceResourceId
    siemAuthorizationRuleId: siemAuthorizationRuleId
    siemEventHubName: siemEventHubName
  }
  dependsOn: [contracts]
}

module cosmos './modules/cosmos-db.bicep' = {
  name: 'esg-cosmos'
  scope: spokeResourceGroup
  params: {
    location: location
    tags: tags
    accountName: names.cosmos
    databaseName: 'esg-db'
    logAnalyticsWorkspaceResourceId: existingLogAnalyticsWorkspaceResourceId
    siemAuthorizationRuleId: siemAuthorizationRuleId
    siemEventHubName: siemEventHubName
  }
  dependsOn: [contracts]
}

module databricks './modules/databricks.bicep' = {
  name: 'esg-databricks'
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
    siemAuthorizationRuleId: siemAuthorizationRuleId
    siemEventHubName: siemEventHubName
  }
  dependsOn: [contracts]
}

module dataFactory './modules/data-factory.bicep' = {
  name: 'esg-data-factory'
  scope: spokeResourceGroup
  params: {
    location: location
    tags: tags
    factoryName: names.dataFactory
    workloadStorageResourceId: workloadStorage.outputs.resourceId
    databricksWorkspaceResourceId: databricks.outputs.resourceId
    logAnalyticsWorkspaceResourceId: existingLogAnalyticsWorkspaceResourceId
    siemAuthorizationRuleId: siemAuthorizationRuleId
    siemEventHubName: siemEventHubName
  }
  dependsOn: [contracts]
}

module functionApp './modules/function-app.bicep' = {
  name: 'esg-function-app'
  scope: spokeResourceGroup
  params: {
    location: location
    tags: tags
    planName: names.functionPlan
    functionAppName: names.functionApp
    hostStorageAccountName: functionStorage.outputs.name
    integrationSubnetResourceId: network.outputs.functionsIntegrationSubnetId
    tenantId: tenantId
    authenticationClientId: functionAuthenticationClientId
    actionGroupResourceId: actionGroupResourceId
    requestsAlertThreshold: functionRequestsAlertThreshold
    allowedPrincipalIds: functionAllowedPrincipalIds
    activateWorkload: activateWorkload
    applicationInsightsConnectionString: monitoring.outputs.connectionString
    logAnalyticsWorkspaceResourceId: existingLogAnalyticsWorkspaceResourceId
    siemAuthorizationRuleId: siemAuthorizationRuleId
    siemEventHubName: siemEventHubName
  }
  dependsOn: [contracts]
}

var privateEndpointSpecs = concat([
  {
    name: 'pe-${names.workloadStorage}-blob'
    resourceId: workloadStorage.outputs.resourceId
    groupIds: [
      'blob'
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
    name: 'pe-${names.foundryAccount}'
    resourceId: foundry.outputs.accountResourceId
    groupIds: [
      'account'
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
], [])

module privateEndpoints './modules/private-endpoints.bicep' = {
  name: 'esg-private-endpoints'
  scope: spokeResourceGroup
  params: {
    location: location
    tags: tags
    subnetResourceId: network.outputs.peSubnetId
    endpoints: privateEndpointSpecs
  }
}

module roleAssignments './modules/role-assignments.bicep' = {
  name: 'esg-role-assignments'
  scope: spokeResourceGroup
  params: {
    functionUsesBlobTriggers: functionUsesBlobTriggers
    functionUsesDurableStorage: functionUsesDurableStorage
    workloadStorageName: workloadStorage.outputs.name
    functionStorageName: functionStorage.outputs.name
    cosmosAccountName: cosmos.outputs.name
    foundryAccountName: foundry.outputs.accountName
    openAiAccountName: openAi.outputs.name
    documentIntelligenceAccountName: documentIntelligence.outputs.name
    databricksWorkspaceName: databricks.outputs.name
    functionPrincipalId: functionApp.outputs.principalId
    dataFactoryPrincipalId: dataFactory.outputs.principalId
    foundryProjectPrincipalId: foundry.outputs.projectPrincipalId
    databricksAccessConnectorPrincipalId: databricks.outputs.accessConnectorPrincipalId
  }
}

output resourceGroupId string = spokeResourceGroup.id
output vnetId string = network.outputs.vnetId
output spokeToHubPeeringId string = network.outputs.spokeToHubPeeringId
output reversePeeringRequired bool = true
output routeTableResourceId string = existingRouteTableResourceId
output centralLogAnalyticsWorkspaceResourceId string = existingLogAnalyticsWorkspaceResourceId
output privateEndpointIds array = privateEndpoints.outputs.resourceIds
output foundryAccountId string = foundry.outputs.accountResourceId
output foundryProjectId string = foundry.outputs.projectResourceId
output foundryProjectEndpoint string = foundry.outputs.projectEndpoint
output groundingResourceId string = foundry.outputs.groundingResourceId
output groundingConnectionId string = foundry.outputs.groundingConnectionId
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
output foundryProjectPrincipalId string = foundry.outputs.projectPrincipalId
output dnsOwnership string = 'DNS central mediante DINE y resolver corporativo; no se crean zonas ni grupos DNS locales.'
output platformActions array = [
  'Crear peering inverso hub a spoke.'
  'Verificar integración DINE y resolución central de cada endpoint privado.'
  'Aprobar endpoints administrados de ADF hacia Storage y Databricks.'
  'Asociar Application Insights al AMPLS corporativo y comprobar ingestión y consulta privadas.'
]

output securityResourceIds object = { workloadStorage: workloadStorage.outputs.resourceId, functionStorage: functionStorage.outputs.resourceId, cosmos: cosmos.outputs.resourceId, foundry: foundry.outputs.accountResourceId, openAi: openAi.outputs.resourceId, functionApp: functionApp.outputs.resourceId, databricks: databricks.outputs.resourceId }
