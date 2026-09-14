targetScope = 'resourceGroup'
@description('Factory creada por la fundación; nunca la original de producción/PoC.')
param dataFactoryName string
param databricksWorkspaceResourceId string
param databricksWorkspaceUrl string
param databricksClusterId string
param workloadStorageResourceId string
param modelProcessingNotebookPath string
@description('Evidencia de aprobación del workspace, identidad ADF, notebook y permisos de clúster.')
param databricksApproved bool = false
@description('Confirmar el recorrido Storage/Event Grid y su excepción corporativa antes de crear el trigger.')
param storageEventsApproved bool = false
param approvalId string = ''
module contract './modules/contracts.bicep' = {
  name: 'vinculador-contratos-adf'
  params: {
    validSecurity: any(databricksApproved && storageEventsApproved && !empty(approvalId) && toLower(resourceGroup().name) != 'rg-poc-vinculador-cr' && toLower(dataFactoryName) != 'adf-poc-vinculador-cr')
    validSettings: any(startsWith(databricksWorkspaceUrl, 'https://adb-') && endsWith(databricksWorkspaceUrl, '.azuredatabricks.net') && !empty(databricksClusterId) && startsWith(modelProcessingNotebookPath, '/') && startsWith(databricksWorkspaceResourceId, '/subscriptions/') && contains(databricksWorkspaceResourceId, '/providers/Microsoft.Databricks/workspaces/') && startsWith(workloadStorageResourceId, '${resourceGroup().id}/providers/Microsoft.Storage/storageAccounts/'))
    validActivation: true
  }
}
resource factory 'Microsoft.DataFactory/factories@2018-06-01' existing = { name: dataFactoryName }
resource managedVnet 'Microsoft.DataFactory/factories/managedVirtualNetworks@2018-06-01' existing = { name: 'default', parent: factory }
resource databricksEndpoint 'Microsoft.DataFactory/factories/managedVirtualNetworks/managedPrivateEndpoints@2018-06-01' = {
  name: 'databricks-ui-api'
  parent: managedVnet
  properties: { privateLinkResourceId: databricksWorkspaceResourceId, groupId: 'databricks_ui_api' }
  dependsOn: [contract]
}
resource linkedService 'Microsoft.DataFactory/factories/linkedservices@2018-06-01' = {
  name: 'VINCULADOR_PROCESSING'
  parent: factory
  properties: {
    type: 'AzureDatabricks'
    connectVia: { referenceName: 'AutoResolveIntegrationRuntime', type: 'IntegrationRuntimeReference' }
    typeProperties: { domain: databricksWorkspaceUrl, authentication: 'MSI', workspaceResourceId: databricksWorkspaceResourceId, existingClusterId: databricksClusterId }
  }
  dependsOn: [databricksEndpoint]
}
resource pipeline 'Microsoft.DataFactory/factories/pipelines@2018-06-01' = {
  name: 'VINCULADOR_DMAF'
  parent: factory
  properties: {
    parameters: { fileName: { type: 'String' } }
    activities: [{
      name: 'VINCULADOR_DMAF'
      type: 'DatabricksNotebook'
      linkedServiceName: { referenceName: linkedService.name, type: 'LinkedServiceReference' }
      policy: { timeout: '0.12:00:00', retry: 0, retryIntervalInSeconds: 30, secureInput: true, secureOutput: true }
      typeProperties: { notebookPath: modelProcessingNotebookPath, baseParameters: { fileName: { type: 'Expression', value: '@pipeline().parameters.fileName' } } }
    }]
  }
}
// Nuevo trigger: Azure lo crea detenido. En actualizaciones, ejecutar check_adf_state.py antes de desplegar.
// runtimeState es estado operativo; omitirlo no detiene un trigger existente.
resource trigger 'Microsoft.DataFactory/factories/triggers@2018-06-01' = {
  name: 'trigger_blob_storage'
  parent: factory
  properties: {
    type: 'BlobEventsTrigger'
    typeProperties: { blobPathBeginsWith: '/poc-vinculador-trigger-data-factory/blobs/', blobPathEndsWith: '.json', ignoreEmptyBlobs: true, events: ['Microsoft.Storage.BlobCreated'], scope: workloadStorageResourceId }
    pipelines: [{ pipelineReference: { referenceName: pipeline.name, type: 'PipelineReference' }, parameters: { fileName: '@triggerBody().fileName' } }]
  }
}
output pipelineName string = pipeline.name
output triggerName string = trigger.name
