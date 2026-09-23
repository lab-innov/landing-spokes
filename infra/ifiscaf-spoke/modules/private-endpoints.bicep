targetScope = 'resourceGroup'

param location string
param tags object = {}
param subnetResourceId string
param endpoints array
param privateDnsZoneResourceIds object

@batchSize(1)
resource privateEndpoints 'Microsoft.Network/privateEndpoints@2024-05-01' = [for endpoint in endpoints: {
  name: endpoint.name
  location: location
  tags: tags
  properties: {
    subnet: {
      id: subnetResourceId
    }
    privateLinkServiceConnections: [
      {
        name: '${endpoint.name}-connection'
        properties: {
          privateLinkServiceId: endpoint.resourceId
          groupIds: endpoint.groupIds
        }
      }
    ]
  }
}]

resource dnsZoneGroups 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-05-01' = [for (endpoint, index) in endpoints: {
  name: 'default'
  parent: privateEndpoints[index]
  properties: {
    privateDnsZoneConfigs: [for (zoneKey, zoneIndex) in (endpoint.?dnsZoneKeys ?? endpoint.groupIds): {
      name: 'zone-${zoneIndex}'
      properties: {
        privateDnsZoneId: privateDnsZoneResourceIds[zoneKey]
      }
    }]
  }
}]

output resourceIds array = [for (endpoint, index) in endpoints: privateEndpoints[index].id]
