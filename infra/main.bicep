targetScope = 'resourceGroup'

@description('Región aprobada con soporte Foundry BYO VNet y Storage ZRS.')
@allowed(['eastus'])
param location string = 'eastus'
type WorkloadTags = {
  @minLength(1)
  iniciativa: string
  *: string
}
param tags WorkloadTags
@description('Identificador estable del workload; no cambiar tras desplegar.')
@minLength(2)
@maxLength(12)
param workload string
@description('Bloque IPv4 /24 aprobado por IPAM; se derivan cuatro subredes.')
param vnetPrefix string
@minLength(1)
param dnsServers array
@minLength(1)
param hubVnetId string
@description('IDs de tablas corporativas: foundry, containers y appGateway.')
type CorporateRoutes = {
  @minLength(1)
  foundry: string
  @minLength(1)
  containers: string
  @minLength(1)
  appGateway: string
}
param routeTableIds CorporateRoutes
param useRemoteGateways bool = false
@minLength(1)
param cafClientPrefixes array
@minLength(1)
param logAnalyticsWorkspaceId string
@minLength(1)
param actionGroupId string
@description('Redes de operadores/ejecutores CAF que acceden a endpoints; no son todos los usuarios VPN.')
param operatorPrefixes array = []
@description('IP reales de endpoints privados, descubiertas tras la fundación: vault y cosmos.')
type PrivateServiceAddresses = { vault: string[], cosmos: string[] }
param privateServiceAddresses PrivateServiceAddresses = { vault: [], cosmos: [] }
@description('IP o CIDR de endpoints AMPLS corporativos.')
param monitorPrefixes array = []
@description('Excepciones de salida TCP por subred; cada una exige destino, puertos y justificación.')
type EgressRule = { destination: string, ports: string[], justification: string }
type EgressRules = { foundry: EgressRule[]?, containers: EgressRule[]?, appGateway: EgressRule[]?, privateEndpoints: EgressRule[]? }
param extraEgress EgressRules = { foundry: [], containers: [], appGateway: [], privateEndpoints: [] }
@description('Evidencia del preflight de Defender vigente para esta suscripción y recursos.')
param defenderCoverageVerified bool = false
@description('Confirmación del SOC de recepción de eventos de esta solución en el SIEM.')
param siemDeliveryVerified bool = false
@description('Regla de autorización del Event Hub corporativo para diagnósticos; vacío usa el pipeline central de Log Analytics.')
param siemAuthorizationRuleId string = ''
param siemEventHubName string = ''
@description('Exigir análisis de malware para cargas, heredado de CAF y verificado antes de activar.')
param scanUploads bool = true

@description('Confirmar que la aplicación espera análisis limpio antes de procesar archivos.')
param uploadGateVerified bool = false
@description('Nombres de secretos preexistentes de aplicación, sin acceso al certificado del gateway.')
param backendSecretNames array = []
@description('Confirmar DNS, endpoints, rutas y RBAC antes de activar runtime.')
param networkReady bool = false
@description('Confirmar autenticación/autorización Entra de las imágenes antes de activar la web.')
param applicationAuthVerified bool = false
@description('Confirmar AMPLS y resolución privada de telemetría antes de activar la web.')
param monitoringReady bool = false
@description('Confirmar certificado, DNS web y habilitación de gateway privado.')
param gatewayReady bool = false
@description('Activar después de verificar endpoints privados, DNS y propagación de RBAC.')
param activateAgentRuntime bool = false
@description('Modelos autorizados con name, model, version, sku y capacity. Vacío no despliega modelos.')
type ModelDeployment = {
  name: string
  model: string
  version: string
  sku: string
  @minValue(1)
  capacity: int
}
param models ModelDeployment[] = []
@description('Aprobación explícita de modelo, versión, modalidad, capacidad y residencia.')
param modelsApproved bool = false
@description('Identificador real de aprobación antes de activar runtime, aplicaciones o gateway.')
param securityApprovalId string = ''
@description('Activar después de publicar ambas imágenes en el ACR privado.')
param deployApplications bool = false
param frontendImage string = ''
param backendImage string = ''
param frontendPort int = 3000
param backendPort int = 8000
@description('Variables no secretas adicionales; deben corresponder al contrato real de cada imagen.')
type EnvironmentValue = {
  name: string
  value: string
}
param frontendEnv EnvironmentValue[] = []
param backendEnv EnvironmentValue[] = []
@description('Activar después de importar el certificado TLS en Key Vault y publicar DNS del sitio.')
param deployGateway bool = false
param gatewayPrivateIp string = ''
param gatewayHostname string = ''
@description('Nombre del secreto de certificado PFX en el Key Vault creado por esta plantilla.')
param certificateSecretName string = 'appgateway-tls'
param frontendHealthPath string = '/'

