param apimServiceName string
param location string
param vnetId string
param subnetName string

var privateEndpointName = '${apimServiceName}-pe'
var privateDnsZoneName = 'privatelink.azure-api.net'
var pvtEndpointDnsGroupName = '${privateEndpointName}/default'


resource apimService 'Microsoft.ApiManagement/service@2021-08-01' existing ={
  name: apimServiceName

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
        name: 'apimServiceConnection'
        properties: {
          privateLinkServiceId: apimService.id
          groupIds: [
            'Gateway'
          ]
          
        }
      }
    ]
  }
  dependsOn: [
    apimService
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
