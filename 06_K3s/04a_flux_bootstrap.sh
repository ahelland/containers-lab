#!/bin/bash
# Source shared variables (e.g. DNS zone) so they are not hard-coded in each script.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/env.sh"

### Flux
# Install Flux
helm install flux-operator oci://ghcr.io/controlplaneio-fluxcd/charts/flux-operator \
  --namespace flux-system \
  --create-namespace

# FIC for flux
# RESOURCE_GROUP / CLUSTER_NAME / USER_ASSIGNED_IDENTITY_NAME come from env.sh.
# Flux gets its own federated credential, distinct from the base one in env.sh.
export FEDERATED_IDENTITY_CREDENTIAL_NAME="k3sFedIdentity-Flux"

# OIDC_ISSUER is exported by 01_onboarding.sh; re-derive here as a fallback.
OIDC_ISSUER="$(az connectedk8s show --name "${CLUSTER_NAME}" --resource-group "${RESOURCE_GROUP}" --query "oidcIssuerProfile.issuerUrl" --output tsv)"

az identity federated-credential create --name "${FEDERATED_IDENTITY_CREDENTIAL_NAME}" --identity-name "${USER_ASSIGNED_IDENTITY_NAME}" --resource-group "${RESOURCE_GROUP}" --issuer "${OIDC_ISSUER}" --subject "system:serviceaccount:flux-system:source-controller" --audience api://AzureADTokenExchange

export USER_ASSIGNED_CLIENT_ID="$(az identity show --resource-group "${RESOURCE_GROUP}" --name "${USER_ASSIGNED_IDENTITY_NAME}" --query 'clientId' --output tsv)"

# PATCH flux-operator to use WIF
kubectl patch deployment source-controller -n flux-system \
  --type='merge' -p='
metadata:
  labels:
    azure.workload.identity/use: "true"
spec:
  template:
    metadata:
      labels:
        azure.workload.identity/use: "true"
'

kubectl patch serviceaccount source-controller -n flux-system \
  --type='merge' -p='
metadata:
  annotations:
    azure.workload.identity/client-id: ${USER_ASSIGNED_CLIENT_ID}
  labels:
    azure.workload.identity/use: "true"
'


# fluxinstance.yaml
cat > flux_instance.yaml <<EOF
apiVersion: fluxcd.controlplane.io/v1
kind: FluxInstance
metadata:
  name: flux
  namespace: flux-system
  annotations:
    fluxcd.controlplane.io/reconcileEvery: "1h"
    fluxcd.controlplane.io/reconcileArtifactEvery: "10m"
    fluxcd.controlplane.io/reconcileTimeout: "5m"
spec:
  distribution:
    version: "2.x"
    registry: "ghcr.io/fluxcd"
    artifact: "oci://ghcr.io/controlplaneio-fluxcd/flux-operator-manifests"
  components:
    - source-controller
    - kustomize-controller
    - helm-controller
    - notification-controller
    - image-reflector-controller
    - image-automation-controller
  cluster:
    type: kubernetes
    size: medium
    multitenant: false
    networkPolicy: true
    domain: "cluster.local"
  kustomize:
    patches:
      - target:
          kind: Deployment
        patch: |
          - op: replace
            path: /spec/template/spec/nodeSelector
            value:
              kubernetes.io/os: linux
          - op: add
            path: /spec/template/spec/tolerations
            value:
              - key: "CriticalAddonsOnly"
                operator: "Exists"
EOF

kubectl apply -f flux_instance.yaml

# flux-gw.yaml (maps a route in Traefik)
cat > flux_gateway.yaml <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: flux
  namespace: flux-system
spec:
  parentRefs:
    - kind: Gateway
      name: traefik-gateway
      namespace: kube-system
  hostnames:
    - "flux.${DNS_ZONE_NAME}"
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /
      backendRefs:
        - name: flux-operator
          port: 9080
EOF

kubectl apply -f flux_gateway.yaml

cat > flux_bootstrap.yaml <<EOF
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: gitops-config
  namespace: flux-system
spec:
  interval: 5m0s
  url: https://github.com/ahelland/containers-lab
  ref:
    branch: main
---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: flux
  namespace: flux-system
spec:
  interval: 10m0s
  path: "./06_K3s/Flux/kustomizations"
  prune: true
  sourceRef:
    kind: GitRepository
    name: gitops-config
EOF

kubectl apply -f flux_bootstrap.yaml

