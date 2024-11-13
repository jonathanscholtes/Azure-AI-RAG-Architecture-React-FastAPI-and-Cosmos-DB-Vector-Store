
param apiManagementName string
param vnetId string

var privateDnsZoneName = 'private.azure-api.net'



resource privateDnsZone 'Microsoft.Network/privateDnsZones@2018-09-01' = {
  name: privateDnsZoneName
  location: 'global'
}

resource apiManagement 'Microsoft.ApiManagement/service@2021-08-01' existing = {
  name: apiManagementName
}

/*resource cnameRecord 'Microsoft.Network/privateDnsZones/CNAME@2018-09-01' = {
  name: '${apiManagementName}.${privateDnsZoneName}'
  parent: privateDnsZone
  properties: {
    ttl: 3600
    cnameRecord: {
      cname: apiManagement.properties.gatewayUrl
    }
  }
}*/


resource aRecord 'Microsoft.Network/privateDnsZones/A@2018-09-01' = {
  name: apiManagementName
  parent: privateDnsZone
  properties: {
    ttl: 3600
    aRecords: [
      {
        ipv4Address: apiManagement.properties.privateIPAddresses[0]
      }
    ]
  }
}


resource vnetLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2018-09-01' = {
  name: '${privateDnsZoneName}-link'
  parent: privateDnsZone
  location: 'global'
  properties: {
    virtualNetwork: {
      id: vnetId
    }
    registrationEnabled: true
  }
}

output apimEndPoint string = 'https://${apiManagementName}.${privateDnsZoneName}'
