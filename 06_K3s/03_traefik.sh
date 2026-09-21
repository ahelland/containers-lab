#!/bin/bash
# Source shared variables (e.g. DNS zone) so they are not hard-coded in each script.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/env.sh"

### Traefik

sudo tee /var/lib/rancher/k3s/server/manifests/k3s-traefik-config.yaml > /dev/null <<EOF
apiVersion: helm.cattle.io/v1
kind: HelmChartConfig
metadata:
  name: traefik
  namespace: kube-system
spec:
  valuesContent: |-
    providers:
      kubernetesIngress:
        enabled: true
      kubernetesGateway:
        enabled: true
    gateway:
      listeners:
        web:
          port: 8080
          protocol: HTTP
          namespacePolicy:
            from: All
        websecure:
          port: 8443
          protocol: HTTPS
          mode: Terminate
          certificateRefs:
            - kind: Secret
              name: tls-secret
              namespace: cert-manager
          namespacePolicy:
            from: All
EOF

# Restart k3s
sudo systemctl restart k3s 

### Traefik config
cat > traefik-rbac.yaml <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: traefik-cluster-role
rules:
  - apiGroups: [""]
    resources: ["services", "endpointslices", "namespaces", "pods", "configmaps", "secrets"]
    verbs: ["get", "list", "watch"]
  - apiGroups: ["traefik.io"]
    resources: ["ingressroutes", "traefikservices", "tlsoptions"]
    verbs: ["get", "list", "watch"]
  - apiGroups: ["gateway.networking.k8s.io"]
    resources: ["gatewayclasses", "gateways", "httproutes", "tlsroutes"]
    verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: traefik-cluster-role-binding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: traefik-cluster-role
subjects:
  - kind: ServiceAccount
    name: traefik
    namespace: kube-system
EOF

kubectl apply -f traefik-rbac.yaml

cat > traefik-referencegrant.yaml <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: ReferenceGrant
metadata:
  name: allow-gateway-to-tls-secret
  namespace: cert-manager
spec:
  from:
    - group: gateway.networking.k8s.io
      kind: Gateway
      namespace: kube-system
  to:
    - group: ""
      kind: Secret
      name: tls-secret
EOF

kubectl apply -f traefik-referencegrant.yaml

cat > traefik-dashboard.yaml <<EOF
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: traefik-dashboard
  namespace: kube-system
spec:
  entryPoints:
    - websecure
  routes:
    - match: Host("traefik.${DNS_ZONE_NAME}")
      middlewares: []
      services:
        - name: api@internal
          kind: TraefikService
EOF

kubectl apply -f traefik-dashboard.yaml