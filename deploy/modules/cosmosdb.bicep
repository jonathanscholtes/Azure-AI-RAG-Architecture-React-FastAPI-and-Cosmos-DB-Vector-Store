param accountName string
param location string
param adminUsername string
@secure()
param adminPassword string
param vnetId string
param subnetName string
param subnetName_pe string


var privateDnsZoneName = 'privatelink.mongocluster.cosmos.azure.com'
var privateEndpointName = '${accountName}-pe'
var pvtEndpointDnsGroupName = '${privateEndpointName}/default'



resource cosmosDb 'Microsoft.DocumentDB/mongoClusters@2022-10-15-preview' = {
  name: accountName
  location: location
  properties: {
    enableFreeTier: true
    administratorLogin: adminUsername
    administratorLoginPassword: adminPassword
    nodeGroupSpecs: [
      {
        kind: 'Shard'
        shardCount: 1
        sku: 'M30'
        nodeCount: 1
        diskSizeGB: 32
        enableHa: false
      }
    ]
    virtualNetworkRules: [
      {
        id: '${vnetId}/subnets/${subnetName}'
      }
    ]
  }
}



resource privateEndpoint 'Microsoft.Network/privateEndpoints@2021-05-01' = {
  name: privateEndpointName
  location: location
  properties: {
    subnet: {
      id: '${vnetId}/subnets/${subnetName_pe}'
    }

    privateLinkServiceConnections: [
      {
        name: 'cosmosDbConnection'
        properties: {
          privateLinkServiceId: cosmosDb.id
          groupIds: [
            'MongoCluster'
          ]
        }
        
      }
      
    ]
  }
  dependsOn: [
    cosmosDb
  ]
}

/*privateLinkServiceConnectionState: {
  status: 'Approved'
  description: 'Approved'
  actionsRequired: 'None'
}*/


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

resource pvtEndpointDnsGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-04-01' = {
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




output CosmosDBConnectionString string = 'mongodb+srv://${adminUsername}:${adminPassword}@${accountName}.mongocluster.cosmos.azure.com/?tls=true&authMechanism=SCRAM-SHA-256&retrywrites=false&maxIdleTimeMS=120000'
