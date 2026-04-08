targetScope = 'resourceGroup'

param location string = resourceGroup().location
param sku string = 'Basic'
param acrName string = 'acr${uniqueString(subscription().id)}'

resource acr 'Microsoft.ContainerRegistry/registries@2026-01-01-preview' = {
  name: acrName
  location: location
  sku: {
    name: sku
  }
  properties: {
    adminUserEnabled: true
  }
}

output acrName string = acrName
output acrLoginServer string = acr.properties.loginServer
output adminUserEnabled bool = acr.properties.adminUserEnabled
