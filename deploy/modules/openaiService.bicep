param openAiServiceName string
param location string
param vnetId string
param subnetName string
param identityName string
param customSubdomain string


var privateEndpointName = '${openAiServiceName}-pe'
var privateDnsZoneName = 'privatelink.openai.azure.com'
var pvtEndpointDnsGroupName = '${privateEndpointName}/default'


resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing= {
  name: identityName
}

resource openAiService 'Microsoft.CognitiveServices/accounts@2023-05-01' = {
  name: openAiServiceName
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentity.id}': {}
    }
  }
  kind: 'OpenAI'
  sku: {
    name: 'S0'
  }
  properties: {
    customSubDomainName: customSubdomain
    publicNetworkAccess: 'Disabled'
    networkAcls: {
      defaultAction: 'Deny'
      virtualNetworkRules: [
        {
          id: '${vnetId}/subnets/${subnetName}'
        }
      ]
    }
  }
}


resource adaDeployment 'Microsoft.CognitiveServices/accounts/deployments@2023-05-01' = {
  parent: openAiService
  name: 'text-embedding'
  sku: {
    capacity: 120
    name: 'Standard'
  }
  properties: {
    model: {
      format: 'OpenAI'
      name: 'text-embedding-ada-002'
      version: '2'
    }
    versionUpgradeOption: 'OnceCurrentVersionExpired'
    raiPolicyName: 'Microsoft.DefaultV2'
    
  }
  
}


resource gptDeployment 'Microsoft.CognitiveServices/accounts/deployments@2023-05-01' = {
  parent: openAiService
  name: 'gpt-chat'
  sku: {
    capacity: 10
    name: 'Standard'
  }
  properties: {
    model: {
      format: 'OpenAI'
      name: 'gpt-4o'
      version: '2024-05-13'
    }
    versionUpgradeOption: 'OnceCurrentVersionExpired'
    raiPolicyName: 'Microsoft.DefaultV2'
    
  }
  dependsOn:[adaDeployment]
}



resource privateEndpoint 'Microsoft.Network/privateEndpoints@2021-05-01' = {
  name: privateEndpointName
  location: location
  properties: {
    subnet: {
      id: '${vnetId}/subnets/${subnetName}'
    }
    privateLinkServiceConnections: [
      {
        name: 'openAiServiceConnection'
        properties: {
          privateLinkServiceId: openAiService.id
          groupIds: [
            'account'
          ]
          
        }
      }
    ]
  }
  dependsOn: [
    openAiService
  ]
}


resource privateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: privateDnsZoneName
  location: 'global'
  properties: {}
  dependsOn: [
    privateEndpoint
  ]
}

resource privateDnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: privateDnsZone
  name: '${privateDnsZoneName}-link'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnetId
    }
  }
}

resource pvtEndpointDnsGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2021-05-01' = {
  name: pvtEndpointDnsGroupName
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'config1'
        properties: {
          privateDnsZoneId: privateDnsZone.id
        }
      }
    ]
  }
  dependsOn: [
    privateEndpoint
  ]
}


resource roleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(managedIdentity.id, openAiService.id, 'cognitive-services-openai-contributor')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'a001fd3d-188f-4b5d-821b-7da978bf7442') // Cognitive Services OpenAI Contributor role ID
    principalId: managedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
  scope:openAiService
  dependsOn:[openAiService]
}

output OpenAIEndPoint string = 'https://${customSubdomain}.openai.azure.com'
//openAiService.properties.endpoint
output openAiServiceKey string = listKeys(openAiService.id, '2023-05-01').key1
output openAiServiceName string = openAiServiceName
