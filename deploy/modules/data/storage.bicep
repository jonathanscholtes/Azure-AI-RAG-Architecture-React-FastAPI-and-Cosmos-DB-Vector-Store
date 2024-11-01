param storageName string
param location string
param vnetId string
param identityName string
param subnetName string
param subnetName_pe string


var privateDnsZoneName = 'privatelink.blob.core.windows.net'
var privateEndpointName = '${storageName}-pe'
var pvtEndpointDnsGroupName = '${privateEndpointName}/default'


resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing= {
  name: identityName
}

resource storageAcct 'Microsoft.Storage/storageAccounts@2023-04-01' = {
  name: storageName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    allowSharedKeyAccess: true
    networkAcls: {
      defaultAction: 'Deny'
      bypass: 'AzureServices'
      virtualNetworkRules: [
        {
          id: '${vnetId}/subnets/${subnetName}'
        }
      ]
    }
  }
}


resource blobServices 'Microsoft.Storage/storageAccounts/blobServices@2023-01-01' = {
  parent: storageAcct
  name: 'default'
}


resource imageContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-04-01' = {
  parent: blobServices
  name: 'images'
  properties: {
    publicAccess: 'None'
  }
}


resource loadContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-04-01' = {
  parent: blobServices
  name: 'load'
}

resource archiveContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-04-01' = {
  parent: blobServices
  name: 'archive'
  properties: {
    publicAccess: 'None'
  }
}


resource roleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(managedIdentity.id, storageAcct.id, 'cognitive-services-openai-contributor')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'ba92f5b4-2d11-453d-a403-e96b0029c9fe') // Storage Blob Data Contributor
    principalId: managedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
  scope:storageAcct
  dependsOn:[storageAcct]
}

resource roleAssignmentQueue 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(managedIdentity.id, storageAcct.id, 'cognitive-services-openai-contributor')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '974c5e8b-45b9-4653-ba55-5f855dd0fb88') // Storage Queue Data Contributor
    principalId: managedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
  scope:storageAcct
  dependsOn:[storageAcct]
}

resource roleAssignmentTable 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(managedIdentity.id, storageAcct.id, 'cognitive-services-openai-contributor')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '0a9a7e1f-b9d0-4cc4-a60d-0319b160aaa3') // Storage Table Data Contributor
    principalId: managedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
  scope:storageAcct
  dependsOn:[storageAcct]
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
          privateLinkServiceId: storageAcct.id
          groupIds: [
            'blob'
          ]
        }
        
      }
      
    ]
  }
  dependsOn: [
    storageAcct
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



output StorageAccountName string = storageAcct.name
output storageBlobURL string = 'https://${storageAcct.name}.blob.core.windows.net/'
