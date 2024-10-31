
targetScope = 'subscription'

param subscription string
param resourceGroupName string = 'rg-vector-search-demo'
param resourceGroupLocation string
@secure()
param cosmosadminUsername string
@secure()
param cosmosadminPassword string


var uniqueSuffix = uniqueString(resourceGroupName,resourceGroupLocation,subscription)
var apiAppName = 'api-vector-search-${uniqueSuffix}'
var webAppName = 'web-vector-search-${uniqueSuffix}'


resource newRG 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: '${resourceGroupName}-${resourceGroupLocation}-${uniqueSuffix}'
  location: resourceGroupLocation
}

module managedIdentityModule 'modules/infra/managedIdentity.bicep' = {
  name: 'managedIdentityModule'
  scope: newRG
  params: {
    identityName: 'VectorSearchAppMI'
    location: resourceGroupLocation
  }
}

module vnetModule 'modules/networking/vnet.bicep' = {
  name: 'vnetModule'
  scope: newRG
  params: {
    vnetLocation: resourceGroupLocation
    vnetName: 'vnet-vector-search-${uniqueSuffix}'
  }
}

module logModule 'modules/infra/loganalytics.bicep' = {
  name: 'logModule'
  scope: newRG
  params: {
    workspaceName: 'log-vector-search-${uniqueSuffix}'
    location: resourceGroupLocation
  }
}

module storageAcct 'modules/data/storage.bicep' = {
  name: 'storageModule'
  scope: newRG
  params: {
    location: resourceGroupLocation
    storageName: 'savecsearch${uniqueSuffix}'
    vnetId: vnetModule.outputs.vnetId
    identityName: managedIdentityModule.outputs.identityName
    subnetName: 'dataSubnet'
    subnetName_pe:'servicesSubnet'
  }
  dependsOn: [vnetModule]
}

module cosmosDbModule 'modules/data/cosmosdb.bicep' = {
  name: 'cosmosDbModule'
  scope: newRG
  params: {
    accountName: 'cosmos-vector-search-${uniqueSuffix}'
    location: resourceGroupLocation
    adminUsername: cosmosadminUsername
    adminPassword: cosmosadminPassword
    vnetId: vnetModule.outputs.vnetId
    subnetName: 'dataSubnet'
    subnetName_pe:'servicesSubnet'
  }
  dependsOn: [vnetModule]
}

module openAiServiceModule 'modules/openai_service.bicep' = {
  name: 'openAiServiceModule'
  scope: newRG
  params: {
    openAiServiceName: 'aoai-vector-search-${uniqueSuffix}'
    location: resourceGroupLocation
    vnetId: vnetModule.outputs.vnetId
    subnetName: 'aiSubnet'
    identityName: managedIdentityModule.outputs.identityName
    customSubdomain: 'openai-app-${uniqueSuffix}'
  }
  dependsOn: [managedIdentityModule,vnetModule]
}

module openAiPEModule 'modules/openai_private_endpoint.bicep' = {
  name: 'openAiPEModule'
  scope: newRG
  params: {
    openAiServiceName: openAiServiceModule.outputs.openAiServiceName
    location: resourceGroupLocation
    vnetId: vnetModule.outputs.vnetId
    subnetName: 'aiSubnet'
  }
  dependsOn: [openAiServiceModule,vnetModule]
}

module keyVaultModule 'modules/infra/keyvault.bicep' = {
  scope: newRG
  name: 'keyVaultModule'
  params: {
    location: resourceGroupLocation
    CosmosDBConnectionString: cosmosDbModule.outputs.CosmosDBConnectionString
    identityName: managedIdentityModule.outputs.identityName
    keyVaultName: 'kvsearch${uniqueSuffix}'
    subnetName: 'servicesSubnet'
    vnetId: vnetModule.outputs.vnetId
  }
  dependsOn: [managedIdentityModule,vnetModule,cosmosDbModule]
}

