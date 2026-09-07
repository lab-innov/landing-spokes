using '../../infra/ifiscaf-spoke/adf-assets.bicep'

// Populate these values from the infrastructure deployment and Asset Bundle output.
param dataFactoryName = 'REPLACE-WITH-DATA-FACTORY-NAME'
param databricksWorkspaceResourceId = '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-ifiscaf-secure-spoke-dev/providers/Microsoft.Databricks/workspaces/REPLACE-WITH-WORKSPACE-NAME'
param databricksWorkspaceUrl = 'https://REPLACE-WITH-WORKSPACE-URL'
param databricksClusterId = 'REPLACE-WITH-ASSET-BUNDLE-CLUSTER-ID'
param workloadStorageResourceId = '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-ifiscaf-secure-spoke-dev/providers/Microsoft.Storage/storageAccounts/REPLACE-WITH-STORAGE-NAME'
param sharedSyntheticStorageAccountResourceId = '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/RG-POC-iDataFactory-CR/providers/Microsoft.Storage/storageAccounts/sapocidatafactorycr'

param mainProcessingNotebookPath = '/Repos/iData/Caf-ifis-model/(Clone) OpenAI_IFISCAF'
param updateOnFailNotebookPath = '/Repos/iData/Caf-ifis-model/UpdateOnFail'
param syntheticDataNotebookPath = '/IData/DataSintetica/Generacion_Data_Sintetica'
