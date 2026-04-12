#!/bin/bash

# Script to update acrName parameter in main.bicepparam
# with the actual ACR name from the rg-acr resource group

# Get the ACR name from Azure
ACR_NAME=$(az acr list --resource-group rg-acr --query "[0].name" -o tsv)

if [ -z "$ACR_NAME" ]; then
    echo "Error: No ACR found in resource group rg-acr"
    exit 1
fi

echo "Found ACR: $ACR_NAME"

# Update the acrName parameter in main.bicepparam
PARAM_FILE="main.bicepparam"

if [ ! -f "$PARAM_FILE" ]; then
    echo "Error: Parameter file $PARAM_FILE not found"
    exit 1
fi

# Replace the acrName value using sed
sed -i.bak "s|param acrName = '.*'|param acrName = '$ACR_NAME'|" "$PARAM_FILE"

echo "Updated $PARAM_FILE with acrName = '$ACR_NAME'"
