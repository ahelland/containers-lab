#!/bin/bash

# Script to create a Kubernetes secret for Azure Container Registry access
# Retrieves ACR credentials dynamically using Azure CLI

set -e

# Parameters
RESOURCE_GROUP=${1:-"rg-acr"}
ACR_NAME=${2:-""}
NAMESPACE=${3:-"time"}
SECRET_NAME=${4:-"acr-secret"}

# If ACR name not provided, get it from the resource group
if [ -z "$ACR_NAME" ]; then
    echo "No ACR name provided, retrieving from resource group $RESOURCE_GROUP..."
    ACR_NAME=$(az acr list --resource-group $RESOURCE_GROUP --query "[0].name" -o tsv)
    
    if [ -z "$ACR_NAME" ]; then
        echo "Error: No ACR found in resource group $RESOURCE_GROUP"
        exit 1
    fi
fi

echo "Using ACR: $ACR_NAME"

# Get ACR login server (fully qualified domain)
ACR_LOGIN_SERVER="$ACR_NAME.azurecr.io"
echo "ACR Login Server: $ACR_LOGIN_SERVER"

# Get ACR credentials
echo "Retrieving ACR credentials..."
ACR_USERNAME=$(az acr credential show --name $ACR_NAME --query "username" -o tsv)
ACR_PASSWORD=$(az acr credential show --name $ACR_NAME --query "passwords[0].value" -o tsv)

if [ -z "$ACR_USERNAME" ] || [ -z "$ACR_PASSWORD" ]; then
    echo "Error: Failed to retrieve ACR credentials"
    exit 1
fi

echo "ACR Username: $ACR_USERNAME"

echo "Creating namespace $NAMESPACE..."
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

# Create Kubernetes secret
echo "Creating Kubernetes secret $SECRET_NAME in namespace $NAMESPACE..."
kubectl create secret docker-registry $SECRET_NAME \
  --docker-server=$ACR_LOGIN_SERVER \
  --docker-username=$ACR_USERNAME \
  --docker-password=$ACR_PASSWORD \
  --namespace $NAMESPACE \
  --dry-run=client -o yaml | kubectl apply -f -

echo "Secret created successfully!"

# Update image in deployment file
DEPLOYMENT_FILE="hellotime-deployment.yaml"
if [ -f "$DEPLOYMENT_FILE" ]; then
    echo "Updating image in $DEPLOYMENT_FILE..."
    # Replace the image tag (assuming format: acrname.azurecr.io/image:tag)
    sed -i.bak "s|image: .*|image: $ACR_LOGIN_SERVER/hellotime:v1|" "$DEPLOYMENT_FILE"
    echo "Updated image to: $ACR_LOGIN_SERVER/hellotime:v1"
else
    echo "Warning: $DEPLOYMENT_FILE not found, skipping image update"
fi

echo "Done!"