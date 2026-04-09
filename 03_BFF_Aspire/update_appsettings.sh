#!/bin/bash

# Script to update appsettings.json with Azure tenantId and subscriptionId
# from the currently logged-in Azure account

set -e

# Get the current Azure account info
AZ_ACCOUNT=$(az account show)

# Extract tenantId and subscriptionId
TENANT_ID=$(echo "$AZ_ACCOUNT" | jq -r '.tenantId')
SUBSCRIPTION_ID=$(echo "$AZ_ACCOUNT" | jq -r '.id')

echo "Extracted values:"
echo "  TenantId: $TENANT_ID"
echo "  SubscriptionId: $SUBSCRIPTION_ID"

# Find the appsettings.json file (look in current directory and parent directories)
APPSETTINGS_FILE="BFF_Web_App.AppHost/appsettings.json"

if [ ! -f "$APPSETTINGS_FILE" ]; then
    echo "Error: appsettings.json not found at $APPSETTINGS_FILE"
    exit 1
fi

# Backup the original file
cp "$APPSETTINGS_FILE" "${APPSETTINGS_FILE}.backup"

# Update the appsettings.json file using jq
jq --arg tenantId "$TENANT_ID" \
   --arg subscriptionId "$SUBSCRIPTION_ID" \
   '.Parameters.TenantId = $tenantId | .Azure.SubscriptionId = $subscriptionId' \
   "$APPSETTINGS_FILE" > "${APPSETTINGS_FILE}.tmp" && \
   mv "${APPSETTINGS_FILE}.tmp" "$APPSETTINGS_FILE"

echo ""
echo "Updated $APPSETTINGS_FILE successfully!"
echo "Backup created at: ${APPSETTINGS_FILE}.backup"
