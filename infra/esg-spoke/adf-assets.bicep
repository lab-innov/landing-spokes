targetScope = 'resourceGroup'

@description('Nombre de Data Factory existente, obtenido de la fundación ESG.')
param dataFactoryName string

@description('ID del workspace Databricks privado existente.')
param databricksWorkspaceResourceId string

@description('URL de Databricks con esquema HTTPS.')
param databricksWorkspaceUrl string

@description('ID de clúster interactivo entregado por Databricks Asset Bundle.')
@minLength(1)
param databricksClusterId string

@description('ID de Storage de negocio para el trigger de blobs.')
param workloadStorageResourceId string

@description('Contenedor vigilado por el trigger ESG.')
param triggerContainerName string = 'poc-esg-trigger-data-factory'

@description('Ruta del notebook de procesamiento desplegado por el Asset Bundle.')
param modelProcessingNotebookPath string = '/Repos/iData/Caf-esg-model/model_processing'

@description('Ruta del notebook mensual desplegado por el Asset Bundle.')
param monthlyReportNotebookPath string = '/Repos/iData/Caf-esg-model/scioteca_webscraping'

resource factory 'Microsoft.DataFactory/factories@2018-06-01' existing = {
  name: dataFactoryName
}

resource databricksLinkedService 'Microsoft.DataFactory/factories/linkedservices@2018-06-01' = {
  name: 'AzureDatabricks1'
  parent: factory
  properties: {
    type: 'AzureDatabricks'
    typeProperties: {
      domain: databricksWorkspaceUrl
      authentication: 'MSI'
      workspaceResourceId: databricksWorkspaceResourceId
      existingClusterId: databricksClusterId
    }
  }
}

resource executionPipeline 'Microsoft.DataFactory/factories/pipelines@2018-06-01' = {
  name: 'ESG_TRACKER_EXECUTION'
  parent: factory
  properties: {
    parameters: {
      fileName: {
        type: 'String'
      }
    }
    activities: [
      {
        name: 'ESG_TRACKER'
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
          notebookPath: modelProcessingNotebookPath
          baseParameters: {
            fileName: {
              type: 'Expression'
              value: '@pipeline().parameters.fileName'
            }
          }
        }
      }
    ]
  }
}

resource monthlyPipeline 'Microsoft.DataFactory/factories/pipelines@2018-06-01' = {
  name: 'ESG_TRACKER_MONTHLY_REPORT_EXECUTE'
  parent: factory
  properties: {
    activities: [
      {
        name: 'ESG_TRACKER_MONTHLY_REPORT'
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
          notebookPath: monthlyReportNotebookPath
        }
      }
    ]
  }
}

resource blobEventsTrigger 'Microsoft.DataFactory/factories/triggers@2018-06-01' = {
  name: 'poc_esg_trigger_from_blob'
  parent: factory
  properties: {
    annotations: [
      'Solo definición. Iniciar explícitamente tras validar migración y seguridad.'
    ]
    type: 'BlobEventsTrigger'
    typeProperties: {
      blobPathBeginsWith: '/${triggerContainerName}/blobs/'
      blobPathEndsWith: '.json'
      ignoreEmptyBlobs: true
      scope: workloadStorageResourceId
      events: [
        'Microsoft.Storage.BlobCreated'
      ]
    }
    pipelines: [
      {
        pipelineReference: {
          referenceName: executionPipeline.name
          type: 'PipelineReference'
        }
        parameters: {
          fileName: '@triggerBody().fileName'
        }
      }
    ]
  }
}

resource monthlyTrigger 'Microsoft.DataFactory/factories/triggers@2018-06-01' = {
  name: 'esg-trigger-monthly-report'
  parent: factory
  properties: {
    annotations: [
      'Solo definición. Iniciar explícitamente tras validar migración y seguridad.'
    ]
    type: 'ScheduleTrigger'
    typeProperties: {
      recurrence: {
        frequency: 'Month'
        interval: 1
        startTime: '2025-03-01T08:00:00'
        timeZone: 'SA Pacific Standard Time'
        schedule: {
          monthDays: [
            1
          ]
          hours: [
            8
          ]
          minutes: [
            0
          ]
        }
      }
    }
    pipelines: [
      {
        pipelineReference: {
          referenceName: monthlyPipeline.name
          type: 'PipelineReference'
        }
        parameters: {}
      }
    ]
  }
}

output linkedServiceName string = databricksLinkedService.name
output pipelineNames array = [
  executionPipeline.name
  monthlyPipeline.name
]
output triggerNames array = [
  blobEventsTrigger.name
  monthlyTrigger.name
]
output triggersStarted bool = false
