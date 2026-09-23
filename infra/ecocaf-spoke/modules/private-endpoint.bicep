targetScope = 'resourceGroup'

param name string
param location string
param subnetResourceId string
param privateLinkServiceId string
param groupIds array
@minLength(1)
param privateDnsZoneResourceIds string[]
param tags object = {}

resource privateEndpoint 'Microsoft.Network/privateEndpoints@2025-05-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    subnet: {
      id: subnetResourceId
    }
    privateLinkServiceConnections: [
      {
        name: '${name}-connection'
        properties: {
          privateLinkServiceId: privateLinkServiceId
          groupIds: groupIds
        }
      }
    ]
  }
}

resource dnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2025-05-01' = {
  name: 'default'
  parent: privateEndpoint
  properties: {
    privateDnsZoneConfigs: [for (zoneId, index) in privateDnsZoneResourceIds: {
      name: 'zone-${index}'
      properties: {
        privateDnsZoneId: zoneId
      }
    }]
  }
}

output resourceId string = privateEndpoint.id
