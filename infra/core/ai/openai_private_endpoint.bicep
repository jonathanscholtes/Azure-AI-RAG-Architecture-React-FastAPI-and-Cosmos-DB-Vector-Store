param openAiServiceName string
param location string
param vnetId string
param subnetName string

var privateEndpointName = '${openAiServiceName}-pe'
var privateDnsZoneName = 'privatelink.openai.azure.com'
var pvtEndpointDnsGroupName = '${privateEndpointName}/default'


resource openAiService 'Microsoft.CognitiveServices/accounts@2023-05-01' existing = {
  name: openAiServiceName

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
