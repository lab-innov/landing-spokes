param location string
param tags object
param name string
param purpose string
param prefixes object
param clientPrefixes array
param privateServiceAddresses object
param operatorPrefixes array
param monitorPrefixes array
param extraEgress array
var profiles = loadJsonContent('../network-rules.json')
var addresses = prefixes
var lists = { clients: clientPrefixes, operators: operatorPrefixes, monitor: monitorPrefixes, vaultEndpoint: privateServiceAddresses.vault, cosmosEndpoint: privateServiceAddresses.cosmos }
var selectedRules = filter(profiles[purpose], rule => !(rule.name == 'operacion-caf' && empty(operatorPrefixes)) && !(rule.name == 'monitor-privado' && empty(monitorPrefixes)) && !(rule.properties.destinationAddressPrefix == 'vaultEndpoint' && empty(privateServiceAddresses.vault)) && !(rule.properties.destinationAddressPrefix == 'cosmosEndpoint' && empty(privateServiceAddresses.cosmos)))
var rules = [for rule in selectedRules: {
  name: rule.name
  properties: union({
    priority: rule.properties.priority
    direction: rule.properties.direction
    access: rule.properties.access
    protocol: rule.properties.protocol
    sourcePortRange: '*'
    destinationPortRanges: rule.properties.destinationPortRanges
  }, contains(lists, rule.properties.sourceAddressPrefix) ? {
    sourceAddressPrefixes: lists[rule.properties.sourceAddressPrefix]
  } : {
    sourceAddressPrefix: addresses[?rule.properties.sourceAddressPrefix] ?? rule.properties.sourceAddressPrefix
  }, contains(lists, rule.properties.destinationAddressPrefix) ? {
    destinationAddressPrefixes: lists[rule.properties.destinationAddressPrefix]
  } : {
    destinationAddressPrefix: addresses[?rule.properties.destinationAddressPrefix] ?? rule.properties.destinationAddressPrefix
  })
}]
var exceptionRules = [for (exception, i) in extraEgress: {
      name: 'excepcion-${i}'
      properties: {
        description: exception.justification
        priority: 1000 + i
        direction: 'Outbound'
        access: 'Allow'
        protocol: 'Tcp'
        sourceAddressPrefix: prefixes[purpose]
        sourcePortRange: '*'
        destinationAddressPrefix: exception.destination
        destinationPortRanges: exception.ports
      }
    }]
resource nsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    securityRules: concat(rules, exceptionRules)
  }
}
output id string = nsg.id
