targetScope = 'resourceGroup'

@description('Existing IFISCAF Data Factory name output by the infrastructure deployment.')
param dataFactoryName string

@description('Existing secure Databricks workspace resource ID.')
param databricksWorkspaceResourceId string

@description('Databricks workspace URL including the https:// scheme.')
param databricksWorkspaceUrl string

@description('Interactive cluster ID deployed by the Databricks Asset Bundle stage.')
@minLength(1)
param databricksClusterId string

@description('IFISCAF workload storage account resource ID used by BlobTrigger.')
param workloadStorageResourceId string

@description('Existing shared synthetic-data storage account resource ID used by triggerDataSintetica.')
param sharedSyntheticStorageAccountResourceId string

param sharedSyntheticContainerName string = 'datasintetica'

@description('Main IFISCAF processing notebook path deployed by the Databricks Asset Bundle.')
param mainProcessingNotebookPath string = '/Repos/iData/Caf-ifis-model/(Clone) OpenAI_IFISCAF'

@description('Failure-update notebook path deployed by the Databricks Asset Bundle.')
param updateOnFailNotebookPath string = '/Repos/iData/Caf-ifis-model/UpdateOnFail'

@description('Synthetic-data notebook path deployed by the Databricks Asset Bundle.')
param syntheticDataNotebookPath string = '/IData/DataSintetica/Generacion_Data_Sintetica'

resource factory 'Microsoft.DataFactory/factories@2018-06-01' existing = {
  name: dataFactoryName
}

resource databricksLinkedService 'Microsoft.DataFactory/factories/linkedservices@2018-06-01' = {
  name: 'AzureDatabricks1'
  parent: factory
  properties: {
    type: 'AzureDatabricks'
    connectVia: {
      referenceName: 'AutoResolveIntegrationRuntime'
      type: 'IntegrationRuntimeReference'
    }
    typeProperties: {
      domain: databricksWorkspaceUrl
      authentication: 'MSI'
      workspaceResourceId: databricksWorkspaceResourceId
      existingClusterId: databricksClusterId
    }
  }
}

resource ifiscafPipeline 'Microsoft.DataFactory/factories/pipelines@2018-06-01' = {
  name: 'ProcesoIFISCAF'
  parent: factory
  properties: {
    parameters: {
      anio: {
        type: 'String'
        defaultValue: '2024'
      }
    }
    activities: [
      {
        name: 'RunProcess'
        type: 'DatabricksNotebook'
        linkedServiceName: {
          referenceName: databricksLinkedService.name
          type: 'LinkedServiceReference'
        }
        policy: {
          timeout: '0.12:00:00'
          retry: 0
          retryIntervalInSeconds: 30
          secureOutput: false
          secureInput: false
        }
        typeProperties: {
          notebookPath: mainProcessingNotebookPath
          baseParameters: {
            anio: {
              type: 'Expression'
              value: '@pipeline().parameters.anio'
            }
          }
        }
      }
      {
        name: 'UpdateCosmosOnFail'
        type: 'DatabricksNotebook'
        dependsOn: [
          {
            activity: 'RunProcess'
            dependencyConditions: [
              'Failed'
            ]
          }
        ]
        linkedServiceName: {
          referenceName: databricksLinkedService.name
          type: 'LinkedServiceReference'
        }
        policy: {
          timeout: '0.12:00:00'
          retry: 0
          retryIntervalInSeconds: 30
          secureOutput: false
          secureInput: false
        }
        typeProperties: {
          notebookPath: updateOnFailNotebookPath
          baseParameters: {
            anio: {
              type: 'Expression'
              value: '@pipeline().parameters.anio'
            }
          }
        }
      }
    ]
  }
}

resource syntheticDataPipeline 'Microsoft.DataFactory/factories/pipelines@2018-06-01' = {
  name: 'ProcesoDataSintetica'
  parent: factory
  properties: {
    parameters: {
      pathjson: {
        type: 'String'
      }
    }
    activities: [
      {
        name: 'Generacion_Data_Sintetica'
        type: 'DatabricksNotebook'
        linkedServiceName: {
          referenceName: databricksLinkedService.name
          type: 'LinkedServiceReference'
        }
        policy: {
          timeout: '0.12:00:00'
          retry: 0
          retryIntervalInSeconds: 30
          secureOutput: false
          secureInput: false
        }
        typeProperties: {
          notebookPath: syntheticDataNotebookPath
          baseParameters: {
            pathjson: {
              type: 'Expression'
              value: '@pipeline().parameters.pathjson'
            }
          }
        }
      }
    ]
  }
}

resource blobTrigger 'Microsoft.DataFactory/factories/triggers@2018-06-01' = {
  name: 'BlobTrigger'
  parent: factory
  properties: {
    annotations: [
      'Definition only. Start explicitly after migration validation.'
    ]
    type: 'BlobEventsTrigger'
    typeProperties: {
      blobPathBeginsWith: '/source/blobs/'
      blobPathEndsWith: 'ParametrosAnio.json'
      ignoreEmptyBlobs: false
      scope: workloadStorageResourceId
      events: [
        'Microsoft.Storage.BlobCreated'
      ]
    }
    pipelines: [
      {
        pipelineReference: {
          referenceName: ifiscafPipeline.name
          type: 'PipelineReference'
        }
        parameters: {
          anio: '@triggerBody().folderPath'
        }
      }
    ]
  }
}

resource syntheticDataTrigger 'Microsoft.DataFactory/factories/triggers@2018-06-01' = {
  name: 'triggerDataSintetica'
  parent: factory
  properties: {
    annotations: [
      'Definition only. Start explicitly after migration validation.'
    ]
    type: 'BlobEventsTrigger'
    typeProperties: {
      blobPathBeginsWith: '/${sharedSyntheticContainerName}/blobs/ejecuciones/'
      blobPathEndsWith: '.json'
      ignoreEmptyBlobs: true
      scope: sharedSyntheticStorageAccountResourceId
      events: [
        'Microsoft.Storage.BlobCreated'
      ]
    }
    pipelines: [
      {
        pipelineReference: {
          referenceName: syntheticDataPipeline.name
          type: 'PipelineReference'
        }
        parameters: {
          pathjson: '@triggerBody().folderPath'
        }
      }
    ]
  }
}

output linkedServiceName string = databricksLinkedService.name
output pipelineNames array = [
  ifiscafPipeline.name
  syntheticDataPipeline.name
]
output triggerNames array = [
  blobTrigger.name
  syntheticDataTrigger.name
]
output triggersStarted bool = false
