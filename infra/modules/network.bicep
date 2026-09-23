param location string
param tags object
param name string
@description('CIDR aprobados por IPAM: vnet, foundry, containers, appGateway y privateEndpoints.')
param prefixes object
param routeTableIds object
param clientPrefixes array

param privateServiceAddresses object
param operatorPrefixes array
param monitorPrefixes array
param extraEgress object
module nsgs './nsg.bicep' = [for purpose in ['foundry', 'containers', 'appGateway', 'privateEndpoints']: {
  name: 'nsg-${purpose}'
  params: {
    location: location
    tags: tags
    name: purpose == 'appGateway' ? '${name}-appgw-nsg' : '${name}-${purpose}-nsg'
    purpose: purpose
    prefixes: prefixes
    clientPrefixes: clientPrefixes
    operatorPrefixes: operatorPrefixes
    privateServiceAddresses: privateServiceAddresses
    monitorPrefixes: monitorPrefixes
    extraEgress: extraEgress[?purpose] ?? []
  }
}]
resource vnet 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    addressSpace: { addressPrefixes: [prefixes.vnet] }
    subnets: [
      {
        name: 'snet-foundry'
        properties: {
          addressPrefix: prefixes.foundry
          networkSecurityGroup: { id: nsgs[0].outputs.id }
          routeTable: { id: routeTableIds.foundry }
          delegations: [{ name: 'foundry', properties: { serviceName: 'Microsoft.App/environments' } }]
        }
      }
      {
        name: 'snet-containers'
        properties: {
          addressPrefix: prefixes.containers
          networkSecurityGroup: { id: nsgs[1].outputs.id }
          routeTable: { id: routeTableIds.containers }
          delegations: [{ name: 'containers', properties: { serviceName: 'Microsoft.App/environments' } }]
        }
      }
      {
        name: 'snet-appgateway'
        properties: {
          addressPrefix: prefixes.appGateway
          routeTable: { id: routeTableIds.appGateway }
          networkSecurityGroup: { id: nsgs[2].outputs.id }
          delegations: [{ name: 'appgateway', properties: { serviceName: 'Microsoft.Network/applicationGateways' } }]
        }
      }
      {
        name: 'snet-private-endpoints'
        properties: {
          addressPrefix: prefixes.privateEndpoints
          networkSecurityGroup: { id: nsgs[3].outputs.id }
          privateEndpointNetworkPolicies: 'NetworkSecurityGroupEnabled'
        }
      }

    ]
  }
}
output vnetId string = vnet.id
output foundrySubnetId string = '${vnet.id}/subnets/snet-foundry'
output containerSubnetId string = '${vnet.id}/subnets/snet-containers'
output gatewaySubnetId string = '${vnet.id}/subnets/snet-appgateway'
output peSubnetId string = '${vnet.id}/subnets/snet-private-endpoints'
