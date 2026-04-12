metadata name = 'Azure Key Vault'
metadata description = 'Azure Key Vault'
metadata owner = 'anhell42'

@description('Specifies the location for resources.')
param location string = resourceGroup().location
@description('Name of Key Vault.')
param kvName string
@allowed([
  'standard'
  'premium'
])
@description('Sku of Key Vault.')
param sku string
@description('Should soft delete be enabled?')
param enableSoftDelete bool
@description('Enable RBAC model (default). False to use access policies.')
param enableRbacAuthorization bool = true
@description('TenantId')
param tenantId string
@description('Tags retrieved from parameter file.')
param resourceTags object = {}
@description('Enable diagnostic logs')
param enableDiagnostics bool = false
@description('Storage account resource id. Only required if enableDiagnostics is set to true.')
param diagnosticStorageAccountId string = ''
@description('Log analytics workspace resource id. Only required if enableDiagnostics is set to true.')
param logAnalyticsWorkspaceId string = ''
@description('Should retention of logs be enabled?')
param logRetentionEnabled bool
@description('How long to retain logs (if retention is enabled)')
param logRetentionDays int = 0
@description('How long to retain deleted keys/secrets (for purge protection).')
param softDeleteRetentionInDays int

var diagnosticsName = '${keyvault.name}-dgs'

resource keyvault 'Microsoft.KeyVault/vaults@2025-05-01' = {
  name: kvName
  location: location
  tags: resourceTags
  properties: {
    sku: {
      family: 'A'
      name: sku
    }
    tenantId: tenantId
    enabledForDeployment: false
    enabledForDiskEncryption: false
    enabledForTemplateDeployment: true
    enableSoftDelete: enableSoftDelete
    softDeleteRetentionInDays: softDeleteRetentionInDays
    enableRbacAuthorization: enableRbacAuthorization
  }
}

resource diagnostics 'microsoft.insights/diagnosticSettings@2021-05-01-preview' = if (enableDiagnostics) {
  scope: keyvault
  name: diagnosticsName
  properties: {
    workspaceId: empty(logAnalyticsWorkspaceId) ? null : logAnalyticsWorkspaceId
    storageAccountId: empty(diagnosticStorageAccountId) ? null : diagnosticStorageAccountId
    logs: [
      {
        category: 'AuditEvent'
        enabled: true
        retentionPolicy: {
          days: logRetentionDays
          enabled: logRetentionEnabled
        }
      }
      {
        category: 'AzurePolicyEvaluationDetails'
        enabled: false
        retentionPolicy: {
          days: 0
          enabled: false
        }
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
        retentionPolicy: {
          days: logRetentionDays
          enabled: logRetentionEnabled
        }
      }
    ]
  }
}

@description('The key vault name.')
output kvName string = kvName
@description('The Key Vault Uri')
output kvUri string = keyvault.properties.vaultUri
