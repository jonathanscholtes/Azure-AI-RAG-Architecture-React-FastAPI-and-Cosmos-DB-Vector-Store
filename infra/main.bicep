
targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name which is used to generate a short unique hash for each resource')
param environmentName string

@minLength(1)
@maxLength(64)
@description('Name which is used to generate a short unique hash for each resource')
param projectName string

@minLength(1)
@description('Primary location for all resources')
param location string


@secure()
param cosmosadminUsername string
@secure()
param cosmosadminPassword string



var resourceToken = uniqueString(environmentName,projectName,location,az.subscription().subscriptionId)
var apiAppName = 'api-${projectName}-${environmentName}-${resourceToken}'
var webAppName = 'web-${projectName}-${environmentName}-${resourceToken}'


resource resourceGroup 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: 'rg-${projectName}-${environmentName}-${location}-${resourceToken}'
  location: location
}
module managedIdentity 'core/security/managed-identity.bicep' = {
  name: 'managed-identity'
  scope: resourceGroup
  params: {
    name: 'id-${projectName}-${environmentName}'
  }
}

module vnetModule 'core/networking/vnet.bicep' = {
  name: 'vnetModule'
  scope: resourceGroup
  params: {
    vnetLocation: location
    vnetName: 'vnet-vector-search-${resourceToken}'
  }
}

module logModule 'core/monitor/loganalytics.bicep' = {
  name: 'logModule'
  scope: resourceGroup
  params: {
    workspaceName: 'log-vector-search-${resourceToken}'
    location: location
  }
}

module storageAcct 'core/storage/blob-storage-account.bicep' = {
  name: 'storageModule'
  scope: resourceGroup
  params: {
    location: location
    storageName: 'savecsearch${resourceToken}'
    vnetId: vnetModule.outputs.vnetId
    identityName: managedIdentity.outputs.managedIdentityName
    subnetName: 'dataSubnet'
    subnetName_pe:'servicesSubnet'
  }
}

module cosmosDbModule 'core/database/nosql/cosmosdb.bicep' = {
  name: 'cosmosDbModule'
  scope: resourceGroup
  params: {
    accountName: 'cosmos-vector-search-${resourceToken}'
    location: location
    adminUsername: cosmosadminUsername
    adminPassword: cosmosadminPassword
    vnetId: vnetModule.outputs.vnetId
    subnetName: 'dataSubnet'
    subnetName_pe:'servicesSubnet'
  }
}

module openAiServiceModule 'core/ai/openai_service.bicep' = {
  name: 'openAiServiceModule'
  scope: resourceGroup
  params: {
    openAiServiceName: 'aoai-vector-search-${resourceToken}'
    location: location
    vnetId: vnetModule.outputs.vnetId
    subnetName: 'aiSubnet'
    identityName: managedIdentity.outputs.managedIdentityName
    customSubdomain: 'openai-app-${resourceToken}'
  }
}

module openAiPEModule 'core/ai/openai_private_endpoint.bicep' = {
  name: 'openAiPEModule'
  scope: resourceGroup
  params: {
    openAiServiceName: openAiServiceModule.outputs.openAiServiceName
    location: location
    vnetId: vnetModule.outputs.vnetId
    subnetName: 'aiSubnet'
  }
  dependsOn: [openAiServiceModule,vnetModule]
}

module keyVaultModule 'core//security/keyvault.bicep' = {
  scope: resourceGroup
  name: 'keyVaultModule'
  params: {
    location: location
    CosmosDBConnectionString: cosmosDbModule.outputs.CosmosDBConnectionString
    identityName: managedIdentity.outputs.managedIdentityName
    keyVaultName: 'kvsearch${resourceToken}'
    subnetName: 'servicesSubnet'
    vnetId: vnetModule.outputs.vnetId
  }
  dependsOn: [managedIdentity,vnetModule,cosmosDbModule]
}

module appInsightsModule 'core/monitor/appInsights.bicep' = {
  scope: resourceGroup
  name: 'appInsightsModule'
  params: {
    location: location
    appInsightsName: 'appi-vector-search-${resourceToken}'
  }
}


module appServiceModule 'core/host/appService.bicep' = {
  name: 'appServiceModule'
  scope: resourceGroup
  params: {
    appServicePlanName: 'asp-vector-search-${resourceToken}'
    appServiceNameAPI: apiAppName
    appServiceNameWeb: webAppName
    location: location
    vnetId: vnetModule.outputs.vnetId
    subnetName: 'webSubnet'
    identityName: managedIdentity.outputs.managedIdentityName
    OpenAIEndPoint: openAiServiceModule.outputs.OpenAIEndPoint
    StorageBlobURL: storageAcct.outputs.storageBlobURL
    logAnalyticsWorkspaceName: logModule.outputs.workspaceName
    appInsightsName: appInsightsModule.outputs.appInsightsName
    kv_CosmosDBConnectionString: keyVaultModule.outputs.kv_CosmosDBConnectionString
    keyVaultUri:keyVaultModule.outputs.keyVaultUri
  }
  dependsOn: [cosmosDbModule,keyVaultModule,appInsightsModule ,openAiServiceModule,logModule ]
}

module functionappModule 'core/host/functionapp.bicep' = {
  name: 'functionAppModule'
  scope: resourceGroup
  params: {
    functionAppPlanName: appServiceModule.outputs.appServicePlanName
    functionAppName: 'func-loader-${resourceToken}'
    location: location
    vnetId: vnetModule.outputs.vnetId
    subnetName: 'dataSubnet'
    StorageBlobURL:storageAcct.outputs.storageBlobURL
    StorageAccountName: storageAcct.outputs.StorageAccountName
    logAnalyticsWorkspaceName: logModule.outputs.workspaceName
    appInsightsName: appInsightsModule.outputs.appInsightsName
    OpenAIEndPoint: openAiServiceModule.outputs.OpenAIEndPoint
    identityName: managedIdentity.outputs.managedIdentityName
    kv_CosmosDBConnectionString: keyVaultModule.outputs.kv_CosmosDBConnectionString
    keyVaultUri:keyVaultModule.outputs.keyVaultUri
  }
  dependsOn:[storageAcct,cosmosDbModule , keyVaultModule,appInsightsModule, openAiServiceModule,logModule]
}


output apiAppName string = apiAppName
output webAppName string = webAppName
output resourceGroupName string = resourceGroup.name
output functionAppName string = functionappModule.outputs.functionAppName
output appServiceURL string = appServiceModule.outputs.appServiceURL
