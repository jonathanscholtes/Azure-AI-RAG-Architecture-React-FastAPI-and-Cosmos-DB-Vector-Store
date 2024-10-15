param location string 
param apimName string
param openAiServiceName string
param identityId string
param vnetId string
param subnetName string
param appInsightsName string

resource apim 'Microsoft.ApiManagement/service@2021-08-01' = {
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



resource openaiApi 'Microsoft.ApiManagement/service/apis@2021-08-01' = {
  parent: apim
  name: openAiServiceName
  properties: {
    displayName: 'Azure OpenAI API'
    serviceUrl: 'https://api.openai.azure.com/v1'
    path: 'openai'
    protocols: [
      'https'
    ]
  }
}

resource openaiApiOperation 'Microsoft.ApiManagement/service/apis/operations@2021-08-01' = {
  parent: openaiApi
  name: 'getOpenAIResponse'
  properties: {
    displayName: 'Get OpenAI Response'
    method: 'POST'
    urlTemplate: '/openai'
    request: {
      description: 'Request to OpenAI API'
      queryParameters: []
      headers: []
      representations: []
    }
    responses: []
  }
}

resource openaiApiPolicy 'Microsoft.ApiManagement/service/apis/policies@2021-08-01' = {
  parent: openaiApi
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
  parent: apim
  properties: {
    loggerType: 'applicationInsights'
    description: 'Application Insights logger with connection string'
    credentials: {
      connectionString: appInsights.properties.ConnectionString
      identityClientId: 'systemAssigned'
    }
  }
}


output apiManagementProxyHostName string = apim.properties.hostnameConfigurations[0].hostName
output apiManagementDeveloperPortalHostName string = replace(apim.properties.developerPortalUrl, 'https://', '')
