targetScope = 'resourceGroup'

param acrName string
param imageName string
param imageTag string = 'latest'
param appName string
param location string = resourceGroup().location

// https://samcogan.com/creating-an-azure-web-app-or-function-running-a-container-with-bicep/

resource containerRegistry 'Microsoft.ContainerRegistry/registries@2023-01-01-preview' = {
  name: acrName
  location: location
  sku: {
    name: 'Basic'
  }
  properties: {
    adminUserEnabled: false
    publicNetworkAccess: 'Disabled'
  }
}

resource appServicePlan 'Microsoft.Web/serverfarms@2022-09-01' = {
  name: '${appName}${uniqueString(resourceGroup().id)}'
  location: location
  properties: {
    reserved: true   // needed for linux
  }
  sku: {
    name: 'F1'
  }
  kind: 'linux'
}

// Use system assigned managed identity to provide secure access to ACR
resource webApp 'Microsoft.Web/sites@2022-09-01' = {
  name: appName
  location: location
  properties: {
    serverFarmId: appServicePlan.id
    siteConfig: {
      // Use managed identity to access ACR, since we have not provided
      // a user managed identity the system assigned identity will be used
      acrUseManagedIdentityCreds: true
      // URL of container image in ACR
      linuxFxVersion: 'DOCKER|${acrName}.azurecr.io:${imageName}:${imageTag}'
      minTlsVersion: '1.2'
      ftpsState: 'FtpsOnly'
      publicNetworkAccess: 'Enabled'
    }
    httpsOnly: false
    clientAffinityEnabled: false
    virtualNetworkSubnetId: null
  }
  identity: {
      type: 'SystemAssigned'
  }
}
