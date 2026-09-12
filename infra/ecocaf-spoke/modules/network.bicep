targetScope = 'resourceGroup'

param location string
param tags object = {}
param vnetName string
param vnetAddressPrefixes array
param subnetPrefixes object
param routeTableResourceId string
param useRemoteGateways bool
param apiClientPrefixes array
param operatorPrefixes array
param monitorPrefixes array
param functionPrivateIps array
param extraEgress array
@minLength(1)
param dnsServers array
param hubVnetResourceId string

var subnetDefinitions = [
  {
    name: 'snet-private-endpoints'
    prefix: subnetPrefixes.privateEndpoints
    delegation: ''
    privateEndpointNetworkPolicies: 'Enabled'
  }
  {
    name: 'snet-functions-integration'
    prefix: subnetPrefixes.functionsIntegration
    delegation: 'Microsoft.Web/serverFarms'
    privateEndpointNetworkPolicies: 'Disabled'
  }
]

module subnetNsgs './nsg.bicep' = [for (purpose, i) in ['privateEndpoints', 'functionsIntegration']: {
  name: 'nsg-${purpose}'
  params: {
    name: 'nsg-${subnetDefinitions[i].name}'
    location: location
    tags: tags
    purpose: purpose
    prefixes: subnetPrefixes
    dnsServers: dnsServers
    apiClientPrefixes: apiClientPrefixes
    operatorPrefixes: operatorPrefixes
    monitorPrefixes: monitorPrefixes
    functionPrivateIps: functionPrivateIps
    extraEgress: extraEgress
  }
}]

resource vnet 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: vnetName
  location: location
  tags: tags
  properties: {
    dhcpOptions: {
      dnsServers: dnsServers
    }
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
          id: subnetNsgs[index].outputs.id
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

resource spokeToHubPeering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2024-05-01' = {
  name: 'peer-${vnetName}-to-hub'
  parent: vnet
  properties: {
    allowForwardedTraffic: true
    allowGatewayTransit: false
    allowVirtualNetworkAccess: true
    remoteVirtualNetwork: {
      id: hubVnetResourceId
    }
    useRemoteGateways: useRemoteGateways
  }
}

output vnetId string = vnet.id
output vnetName string = vnet.name
output peSubnetId string = '${vnet.id}/subnets/snet-private-endpoints'
output functionsIntegrationSubnetId string = '${vnet.id}/subnets/snet-functions-integration'
output spokeToHubPeeringId string = spokeToHubPeering.id
