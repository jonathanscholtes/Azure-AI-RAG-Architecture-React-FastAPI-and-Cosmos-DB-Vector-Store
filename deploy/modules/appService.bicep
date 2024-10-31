param appServicePlanName string
param appServiceNameAPI string
param appServiceNameWeb string
param location string
param vnetId string
param subnetName string
param identityName string
param keyVaultUri string
param kv_CosmosDBConnectionString string
param OpenAIEndPoint string
param StorageBlobURL string
param logAnalyticsWorkspaceName string
param appInsightsName string

resource appServicePlan 'Microsoft.Web/serverfarms@2022-03-01' = {
  name: appServicePlanName
  location: location
  sku: {
    name: 'B2'
    tier: 'Basic'
    size: 'B2'
   family: 'B'
    capacity: 1
  }
  properties: {
    reserved: true
    isXenon: false
    hyperV: false
  }
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' existing = {
  name: appInsightsName
}

resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing= {
  name: identityName
}

resource appServiceAPI 'Microsoft.Web/sites@2022-03-01' = {
  name: appServiceNameAPI
  location: location
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
      
      linuxFxVersion: 'PYTHON|3.11'
      appCommandLine: 'gunicorn -w 2 -k uvicorn.workers.UvicornWorker -b 0.0.0.0:8000 main:app'      
      appSettings: [
        {
          name: 'SCM_DO_BUILD_DURING_DEPLOYMENT'
          value: '1'
        }        
        {
          name: 'AZURE_OPENAI_ENDPOINT'
          value: OpenAIEndPoint
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
          name: 'AZURE_STORAGE_CONTAINER'
          value: 'images'
        }
        {
          name: 'AZURE_STORAGE_URL'
          value: StorageBlobURL
        } 
        {
          name: 'AZURE_CLIENT_ID'
          value: managedIdentity.properties.clientId
        } 
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: appInsights.properties.InstrumentationKey
        }
        {
          name: 'ApplicationInsightsAgent_EXTENSION_VERSION'
          value: '~3'
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appInsights.properties.ConnectionString
        }    
        {
          name:'KeyVaultUri'
          value:keyVaultUri
        }
        {
          name:'KV_CosmosDBConnectionString'
          value:kv_CosmosDBConnectionString
        }
        {
          // Temp to fix: ImportError: cannot import name 'AccessTokenInfo' from 'azure.core.credentials'
          name:'WEBSITE_PIN_SYSTEM_IMAGES'
          value:'application_insights_python|applicationinsights/auto-instrumentation/python:1.0.0b18'
        }
        
      
      ]
      alwaysOn: true
    }
    publicNetworkAccess: 'Enabled'
    
  }
 
}


resource appServiceNode 'Microsoft.Web/sites@2022-03-01' = {
  name: appServiceNameWeb
  location: location
  properties: {
    serverFarmId: appServicePlan.id
    virtualNetworkSubnetId: '${vnetId}/subnets/${subnetName}'
    siteConfig: {
      
      linuxFxVersion: 'NODE|18-lts'
      appCommandLine: 'pm2 serve /home/site/wwwroot --spa --no-daemon'
      appSettings: [
        {
          name: 'SCM_DO_BUILD_DURING_DEPLOYMENT'
          value: '0'
        }
        {
          name: 'REACT_APP_API_HOST'
          value: 'https://${appServiceNameAPI}.azurewebsites.net'
        }
      ]
    }
    publicNetworkAccess: 'Enabled'
    ipSecurityRestrictions: [
      {
        name: 'AllowAll'
        ipAddress: '0.0.0.0/0'
        action: 'Allow'
        priority: 100
        description: 'Allow all traffic'
      }
    ]
  }
}


resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2021-06-01'  existing =  {
  name: logAnalyticsWorkspaceName
}

resource diagnosticSettingsAPI 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${appServiceNameAPI}-diagnostic'
  scope: appServiceAPI
  properties: {
    workspaceId: logAnalyticsWorkspace.id
    logs: [
      {
        category: 'AppServiceHTTPLogs'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
      {
        category: 'AppServiceConsoleLogs'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
      {
        category: 'AppServiceAppLogs'
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


output appServicePlanName string = appServicePlanName
output appServiceURL string = 'https://${appServiceNameAPI}.azurewebsites.net'
