using 'main.bicep' 

param resourceName = 'auto'
param location = 'norwayeast'
param enableRBAC = true
param nodeResourceGroup = 'MC_rg-aks-auto_auto_norwayeast'

param nodeResourceGroupProfile = {
  restrictionLevel: 'ReadOnly'
}

param nodeProvisioningProfile = {
  mode: 'Auto'
}

param clusterIdentity = {
  type: 'SystemAssigned'
}

param clusterSku = {
  name: 'Automatic'
  tier: 'Standard'
}

param upgradeChannel = 'stable'

param disableLocalAccounts = true
param enableAadProfile = true
param azureRbac = true
param adminGroupObjectIDs = []
param supportPlan = 'KubernetesOfficial'
param nodeOSUpgradeChannel = 'NodeImage'
param enableContainerNetworkObservability = false
param enableContainerNetworkSecurity = false
