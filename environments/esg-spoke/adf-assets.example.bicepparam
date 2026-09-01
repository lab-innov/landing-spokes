using '../../infra/esg-spoke/adf-assets.bicep'

// Populate these values from the infrastructure deployment and Asset Bundle output.
param dataFactoryName = 'REPLACE-WITH-DATA-FACTORY-NAME'
param databricksWorkspaceResourceId = '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-esg-secure-spoke-dev/providers/Microsoft.Databricks/workspaces/REPLACE-WITH-WORKSPACE-NAME'
param databricksWorkspaceUrl = 'https://REPLACE-WITH-WORKSPACE-URL'
param databricksClusterId = 'REPLACE-WITH-ASSET-BUNDLE-CLUSTER-ID'
param workloadStorageResourceId = '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-esg-secure-spoke-dev/providers/Microsoft.Storage/storageAccounts/REPLACE-WITH-STORAGE-NAME'

param triggerContainerName = 'poc-esg-trigger-data-factory'
param modelProcessingNotebookPath = '/Repos/iData/Caf-esg-model/model_processing'
param monthlyReportNotebookPath = '/Repos/iData/Caf-esg-model/scioteca_webscraping'
