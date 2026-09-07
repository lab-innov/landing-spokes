targetScope = 'resourceGroup'

param location string
param tags object = {}
param subnetResourceId string
param endpoints array

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

output resourceIds array = [for (endpoint, index) in endpoints: privateEndpoints[index].id]
