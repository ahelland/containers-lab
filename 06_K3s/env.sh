# Shared configuration for the K3s lab.
# Source this file from the lab scripts instead of hard-coding values in each one.
# Edit values here and every script picks them up.

### Azure
export RESOURCE_GROUP="rg-k3s"
export LOCATION="northeurope"
export CLUSTER_NAME="k3s01"

### Workload Identity Federation (WIF)
export USER_ASSIGNED_IDENTITY_NAME="k3sIdentity"
export FEDERATED_IDENTITY_CREDENTIAL_NAME="k3sFedIdentity"
export FIC_CERT_NAME="k3sFedIdentity-CertManager"

export SERVICE_ACCOUNT_NAMESPACE="azure-wif"
export SERVICE_ACCOUNT_NAME="azure-sa"

### VM (k3s node)
# Static config for the VM created by 00_deploy_k3s_vm.sh. The VM name and
# resource group are built from these prefixes + a random suffix (so a re-run
# creates fresh, non-conflicting resources). cleanup_k3s_vm.sh uses the same
# prefix to find and delete prior VMs.
export VM_USERNAME="azureuser"
export VM_IMAGE="canonical:ubuntu-24_04-lts:server:latest"
export VM_NAME_PREFIX="myVM"
export VM_RESOURCE_GROUP_PREFIX="rg-k3s-vm"

### Azure public DNS
# Used for cert-manager's ClusterIssuer/Certificate and the Traefik ingress
# routes (e.g. traefik.<zone>, flux.<zone>).
export DNS_ZONE_NAME="placeholder"
export DNS_RESOURCE_GROUP="rg-core-dns"
