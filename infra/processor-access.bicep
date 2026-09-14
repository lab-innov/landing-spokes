targetScope = 'resourceGroup'
@description('Object ID de la identidad real del notebook/cómputo, distinto de la identidad ADF que agenda el trabajo.')
param processorPrincipalId string
param storageName string
param cosmosName string
param openAiName string
param documentName string
param batchEnabled bool = false
param identityApproved bool = false
param approvalId string = ''
module contract './modules/contracts.bicep' = {
  name: 'vinculador-contratos-procesador'
  params: { validSecurity: any(identityApproved && !empty(approvalId) && toLower(resourceGroup().name) != 'rg-poc-vinculador-cr'), validSettings: any(length(processorPrincipalId) == 36), validActivation: true }
}
module access './modules/data-access.bicep' = {
  name: 'vinculador-permisos-procesador'
  params: { principalId: processorPrincipalId, storageName: storageName, cosmosName: cosmosName, openAiName: openAiName, documentName: documentName, batchEnabled: batchEnabled, usesBlobTrigger: false }
  dependsOn: [contract]
}
