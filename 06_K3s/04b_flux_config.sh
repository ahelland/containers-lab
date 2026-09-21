#!/bin/bash
# Apply the DNS-specific route directly (NOT Flux-managed), so the public repo
# can keep a generic placeholder. Run AFTER 04_flux_bootstrap.sh.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/env.sh"

### vikunja HTTPRoute — rendered with the real DNS zone, then applied directly
# The committed template (Flux/vikunja/httproute.yaml) keeps a __DNS_ZONE__
# placeholder and is intentionally NOT managed by Flux. We render it here with
# the real zone from env.sh and apply it to the cluster. Because Flux does not
# manage this route, it will not be reverted on the next reconcile.
#
# (The publicurl is intentionally omitted: behind Traefik, Vikunja uses the
#  request's Host header for absolute URLs, so it is redundant.)
sed "s|__DNS_ZONE__|${DNS_ZONE_NAME}|g" "${SCRIPT_DIR}/Flux/vikunja/httproute.yaml" | kubectl apply -f -

# Confirm the rendered hostnames:
kubectl get httproute vikunja-route -n vikunja -o jsonpath='{.spec.hostnames}{"\n"}'