var reservedEnv = ['BACKEND_URL', 'AZURE_CLIENT_ID', 'AZURE_AI_PROJECT_ENDPOINT', 'AZURE_STORAGE_BLOB_ENDPOINT', 'AZURE_STORAGE_CONTAINER', 'AZURE_KEY_VAULT_URL', 'APPLICATIONINSIGHTS_CONNECTION_STRING']
var octets = split(split(vnetPrefix, '/')[0], '.')
var privateRange = octets[0] == '10' || (octets[0] == '192' && octets[1] == '168') || (octets[0] == '172' && int(octets[1]) >= 16 && int(octets[1]) <= 29)
var prefixes = {
  vnet: vnetPrefix
  foundry: cidrSubnet(vnetPrefix, 25, 0)
  containers: cidrSubnet(vnetPrefix, 26, 2)
  privateEndpoints: cidrSubnet(vnetPrefix, 27, 6)
  appGateway: cidrSubnet(vnetPrefix, 27, 7)
}
module contracts './modules/contracts.bicep' = {
  name: 'contratos-despliegue'
  params: {
    validNetwork: any(privateRange && parseCidr(vnetPrefix).cidr == 24 && parseCidr(vnetPrefix).network == split(vnetPrefix, '/')[0])
    validSecurity: any(!empty(tags.?DataClassification ?? '') && (empty(models) || modelsApproved) && (!(activateAgentRuntime || deployApplications || deployGateway) || !empty(securityApprovalId)) && (empty(siemAuthorizationRuleId) == empty(siemEventHubName)) && !contains(map(backendSecretNames, secret => toLower(secret)), toLower(certificateSecretName)) && empty(extraEgress.?privateEndpoints ?? []) && (!deployApplications || !empty(monitorPrefixes)))
    validEnvironment: any(empty(filter(concat(frontendEnv, backendEnv), entry => contains(reservedEnv, entry.name))))
    validRuntime: any(!activateAgentRuntime || (!empty(privateServiceAddresses.cosmos) && networkReady && defenderCoverageVerified && siemDeliveryVerified))
    validApps: any(!deployApplications || (activateAgentRuntime && applicationAuthVerified && monitoringReady && (!scanUploads || uploadGateVerified) && contains(frontendImage, '.azurecr.io/') && contains(frontendImage, '@sha256:') && contains(backendImage, '.azurecr.io/') && contains(backendImage, '@sha256:') && !empty(models)))
    validGateway: any(!deployGateway || (!empty(privateServiceAddresses.vault) && deployApplications && gatewayReady && !empty(gatewayHostname) && !empty(gatewayPrivateIp)))
  }
}
var token = uniqueString(resourceGroup().id, workload)
resource frontendIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'id-frontend-${token}'
  location: location
  tags: tags
}
resource backendIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'id-backend-${token}'
  location: location
  tags: tags
}
resource gatewayIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'id-gateway-${token}'
  location: location
  tags: tags
}
module network './modules/network.bicep' = {
  name: 'red-foundry'
  params: {
    location: location
    tags: tags
    name: 'vnet-${workload}-${token}'
    prefixes: prefixes
    dnsServers: dnsServers
    hubVnetId: hubVnetId
    routeTableIds: routeTableIds
    useRemoteGateways: useRemoteGateways
    clientPrefixes: cafClientPrefixes
    operatorPrefixes: operatorPrefixes
    privateServiceAddresses: privateServiceAddresses
    monitorPrefixes: monitorPrefixes
    extraEgress: extraEgress
  }
  dependsOn: [contracts]
}
module services './modules/services.bicep' = {
  name: 'servicios-foundry'
  params: {
    location: location
    tags: tags
    token: token
    foundrySubnetId: network.outputs.foundrySubnetId
    backendPrincipalId: backendIdentity.properties.principalId
    frontendPrincipalId: frontendIdentity.properties.principalId
    models: models
    workspaceId: logAnalyticsWorkspaceId
    siemAuthorizationRuleId: siemAuthorizationRuleId
    siemEventHubName: siemEventHubName
  }
}
@batchSize(1)
module endpoints './modules/private-endpoint.bicep' = [
  for i in range(0, 7): {
    name: 'endpoint-${i}'
    params: {
      location: location
      tags: tags
      name: 'pe-${services.outputs.targets[i].name}-${token}'
      subnetId: network.outputs.peSubnetId
      targetId: services.outputs.targets[i].id
      groupId: services.outputs.targets[i].group
    }
  }
]
module agentRuntime './modules/agent-runtime.bicep' = if (activateAgentRuntime) {
  name: 'runtime-foundry-standard'
  params: {
    accountName: services.outputs.accountName
    projectPrincipalId: services.outputs.projectPrincipalId
    storageName: services.outputs.agentStorageName
    cosmosName: services.outputs.cosmosName
    searchName: services.outputs.searchName
  }
  dependsOn: [endpoints]
}
module apps './modules/apps.bicep' = {
  name: 'container-apps'
  params: {
    location: location
    tags: tags
    token: token
    subnetId: network.outputs.containerSubnetId
    gatewaySubnetPrefix: prefixes.appGateway
    frontendIdentityId: frontendIdentity.id
    backendIdentityId: backendIdentity.id
    backendClientId: backendIdentity.properties.clientId
    registryServer: services.outputs.registryServer
    projectEndpoint: services.outputs.projectEndpoint
    blobEndpoint: services.outputs.blobEndpoint
    vaultUri: services.outputs.vaultUri
    deployApplications: deployApplications
    frontendImage: frontendImage
    backendImage: backendImage
    frontendPort: frontendPort
    backendPort: backendPort
    frontendEnv: frontendEnv
    backendEnv: backendEnv
    workspaceId: logAnalyticsWorkspaceId
    siemAuthorizationRuleId: siemAuthorizationRuleId
    siemEventHubName: siemEventHubName
    actionGroupId: actionGroupId
  }
  dependsOn: [endpoints, agentRuntime, secretAccess]
}
module secretAccess './modules/secret-access.bicep' = {
  name: 'permisos-secretos'
  params: {
    vaultName: services.outputs.vaultName
    backendPrincipalId: backendIdentity.properties.principalId
    gatewayPrincipalId: gatewayIdentity.properties.principalId
    backendSecretNames: deployApplications ? backendSecretNames : []
    certificateSecretName: certificateSecretName
    deployGateway: deployGateway
  }
}
module gateway './modules/gateway.bicep' = if (deployGateway) {
  name: 'application-gateway'
  params: {
    location: location
    tags: tags
    token: token
    subnetId: network.outputs.gatewaySubnetId
    privateIp: gatewayPrivateIp
    hostname: gatewayHostname
    backendFqdn: apps.outputs.frontendFqdn
    identityId: gatewayIdentity.id
    certificateSecretId: '${services.outputs.vaultUri}secrets/${certificateSecretName}'
    healthPath: frontendHealthPath
    workspaceId: logAnalyticsWorkspaceId
    siemAuthorizationRuleId: siemAuthorizationRuleId
    siemEventHubName: siemEventHubName
    actionGroupId: actionGroupId
  }
  dependsOn: [secretAccess]
}
output securityResourceIds object = services.outputs.securityResourceIds
output vnetId string = network.outputs.vnetId
output registryServer string = services.outputs.registryServer
output registryId string = services.outputs.registryId
output keyVaultUri string = services.outputs.vaultUri
output projectEndpoint string = services.outputs.projectEndpoint
output containerEnvironmentDomain string = apps.outputs.environmentDomain
output containerEnvironmentIp string = apps.outputs.environmentIp
output frontendFqdn string = apps.outputs.frontendFqdn
output applicationUrl string = deployGateway ? gateway!.outputs.url : ''

output subnetPrefixes object = prefixes
output gatewayAddress string = gatewayPrivateIp
output requiredWebDnsName string = gatewayHostname
output applicationInsightsId string = apps.outputs.applicationInsightsId
