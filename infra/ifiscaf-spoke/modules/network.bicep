targetScope = 'resourceGroup'

param location string
param tags object = {}
param vnetName string
param vnetAddressPrefixes array
param subnetPrefixes object
param routeTableResourceId string

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

resource subnetNsgs 'Microsoft.Network/networkSecurityGroups@2024-05-01' = [for subnet in subnetDefinitions: {
  name: 'nsg-${subnet.name}'
  location: location
  tags: tags
  properties: {
    securityRules: subnet.name == 'snet-private-endpoints' ? [
      {
        name: 'AllowHttpsFromVirtualNetwork'
        properties: {
          priority: 100
          access: 'Allow'
          direction: 'Inbound'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'AllowCosmosFromVirtualNetwork'
        properties: {
          priority: 110
          access: 'Allow'
          direction: 'Inbound'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: '*'
        }
      }
    ] : []
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
          id: subnetNsgs[index].id
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
output functionsIntegrationSubnetId string = '${vnet.id}/subnets/snet-functions-integration'
output databricksPublicSubnetName string = 'snet-databricks-public'
output databricksPrivateSubnetName string = 'snet-databricks-private'
