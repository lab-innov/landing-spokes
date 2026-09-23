targetScope = 'resourceGroup'

param location string
param tags object = {}
param vnetName string
param vnetAddressPrefixes array
param subnetPrefixes object
param routeTableResourceId string
param apiClientPrefixes array
param operatorPrefixes array
param monitorPrefixes array
param cosmosPrivateIps array
param functionPrivateIps array
param extraEgress array

var subnetDefinitions = [
  {
    name: 'snet-private-endpoints'
    prefix: subnetPrefixes.privateEndpoints
    delegation: ''
    privateEndpointNetworkPolicies: 'Enabled'
  }
  {
    name: 'snet-foundry-agents'
    prefix: subnetPrefixes.foundryAgents
    delegation: 'Microsoft.App/environments'
    privateEndpointNetworkPolicies: 'Disabled'
  }
  {
    name: 'snet-functions-integration'
    prefix: subnetPrefixes.functionsIntegration
    delegation: 'Microsoft.Web/serverFarms'
    privateEndpointNetworkPolicies: 'Disabled'
  }
  {
    name: 'snet-databricks-public'
    prefix: subnetPrefixes.databricksPublic
    delegation: 'Microsoft.Databricks/workspaces'
    privateEndpointNetworkPolicies: 'Disabled'
  }
  {
    name: 'snet-databricks-private'
    prefix: subnetPrefixes.databricksPrivate
    delegation: 'Microsoft.Databricks/workspaces'
    privateEndpointNetworkPolicies: 'Disabled'
  }
]

// Databricks administra sus reglas obligatorias mediante la delegación. No se sobrescriben.
resource databricksNsgs 'Microsoft.Network/networkSecurityGroups@2024-05-01' = [for name in ['snet-databricks-public', 'snet-databricks-private']: {
  name: 'nsg-${name}'
  location: location
  tags: tags
  properties: {}
}]
module workloadNsgs './nsg.bicep' = [for (purpose, i) in ['privateEndpoints', 'foundryAgents', 'functionsIntegration']: {
  name: 'nsg-${purpose}'
  params: {
    name: 'nsg-${subnetDefinitions[i].name}'
    location: location
    tags: tags
    purpose: purpose
    prefixes: subnetPrefixes
    apiClientPrefixes: apiClientPrefixes
    operatorPrefixes: operatorPrefixes
    monitorPrefixes: monitorPrefixes
    cosmosPrivateIps: cosmosPrivateIps
    functionPrivateIps: functionPrivateIps
    extraEgress: extraEgress
  }
}]

resource vnet 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: vnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: vnetAddressPrefixes
    }
    subnets: [for (subnet, index) in subnetDefinitions: {
      name: subnet.name
      properties: {
        addressPrefix: subnet.prefix
        routeTable: {
          id: routeTableResourceId
        }
        networkSecurityGroup: {
          id: index < 3 ? workloadNsgs[index].outputs.id : databricksNsgs[index - 3].id
        }
        privateEndpointNetworkPolicies: subnet.privateEndpointNetworkPolicies
        delegations: empty(subnet.delegation) ? [] : [
          {
            name: 'delegation'
            properties: {
              serviceName: subnet.delegation
            }
          }
        ]
      }
    }]
  }
}


output vnetId string = vnet.id
output vnetName string = vnet.name
output peSubnetId string = '${vnet.id}/subnets/snet-private-endpoints'
output foundryAgentSubnetId string = '${vnet.id}/subnets/snet-foundry-agents'
output functionsIntegrationSubnetId string = '${vnet.id}/subnets/snet-functions-integration'
output databricksPublicSubnetName string = 'snet-databricks-public'
output databricksPrivateSubnetName string = 'snet-databricks-private'
