targetScope = 'resourceGroup'

param location string
param tags object = {}
param applicationInsightsName string
param logAnalyticsWorkspaceResourceId string

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: applicationInsightsName
  location: location
  tags: tags
  kind: 'web'
  properties: {
    Application_Type: 'web'
    IngestionMode: 'LogAnalytics'
    WorkspaceResourceId: logAnalyticsWorkspaceResourceId
    publicNetworkAccessForIngestion: 'Disabled'
    publicNetworkAccessForQuery: 'Disabled'
  }
}

output resourceId string = applicationInsights.id
output connectionString string = applicationInsights.properties.ConnectionString
