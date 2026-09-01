#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
TARGET_DIR="${REPO_ROOT}/infra/esg-spoke"

az bicep build --file "${TARGET_DIR}/main.bicep" --stdout >/dev/null
az bicep build --file "${TARGET_DIR}/adf-assets.bicep" --stdout >/dev/null

if rg -n "Bing\.Search\.v7|kind:[[:space:]]*'Bing\.Search'|BingSearch-POC" "${TARGET_DIR}"; then
  echo "Retired Bing Search API resource found." >&2
  exit 1
fi

if rg -n "publicNetworkAccess:[[:space:]]*'Enabled'|disableLocalAuth:[[:space:]]*false" "${TARGET_DIR}"; then
  echo "Insecure public access or local authentication setting found." >&2
  exit 1
fi

if rg -n "privateDnsZoneGroups|privateDnsZoneGroup" "${TARGET_DIR}"; then
  echo "Private DNS zone groups must be managed by central DINE policy." >&2
  exit 1
fi

if rg -n "/subscriptions/[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}" "${TARGET_DIR}"; then
  echo "Hard-coded subscription ID found in ESG Bicep." >&2
  exit 1
fi

rg -q "routeTableResourceId" "${TARGET_DIR}/modules/network.bicep"
rg -q "privateEndpointNetworkPolicies: 'Enabled'" "${TARGET_DIR}/modules/network.bicep"
rg -q "GroundingComplianceException" "${TARGET_DIR}/modules/ai-foundry.bicep"
rg -q "Definition only. Start explicitly after migration validation." "${TARGET_DIR}/adf-assets.bicep"

echo "ESG spoke Bicep and security contracts passed."
