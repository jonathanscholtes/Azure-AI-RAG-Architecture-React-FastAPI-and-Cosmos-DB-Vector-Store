param location string 
param apimName string
param openAiServiceName string
param identityId string
param vnetId string
param subnetName string
param appInsightsName string
param openaiEndpoint string

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
      '${identityId}': {}
    }
  }
  properties: {
    publisherEmail: 'your-email@example.com'
    publisherName: 'Your Name'
    virtualNetworkConfiguration: {
      subnetResourceId: '${vnetId}/subnets/${subnetName}'
    }
    virtualNetworkType: 'Internal'
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
          id: '/subscriptions/${subscription().subscriptionId}/resourceGroups/${resourceGroup().name}/providers/Microsoft.ApiManagement/service/${apimService.name}/backends/${backend1.name}'
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
    path: 'openai'
    format: 'openapi+json-link'
    value: 'https://raw.githubusercontent.com/Azure/azure-rest-api-specs/main/specification/cognitiveservices/data-plane/AzureOpenAI/inference/preview/2024-03-01-preview/inference.json'
    subscriptionKeyParameterNames: {
      header: 'api-key'
    }
  }
}

resource openaiApiPolicy 'Microsoft.ApiManagement/service/apis/policies@2021-08-01' = {
  parent: api1
  name: 'policy'
  properties: {
    format: 'rawxml'
    value: '''
    <policies>
      <inbound>
        <base />
        <set-header name="Authorization" exists-action="override">
          <value>@("Bearer " + context.Request.Headers.GetValueOrDefault("Authorization", ""))</value>
        </set-header>
      </inbound>
      <backend>
        <base />
      </backend>
      <outbound>
        <base />
      </outbound>
      <on-error>
        <base />
      </on-error>
    </policies>
    '''
  }
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
  }
}

resource aiLoggerWithSystemAssignedIdentity 'Microsoft.ApiManagement/service/loggers@2022-08-01' = {
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

output apiManagementProxyHostName string = apimService.properties.hostnameConfigurations[0].hostName
output apiManagementDeveloperPortalHostName string = replace(apimService.properties.developerPortalUrl, 'https://', '')
