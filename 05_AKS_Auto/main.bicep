targetScope = 'subscription'

@description('The name of the Managed Cluster resource.')
param resourceName string

@description('The location of AKS resource.')
param location string

@description('Tags retrieved from parameter file.')
param resourceTags object = {}

@metadata({ descirption: 'The managed cluster SKU tier.' })
param clusterSku object = {
  name: 'Automatic'
  tier: 'Standard'
}

@description('The identity of the managed cluster, if configured.')
param clusterIdentity object = {
  type: 'SystemAssigned'
}

@description('Flag to turn on or off of Microsoft Entra ID Profile.')
param enableAadProfile bool = false

@description('Boolean flag to turn on and off of RBAC.')
param enableRBAC bool = true

@description('The name of the resource group containing agent pool nodes.')
param nodeResourceGroup string

@description('Node resource group lockdown profile for a managed cluster.')
param nodeResourceGroupProfile object = {
  restrictionLevel: 'ReadOnly'
}

@description('The node provisioning mode.')
param nodeProvisioningProfile object = {
  mode: 'Auto'
}

@description('Auto upgrade channel for a managed cluster.')
param upgradeChannel string = 'stable'

@description('An array of Microsoft Entra group object ids to give administrative access.')
param adminGroupObjectIDs array = []

@description('Enable or disable Azure RBAC.')
param azureRbac bool = false

@description('Enable or disable local accounts.')
param disableLocalAccounts bool = false

@description('Auto upgrade channel for node OS security.')
param nodeOSUpgradeChannel string = 'NodeImage'

param supportPlan string = 'KubernetesOfficial'

@description('Boolean flag to turn on and off Container Network Observability.')
param enableContainerNetworkObservability bool = true

@description('Boolean flag to turn on and off Container Network Security.')
param enableContainerNetworkSecurity bool = true

resource rg_aks 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: 'rg-aks-auto'
  location: location
  tags: resourceTags
}

module cluster 'modules/containers/managed-cluster/main.bicep' = {
  name: 'aks'
  scope: rg_aks
  params: {
    location: location
    resourceName: resourceName
    resourceTags: resourceTags
    clusterSku: clusterSku
    clusterIdentity: clusterIdentity
    enableAadProfile: enableAadProfile
    enableRBAC: enableRBAC
    nodeResourceGroup: nodeResourceGroup
    nodeResourceGroupProfile: nodeResourceGroupProfile
    nodeProvisioningProfile: nodeProvisioningProfile
    upgradeChannel: upgradeChannel
    adminGroupObjectIDs: adminGroupObjectIDs
    azureRbac: azureRbac
    disableLocalAccounts: disableLocalAccounts
    nodeOSUpgradeChannel: nodeOSUpgradeChannel
    supportPlan: supportPlan
    enableContainerNetworkObservability: enableContainerNetworkObservability
    enableContainerNetworkSecurity: enableContainerNetworkSecurity
  }
}
