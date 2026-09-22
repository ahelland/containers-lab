#!/bin/bash
# Delete the k3s VM(s) created by 00_deploy_k3s_vm.sh.
#
# 00 appends a random suffix to VM_RESOURCE_GROUP_PREFIX, so we can't know the
# exact name in advance; instead we match every resource group that starts with
# that prefix and delete it (and everything inside, including the VM).
#
# This only targets "${VM_RESOURCE_GROUP_PREFIX}*" (e.g. rg-k3s-vm*) and does
# NOT touch the cluster's own RESOURCE_GROUP (rg-k3s) — the Arc connected
# cluster and WIF identity live there and are left intact.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/env.sh"

# Find all resource groups matching the prefix (00 appends a random suffix).
rgs="$(az group list --query "[?starts_with(name, '${VM_RESOURCE_GROUP_PREFIX}')].name" --output tsv)"
if [ -z "$rgs" ]; then
  echo "No resource groups matching '${VM_RESOURCE_GROUP_PREFIX}*' found — nothing to clean up."
  exit 0
fi

echo "Found the following resource group(s) to delete:"
echo "$rgs"
echo

# Ask before destroying — this is irreversible.
read -r -p "Delete all of the above? [y/N] " confirm
case "$confirm" in
  [Yy]*) ;;
  *) echo "Aborted — nothing deleted." >&2; exit 1 ;;
esac

for rg in $rgs; do
  echo "Deleting resource group '${rg}' (and its VMs)…"
  az group delete --name "$rg" --yes
done

echo "Cleanup done."
