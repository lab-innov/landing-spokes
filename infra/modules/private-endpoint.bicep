targetScope = 'resourceGroup'

param name string
param location string
param subnetResourceId string
param privateLinkServiceId string
param groupIds array
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

output resourceId string = privateEndpoint.id
