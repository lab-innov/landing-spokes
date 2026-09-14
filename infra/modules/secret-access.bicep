param vaultName string
param backendPrincipalId string
param gatewayPrincipalId string
param backendSecretNames array
param certificateSecretName string
param deployGateway bool
resource vault 'Microsoft.KeyVault/vaults@2023-07-01' existing = { name: vaultName }
resource secrets 'Microsoft.KeyVault/vaults/secrets@2023-07-01' existing = [for name in backendSecretNames: {
  parent: vault
  name: name
}]
resource certificate 'Microsoft.KeyVault/vaults/secrets@2023-07-01' existing = {
  parent: vault
  name: certificateSecretName
}
resource backendRoles 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for (name, i) in backendSecretNames: {
  name: guid(vault.id, name, backendPrincipalId, 'secreto-lectura')
  scope: secrets[i]
  properties: {
    principalId: backendPrincipalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4633458b-17de-408a-b874-0445c86b69e6')
  }
}]
resource gatewayRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (deployGateway) {
  name: guid(vault.id, certificateSecretName, gatewayPrincipalId, 'certificado-lectura')
  scope: certificate
  properties: {
    principalId: gatewayPrincipalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4633458b-17de-408a-b874-0445c86b69e6')
  }
}