/*module apiManagementServiceModule 'modules/apim.bicep' = {
  scope: newRG
  name: 'apiManagementServiceModule'
  params: {
    location: resourceGroupLocation
    apimName: 'apim-vector-search-${uniqueSuffix}'
    appInsightsName: 'appi-vector-search-${uniqueSuffix}'
    identityId: managedIdentityModule.outputs.identityId
    openAiServiceName: openAiServiceModule.outputs.openAiServiceName
    subnetName: 'apimSubnet'
    vnetId: vnetModule.outputs.vnetId
    openaiEndpoint: openAiServiceModule.outputs.OpenAIEndPoint
  }
  dependsOn:[managedIdentityModule,keyVaultModule,openAiServiceModule]
}

module apimDnsModule 'modules/apim_dns.bicep' = {
  scope: newRG
  name: 'apimDnsModule'
  params: {
    apiManagementName:apiManagementServiceModule.outputs.apimServiceName
    vnetId:vnetModule.outputs.vnetId
  }
  dependsOn:[apiManagementServiceModule]
}

module apiManagementServicePEModule 'modules/apim_private_endpoint.bicep' ={
  name: 'apiManagementServicePEModule'
  scope: newRG
  params: {
    apimServiceName:apiManagementServiceModule.outputs.apimServiceName
    location:resourceGroupLocation
    subnetName:'servicesSubnet'
    vnetId:vnetModule.outputs.vnetId
  }
  dependsOn:[apiManagementServiceModule]
}*/


module appServiceModule 'modules/appService.bicep' = {
  name: 'appServiceModule'
  scope: newRG
  params: {
    appServicePlanName: 'asp-vector-search-${uniqueSuffix}'
    appServiceNameAPI: apiAppName
    appServiceNameWeb: webAppName
    location: resourceGroupLocation
    vnetId: vnetModule.outputs.vnetId
    subnetName: 'webSubnet'
    identityName: managedIdentityModule.outputs.identityName
    OpenAIEndPoint: openAiServiceModule.outputs.OpenAIEndPoint
    StorageBlobURL: storageAcct.outputs.storageBlobURL
    logAnalyticsWorkspaceName: logModule.outputs.workspaceName
    appInsightsName: 'appi-vector-search-${uniqueSuffix}'
    kv_CosmosDBConnectionString: keyVaultModule.outputs.kv_CosmosDBConnectionString
    keyVaultUri:keyVaultModule.outputs.keyVaultUri
  }
  dependsOn: [cosmosDbModule,keyVaultModule ,openAiServiceModule,logModule ]
}

module functionappModule 'modules/functionapp.bicep' = {
  name: 'functionAppModule'
  scope: newRG
  params: {
    functionAppPlanName: appServiceModule.outputs.appServicePlanName
    functionAppName: 'func-loader-${uniqueSuffix}'
    location: resourceGroupLocation
    vnetId: vnetModule.outputs.vnetId
    subnetName: 'dataSubnet'
    StorageConnectionString:storageAcct.outputs.storageConnectionString
    logAnalyticsWorkspaceName: logModule.outputs.workspaceName
    appInsightsName: 'appi-vector-search-${uniqueSuffix}'
    OpenAIEndPoint: openAiServiceModule.outputs.OpenAIEndPoint
    identityName: managedIdentityModule.outputs.identityName
    kv_CosmosDBConnectionString: keyVaultModule.outputs.kv_CosmosDBConnectionString
    keyVaultUri:keyVaultModule.outputs.keyVaultUri
  }
  dependsOn:[storageAcct,cosmosDbModule , keyVaultModule, openAiServiceModule,logModule]
}


output apiAppName string = apiAppName
output webAppName string = webAppName
output resourceGroupName string = newRG.name
output functionAppName string = functionappModule.outputs.functionAppName
output appServiceURL string = appServiceModule.outputs.appServiceURL
