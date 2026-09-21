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

### Azure public DNS
# Used for cert-manager's ClusterIssuer/Certificate and the Traefik ingress
# routes (e.g. traefik.<zone>, flux.<zone>).
export DNS_ZONE_NAME="placeholder"
export DNS_RESOURCE_GROUP="rg-core-dns"
