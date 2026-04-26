targetScope = 'subscription'

@description('Azure region to deploy resources into.')
param location string
@description('Tags retrieved from parameter file.')
param resourceTags object = {}
@description('Name of the ACR to be used for container app deployments. Assumed to already exist.')
param acrName string
param tenantId string = tenant().tenantId

var ficClientId string = entraApp.outputs.clientId

@description('Environment variables for the Weather API Container App')
var weatherAPIEnvironmentVariables = [
  {
    name: 'ASPNETCORE_ENVIRONMENT'
    value: 'Production'
  }
  {
    name: 'ClientId'
    value: ficClientId
  }
  {
    name: 'TenantId'
    value: tenantId
  }
]

@description('Environment variables for the Web App Container App')
var webappEnvironmentVariables = [
  {
    name: 'ASPNETCORE_ENVIRONMENT'
    value: 'Production'
  }
  {
    name: 'ClientId'
    value: ficClientId
  }
  {
    name: 'TenantId'
    value: tenantId
  }
  {
    name: 'IdentifierUri'
    value: 'api://${tenantId}/bff-dotnet10-aca'
  }
  {
    name: 'UamiId'
    value: userMiCAE.outputs.clientId
  }
  {
    name: 'ASPNETCORE_FORWARDEDHEADERS_ENABLED'
    value: 'true'
  }
  {
    name: 'dnsSuffix'
    value: containerenvironment.outputs.defaultDomain
  }
]

@description('The name of the App Registration')
param AppName string

resource rg_cae 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: 'rg-bff-cae'
  location: location
  tags: resourceTags
}

resource rg_acr 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: 'rg-acr'  
  location: location
  tags: resourceTags
}

module containerenvironment './modules/containers/container-environment/main.bicep' = {
  scope: rg_cae
  name: 'bff-cae-01'
  params: {
    location: location
    environmentName: 'bff-cae-01'
  }
  dependsOn: [
    keyvault
   ]
}

module keyvault 'modules/keyvault/keyvault/main.bicep' = {
  scope: rg_cae
  name: 'keyvault'
  params: {
    resourceTags: resourceTags
    location: location
    kvName: 'kv${uniqueString(subscription().id)}'
    enableSoftDelete: false
    enableDiagnostics: false
    sku: 'standard'
    tenantId: tenantId
    logRetentionEnabled: false
    softDeleteRetentionInDays: 7
  }
}

module entraApp 'modules/graph/entra-app/app-registration.bicep' = {
  name: 'entra-app'
  scope: rg_cae
  params: {
    appName: AppName
    managedIdentityName: userMiCAE.name
    caeDomainName: containerenvironment.outputs.defaultDomain
    keyVaultName: keyvault.outputs.kvName
    location: location
    subjectName: 'CN=bff.contoso.com'
  }
}

module userMiCAE './modules/identity/user-managed-identity/main.bicep' = {
  scope: rg_cae
  name: 'bff-cae-user-mi'
  params: {
    location: location
    miname: 'bff-cae-user-mi'
  }
}

module acrRole './modules/identity/role-assignment-rg/main.bicep' = {
  scope: rg_acr
  name: 'bff-cae-mi-acr-role'
  params: {
    principalId: userMiCAE.outputs.managedIdentityPrincipal
    principalType: 'ServicePrincipal'
    roleName: 'AcrPull'
  }
}

module weatherapi './modules/containers/container-app/main.bicep' = {
  scope: rg_cae
  name: 'weatherapi'
  params: {
    location: location
    resourceTags: resourceTags
    containerAppEnvironmentId: containerenvironment.outputs.id
    containerRegistry: '${acrName}.azurecr.io'
    containerImage: '${acrName}.azurecr.io/bff-weatherapi:v1'
    targetPort: 8080
    transport: 'http'
    externalIngress: false
    containerName: 'weatherapi'
    identityName: 'bff-cae-user-mi'
    name: 'weatherapi'
    minReplicas: 1
    envVars: weatherAPIEnvironmentVariables
  }
}

module bff './modules/containers/container-app/main.bicep' = {
  scope: rg_cae
  name: 'bff-web-app'
  params: {
    location: location
    resourceTags: resourceTags
    containerAppEnvironmentId: containerenvironment.outputs.id
    containerRegistry: '${acrName}.azurecr.io'
    containerImage: '${acrName}.azurecr.io/bff-webapp:v1'
    targetPort: 8080
    externalIngress: true
    containerName: 'bffwebapp'
    identityName: 'bff-cae-user-mi'
    name: 'bff-web-app'
    minReplicas: 1
    envVars: webappEnvironmentVariables
  }
}
