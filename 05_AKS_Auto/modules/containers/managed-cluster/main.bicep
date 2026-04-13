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

var defaultAadProfile = {
  managed: true
  adminGroupObjectIDs: adminGroupObjectIDs
  enableAzureRBAC: azureRbac
}

resource aks 'Microsoft.ContainerService/managedClusters@2025-10-02-preview' = {
  sku: clusterSku
  identity: clusterIdentity
  location: location
  name: resourceName
  properties: {
    enableRBAC: enableRBAC
    nodeResourceGroup: nodeResourceGroup
    nodeResourceGroupProfile: nodeResourceGroupProfile
    nodeProvisioningProfile: nodeProvisioningProfile
    disableLocalAccounts: disableLocalAccounts
    aadProfile: (enableAadProfile ? defaultAadProfile : null)
    autoUpgradeProfile: {
      upgradeChannel: upgradeChannel
      nodeOSUpgradeChannel: nodeOSUpgradeChannel
    }
    addonProfiles: {}
    supportPlan: supportPlan
    agentPoolProfiles: [
      {
        name: 'systempool'
        mode: 'System'
        count: 3
      }
    ]
    networkProfile: {
      advancedNetworking: {
        enabled: (enableContainerNetworkObservability || enableContainerNetworkSecurity)
        observability: {
          enabled: enableContainerNetworkObservability
        }
        security: {
          enabled: enableContainerNetworkSecurity
        }
      }
    }
  }
  tags: resourceTags
  dependsOn: []
}
