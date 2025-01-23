param location string 
param apimName string
param openAiServiceName string
param identityName string
param vnetId string
param subnetName string
param appInsightsName string
param openaiEndpoint string

param productName string = 'APIM-AI_APIS'
param productDescription string = 'A product with AI APIs'

@description('The email address of the owner of the service')
@minLength(1)
param publisherEmail string = 'myPublisherEmail@example.com'

@description('The name of the owner of the service')
@minLength(1)
param publisherName string = 'myPublisherName'

var subscriptionId = az.subscription().subscriptionId

var apiSuffix = '${openAiServiceName}/openai'

resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing= {
  name: identityName
}

resource apimService 'Microsoft.ApiManagement/service@2021-08-01' = {
  name: apimName
  location: location
  sku: {
    name: 'Developer'
    capacity: 1
  }
  identity: {
    type: 'SystemAssigned, UserAssigned'
    userAssignedIdentities: {
      '${managedIdentity.id}': {}
    }
  }
  properties: {
    publisherEmail: publisherEmail
    publisherName: publisherName
    virtualNetworkConfiguration: {
      subnetResourceId: '${vnetId}/subnets/${subnetName}'
    }
    virtualNetworkType: 'Internal'
  }
}


resource appInsights 'Microsoft.Insights/components@2020-02-02' existing= {
  name: appInsightsName

}

resource apimLogger 'Microsoft.ApiManagement/service/loggers@2022-08-01' = {
  name: 'aiLoggerWithSystemAssignedIdentity'
  parent: apimService
  properties: {
    loggerType: 'applicationInsights'
    description: 'Application Insights logger with connection string'
    credentials: {
      connectionString: appInsights.properties.ConnectionString
      identityClientId: 'systemAssigned'
    }
  }
}



resource backend1 'Microsoft.ApiManagement/service/backends@2023-09-01-preview' = {
  parent: apimService
  name: 'backend1'
  properties: {
    url: '${openaiEndpoint}/openai'
    protocol: 'http'
    circuitBreaker: {
      rules: [
        {
          failureCondition: {
            count: 3
            errorReasons: [
              'Server errors'
            ]
            interval: 'P1D'
            statusCodeRanges: [
              {
                min: 500
                max: 599
              }
            ]
          }
          name: 'myBreakerRule'
          tripDuration: 'PT1H'
        }
      ]
    }
  }
}

resource loadBalancing 'Microsoft.ApiManagement/service/backends@2023-09-01-preview' = {
  parent: apimService
  name: 'LoadBalancer'
  properties: {
    description: 'Load balancer for multiple backends'
    type: 'Pool'
    pool: {
      services: [
        {
          id: '/subscriptions/${subscriptionId}/resourceGroups/${resourceGroup().name}/providers/Microsoft.ApiManagement/service/${apimService.name}/backends/${backend1.id}'
        }
      ]
    }
  }
}

resource api1 'Microsoft.ApiManagement/service/apis@2020-06-01-preview' = {
  parent: apimService
  name: openAiServiceName
  properties: {
    displayName: openAiServiceName
    apiType: 'http'
    path: apiSuffix
    format: 'openapi+json-link'
    value: 'https://raw.githubusercontent.com/Azure/azure-rest-api-specs/main/specification/cognitiveservices/data-plane/AzureOpenAI/inference/preview/2024-03-01-preview/inference.json'
    subscriptionKeyParameterNames: {
      header: 'api-key'
    }
  }
  resource apimDiagnostics 'diagnostics@2023-05-01-preview' = {
    name: 'applicationinsights' // Use a supported diagnostic identifier
    properties: {
      loggerId: '/subscriptions/${subscriptionId}/resourceGroups/${resourceGroup().name}/providers/Microsoft.ApiManagement/service/${apimService.name}/loggers/${apimLogger.name}'
      metrics: true
    }
  }
}




var headerPolicyXml = format(loadTextContent('./policy.xml'), loadBalancing.name, 5000)


resource openaiApiPolicy 'Microsoft.ApiManagement/service/apis/policies@2021-08-01' = {
  parent: api1
  name: 'policy'
  properties: {
    format: 'rawxml'
    value: headerPolicyXml
  }
}

// Creating a product for the API. Products are used to group APIs and apply policies to them
resource product 'Microsoft.ApiManagement/service/products@2020-06-01-preview' = {
  parent: apimService
  name: productName
  properties: {
    displayName: productName
    description: productDescription
    state: 'published'
    subscriptionRequired: true
  }
}

// Create PRODUCT-API association the API with the product
resource productApi1 'Microsoft.ApiManagement/service/products/apis@2020-06-01-preview' = {
  parent: product
  name: api1.name
}

// Creating a user for the API Management service
resource user 'Microsoft.ApiManagement/service/users@2020-06-01-preview' = {
  parent: apimService
  name: 'userName'
  properties: {
    firstName: 'User'
    lastName: 'Name'
    email: 'user@example.com'
    state: 'active'
  }
}

// Creating a subscription for the API Management service
// NOTE: the subscription is associated with the user and the product, AND the subscription ID is what will be used in the request to authenticate the calling client
resource subscription 'Microsoft.ApiManagement/service/subscriptions@2020-06-01-preview' = {
  parent: apimService
  name: 'subscriptionAIProduct'
  properties: {
    displayName: 'Subscribing to AI services'
    state: 'active'
    ownerId: user.id
    scope: product.id
  }
}



output apiManagementProxyHostName string = apimService.properties.hostnameConfigurations[0].hostName
output apiManagementDeveloperPortalHostName string = replace(apimService.properties.developerPortalUrl, 'https://', '')
output apimServiceName string = apimName
