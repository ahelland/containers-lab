#!/bin/bash
# Source shared variables (e.g. DNS zone) so they are not hard-coded in each script.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/env.sh"

### Install K3s:
# Azure CLI
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# Install Helm
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-4
chmod 700 get_helm.sh
./get_helm.sh

# K3s:
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--write-kubeconfig-mode 644" sh -

### Azure ARC
# RESOURCE_GROUP / LOCATION / CLUSTER_NAME are defined in env.sh (sourced above).

#Login to Azure
az login

# Create RG:
az group create --name "${RESOURCE_GROUP}" --location "${LOCATION}" --output table

# By default k3s does not use the local kubeconfig file at ~/.kube/config. 
sudo k3s kubectl config view --raw > ~/.kube/config

# Connect k3s:
az connectedk8s connect --name "${CLUSTER_NAME}" --resource-group "${RESOURCE_GROUP}" --location "${LOCATION}" --skip-ssl-verification --enable-oidc-issuer --enable-workload-identity

# Extract the OIDC issuer URL for the connected cluster (exported so later
# scripts, e.g. 02_certificates.sh, can use it when run as a subprocess).
export OIDC_ISSUER="$(az connectedk8s show --name "${CLUSTER_NAME}" --resource-group "${RESOURCE_GROUP}" --query "oidcIssuerProfile.issuerUrl" --output tsv)"

# Configure k3s to use the OIDC issuer URL for service account tokens
sudo tee /etc/rancher/k3s/config.yaml > /dev/null <<EOF
kube-apiserver-arg:
  - "service-account-issuer=${OIDC_ISSUER}"
  - "service-account-max-token-expiration=24h"
EOF

sudo systemctl restart k3s

## Additional variables
# Identity / service-account names come from env.sh (sourced above).
# SUBSCRIPTION is derived from the currently logged-in Azure account.
export SUBSCRIPTION="$(az account show --query id --output tsv)"

### Workload Identity Federation (WIF)
# https://learn.microsoft.com/en-us/azure/azure-arc/kubernetes/workload-identity

az identity create --name "${USER_ASSIGNED_IDENTITY_NAME}" --resource-group "${RESOURCE_GROUP}" --location "${LOCATION}" --subscription "${SUBSCRIPTION}"

export USER_ASSIGNED_CLIENT_ID="$(az identity show --resource-group "${RESOURCE_GROUP}" --name "${USER_ASSIGNED_IDENTITY_NAME}" --query 'clientId' --output tsv)"

cat > azure-wif-sa.yaml <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: ${SERVICE_ACCOUNT_NAMESPACE}
---
apiVersion: v1
kind: ServiceAccount
metadata:
  annotations:
    azure.workload.identity/client-id: ${USER_ASSIGNED_CLIENT_ID}
  name: ${SERVICE_ACCOUNT_NAME}
  namespace: ${SERVICE_ACCOUNT_NAMESPACE}
EOF

kubectl apply -f azure-wif-sa.yaml

az identity federated-credential create --name "${FEDERATED_IDENTITY_CREDENTIAL_NAME}" --identity-name "${USER_ASSIGNED_IDENTITY_NAME}" --resource-group "${RESOURCE_GROUP}" --issuer "${OIDC_ISSUER}" --subject system:serviceaccount:"${SERVICE_ACCOUNT_NAMESPACE}":"${SERVICE_ACCOUNT_NAME}" --audience api://AzureADTokenExchange