param location string
param tags object
param purpose string
param name string
param prefixes object
param apiClientPrefixes array
param operatorPrefixes array
param monitorPrefixes array
param functionPrivateIps array
param extraEgress array
var profiles = loadJsonContent('../network-rules.json')
var lists = { clients: apiClientPrefixes, operators: operatorPrefixes, monitor: monitorPrefixes, function: functionPrivateIps }
var selected = filter(profiles[purpose], r => (!contains(lists, r.properties.sourceAddressPrefix) || !empty(lists[?r.properties.sourceAddressPrefix] ?? [])) && (!contains(lists, r.properties.destinationAddressPrefix) || !empty(lists[?r.properties.destinationAddressPrefix] ?? [])))
var rules = [for r in selected: {
  name: r.name
  properties: union({
    priority: r.properties.priority
    direction: r.properties.direction
    access: r.properties.access
    protocol: r.properties.protocol
    sourcePortRange: '*'
    destinationPortRanges: r.properties.destinationPortRanges
  }, contains(lists, r.properties.sourceAddressPrefix) ? {
    sourceAddressPrefixes: lists[r.properties.sourceAddressPrefix]
  } : {
    sourceAddressPrefix: prefixes[?r.properties.sourceAddressPrefix] ?? r.properties.sourceAddressPrefix
  }, contains(lists, r.properties.destinationAddressPrefix) ? {
    destinationAddressPrefixes: lists[r.properties.destinationAddressPrefix]
  } : {
    destinationAddressPrefix: prefixes[?r.properties.destinationAddressPrefix] ?? r.properties.destinationAddressPrefix
  })
}]
var exceptions = filter(extraEgress, r => r.purpose == purpose)
var exceptionRules = [for (r, i) in exceptions: {
  name: 'excepcion-${i}'
  properties: {
    description: r.justification
    priority: 2000 + i
    direction: 'Outbound'
    access: 'Allow'
    protocol: 'Tcp'
    sourcePortRange: '*'
    destinationPortRanges: r.ports
    sourceAddressPrefix: prefixes[purpose]
    destinationAddressPrefix: r.destination
  }
}]
resource nsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: name
  location: location
  tags: tags
  properties: { securityRules: concat(rules, exceptionRules) }
}
output id string = nsg.id
