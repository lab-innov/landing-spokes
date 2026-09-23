param location string
param tags object
param name string
param subnetId string
param targetId string
param groupId string
param privateDnsZoneResourceId string
resource endpoint 'Microsoft.Network/privateEndpoints@2024-05-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    subnet: { id: subnetId }
    privateLinkServiceConnections: [
      {
        name: name
        properties: { privateLinkServiceId: targetId, groupIds: [groupId] }
      }
    ]
  }
}
resource dnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-05-01' = {
  name: 'default'
  parent: endpoint
  properties: {
    privateDnsZoneConfigs: [{ name: 'zone', properties: { privateDnsZoneId: privateDnsZoneResourceId } }]
  }
}
