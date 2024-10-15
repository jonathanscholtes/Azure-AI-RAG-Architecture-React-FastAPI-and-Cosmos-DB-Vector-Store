param functionAppName string
param functionAppPlanName string
param location string
param StorageConnectionString string
param vnetId string
param subnetName string
param identityName string
param logAnalyticsWorkspaceName string
param appInsightsName string
param OpenAIEndPoint string
param keyVaultUri string
param kv_CosmosDBConnectionString string


resource appServicePlan 'Microsoft.Web/serverfarms@2022-03-01' existing = {
  name: functionAppPlanName
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' existing = {
  name: appInsightsName
}

resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing= {
  name: identityName
}

resource functionApp 'Microsoft.Web/sites@2022-03-01' = {
  name: functionAppName
  location: location
  kind: 'functionapp,linux'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentity.id}': {}
    }
  }
  properties: {
    serverFarmId: appServicePlan.id
    virtualNetworkSubnetId: '${vnetId}/subnets/${subnetName}'
    siteConfig: {
      appSettings: [
        {
          name: 'AzureWebJobsStorage'
          value: StorageConnectionString
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'WEBSITE_RUN_FROM_PACKAGE'
          value: 'true'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'python'
        }
        {
          name: 'AzureWebJobsFeatureFlags'
          value: 'EnableWorkerIndexing'
        }
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: appInsights.properties.InstrumentationKey
        }
        {
          name: 'AZURE_OPENAI_EMBEDDING'
          value: 'text-embedding'
        }
        {
          name: 'AZURE_OPENAI_API_VERSION'
          value: '2023-05-15'
        }
        {
          name: 'AZURE_OPENAI_ENDPOINT'
          value: OpenAIEndPoint
        }
        {
          name: 'AZURE_CLIENT_ID'
          value: managedIdentity.properties.clientId
        } 
        {
          name: 'AZURE_STORAGE_CONNECTION_STRING'
          value: StorageConnectionString
        }
        {
          name:'KeyVaultUri'
          value:keyVaultUri
        }
        {
          name:'KV_CosmosDBConnectionString'
          value:kv_CosmosDBConnectionString
        }
      ]
       linuxFxVersion: 'PYTHON|3.11'
       alwaysOn: true
       
    }
  }
}

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2021-06-01'  existing =  {
  name: logAnalyticsWorkspaceName
}

resource diagnosticSettingsAPI 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${functionAppName}-diagnostic'
  scope: functionApp
  properties: {
    workspaceId: logAnalyticsWorkspace.id
    logs: [
      {
        category: 'FunctionAppLogs'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
      
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
    ]
  }
}

output functionAppId string = functionApp.id
output functionAppName string = functionAppName