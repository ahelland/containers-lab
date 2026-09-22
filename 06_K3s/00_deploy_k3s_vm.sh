#!/bin/bash
# Create the k3s VM in Azure, then SSH into it. Run this first (before 01-04).
# Static config (region, image, username) comes from env.sh; the VM name and
# resource group get a random suffix so a re-run creates fresh, non-conflicting
# resources.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/env.sh"

# Random suffix so re-running this script creates fresh, non-conflicting names.
# Prefixes come from env.sh so cleanup_k3s_vm.sh can find prior VMs by the same
# prefix.
export RANDOM_ID="$(openssl rand -hex 3)"
export VM_RESOURCE_GROUP_NAME="${VM_RESOURCE_GROUP_PREFIX}${RANDOM_ID}"
export VM_NAME="${VM_NAME_PREFIX}${RANDOM_ID}"

#Login to Azure
az login

# Create RG:
az group create --name "${VM_RESOURCE_GROUP_NAME}" --location "${LOCATION}"

az vm create \
  --resource-group "${VM_RESOURCE_GROUP_NAME}" \
  --name "${VM_NAME}" \
  --image "${VM_IMAGE}" \
  --admin-username "${VM_USERNAME}" \
  --assign-identity \
  --generate-ssh-keys \
  --public-ip-sku Standard

export IP_ADDRESS="$(az vm show --show-details --resource-group "${VM_RESOURCE_GROUP_NAME}" --name "${VM_NAME}" --query publicIps --output tsv)"

ssh -o StrictHostKeyChecking=no "${VM_USERNAME}@${IP_ADDRESS}"

# Once inside the VM, run the following commands before running the rest of the lab scripts (01-04):
# git clone https://github.com/ahelland/containers-lab
# sudo apt update && sudo apt upgrade
# sudo reboot