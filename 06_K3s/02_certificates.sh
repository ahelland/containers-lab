#!/bin/bash
# Source shared variables (e.g. DNS zone) so they are not hard-coded in each script.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/env.sh"

### Cert-manager
# Make sure the managed identity has permissions to DNS
 az role assignment create \
        --role "DNS Zone Contributor" \
        --assignee "${USER_ASSIGNED_CLIENT_ID}" \
        --scope "$(az network dns zone show \
            --name "${DNS_ZONE_NAME}" \
            --resource-group "${DNS_RESOURCE_GROUP}" \
            --subscription "${SUBSCRIPTION}" \
            --query id \
            --output tsv)"

az k8s-extension create \
    --resource-group "${RESOURCE_GROUP}" \
    --cluster-name "${CLUSTER_NAME}" \
    --cluster-type connectedClusters \
    --name "azure-cert-management" \
    --extension-type "microsoft.certmanagement" \
    --config cert-manager.config.enableGatewayAPI=true \
    --config cert-manager.crds.keep=true \
    --config trust-manager.defaultPackage.enabled=false \
    --config trust-manager.secretTargets.enabled=true \
    --config trust-manager.secretTargets.authorizedSecretsAll=true

# Apply labels to make cert-manager use the managed identity for workload identity federation
kubectl label deployment     cert-manager -n cert-manager azure.workload.identity/use=true
kubectl label serviceaccount cert-manager -n cert-manager azure.workload.identity/use=true

kubectl patch deployment cert-manager -n cert-manager -p '{"spec":{"template":{"metadata":{"labels":{"azure.workload.identity/use":"true"}}}}}'
kubectl patch serviceaccount cert-manager -n cert-manager -p "{\"metadata\":{\"annotations\":{\"azure.workload.identity/client-id\":\"${USER_ASSIGNED_CLIENT_ID}\"}}}"

# FIC for cert-manager (FIC_CERT_NAME comes from env.sh)
az identity federated-credential create --name "${FIC_CERT_NAME}" --identity-name "${USER_ASSIGNED_IDENTITY_NAME}" --resource-group "${RESOURCE_GROUP}" --issuer "${OIDC_ISSUER}" --subject system:serviceaccount:cert-manager:cert-manager --audience api://AzureADTokenExchange

# Apply ClusterIssuer and Certificate manifests
cat > clusterissuer.yaml <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt
  namespace: cert-manager  
spec:
  acme:
    server: https://acme-staging-v02.api.letsencrypt.org/directory
    privateKeySecretRef:
      name: letsencrypt-private-key
    solvers:
    - dns01:
        azureDNS:
          managedIdentity:
            clientID: ${USER_ASSIGNED_CLIENT_ID}
          subscriptionID: ${SUBSCRIPTION}
          resourceGroupName: ${DNS_RESOURCE_GROUP}
          hostedZoneName: "${DNS_ZONE_NAME}"
          environment: AzurePublicCloud
EOF

kubectl apply -f clusterissuer.yaml

# Certificate
cat > certificate.yaml <<EOF
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: wild-${DNS_ZONE_NAME}
  namespace: cert-manager
spec:
  secretName: tls-secret
  issuerRef:
    name: letsencrypt
    kind: ClusterIssuer
  dnsNames:
    - "*.${DNS_ZONE_NAME}"
EOF

kubectl apply -f certificate.yaml