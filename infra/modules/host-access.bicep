targetScope = 'resourceGroup'

param storageAccountName string
param principalId string
param hostUsesTables bool
param hostUsesBlobTriggers bool
param hostUsesDurableStorage bool

resource storage 'Microsoft.Storage/storageAccounts@2023-05-01' existing = {
  name: storageAccountName
}

// El host HTTP requiere Blob Data Owner; habilitar extras solo por bindings verificados.
var roleIds = concat([
  'b7e6dc6d-f1e8-4753-8033-0f276bb0955b'
], (hostUsesTables || hostUsesDurableStorage) ? ['0a9a7e1f-b9d0-4cc4-a60d-0319b160aaa3'] : [], (hostUsesBlobTriggers || hostUsesDurableStorage) ? ['974c5e8b-45b9-4653-ba55-5f855dd0fb88'] : [], hostUsesBlobTriggers ? ['17d1049b-9a84-46fb-8f53-869881c3d3ab'] : [])

resource assignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for roleId in roleIds: {
  name: guid(storage.id, principalId, roleId)
  scope: storage
  properties: {
    principalId: principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleId)
  }
}]
