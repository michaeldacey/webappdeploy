targetScope = 'resourceGroup'

param acrName string
param imageName string
param imageTag string = 'latest'
param appName string
param location string = resourceGroup().location
@secure()
param applicationServicePrincipalId string

// https://samcogan.com/creating-an-azure-web-app-or-function-running-a-container-with-bicep/

resource containerRegistry 'Microsoft.ContainerRegistry/registries@2023-01-01-preview' = {
  name: '${acrName}${uniqueString(resourceGroup().id)}'
  location: location
  sku: {
    name: 'Basic'
  }
  properties: {
    adminUserEnabled: true  // We need a password for allow docker login
    // publicNetworkAccess: 'Disabled' only fo Premium sku
  }
}

resource appServicePlan 'Microsoft.Web/serverfarms@2022-09-01' = {
  name: '${appName}ServicePlan${uniqueString(resourceGroup().id)}'
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
  name: '${appName}${uniqueString(resourceGroup().id)}'
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

// This is the build in AcrPull role.
// az role definition list --name "AcrPull" --query [].id -o tsv
// az role definition list --name "AcrPush" --query [].id -o tsv
// See https://learn.microsoft.com/en-gb/azure/role-based-access-control/built-in-roles
resource acrPush 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: '8311e382-0749-4cb8-b61a-304f252e45ec'
}

resource acrPull 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: '7f951dda-4ed3-4680-a7ca-43fe172d538d'
}

// Allow the application service principal to push an image to the ACR
// so that GitHub Actions can push the image to the ACR
resource acrPushRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(containerRegistry.name, 'AcrPush')
  properties: {
    roleDefinitionId: acrPush.id
    principalId: applicationServicePrincipalId
    principalType: 'ServicePrincipal'
  }
  scope: containerRegistry
}

// Allow the web app to pull an image from the ACR
resource acrPullRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(containerRegistry.name, 'AcrPull')
  properties: {
    roleDefinitionId: acrPull.id
    principalId: webApp.identity.principalId
    principalType: 'ServicePrincipal'
  }
  scope: containerRegistry
}






