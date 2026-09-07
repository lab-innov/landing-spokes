#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
TARGET_DIR="${REPO_ROOT}/infra/ifiscaf-spoke"

az bicep build --file "${TARGET_DIR}/main.bicep" --stdout >/dev/null
az bicep build --file "${TARGET_DIR}/adf-assets.bicep" --stdout >/dev/null
az bicep build-params --file "${REPO_ROOT}/environments/ifiscaf-spoke/ifiscaf-spoke.example.bicepparam" --stdout >/dev/null
az bicep build-params --file "${REPO_ROOT}/environments/ifiscaf-spoke/adf-assets.example.bicepparam" --stdout >/dev/null

if rg -n --glob '*.bicep' "publicNetworkAccess:[[:space:]]*'Enabled'|disableLocalAuth:[[:space:]]*false|allowSharedKeyAccess:[[:space:]]*true" "${TARGET_DIR}"; then
  echo "Insecure public access or local/key authentication setting found." >&2
  exit 1
fi

if rg -n --glob '*.bicep' "privateDnsZoneGroups|privateDnsZoneGroup|Microsoft\.Network/privateDnsZones" "${TARGET_DIR}"; then
  echo "Private DNS zones and zone groups must be managed by central policy." >&2
  exit 1
fi

if rg -n --glob '*.bicep' "AzureWebJobsStorage[[:space:]]*'|COSMOS_DB_CONNECTION_STRING|BLOB_STORAGE_CONNECTION_STRING|listKeys\(|encryptedCredential|accessToken" "${TARGET_DIR}"; then
  echo "Secret-bearing application configuration found." >&2
  exit 1
fi

if rg -n --glob '*.bicep' "Microsoft\.Web/sites/deployments|Microsoft\.Web/sites/functions@|sqlRoleDefinitions@|gremlinRoleDefinitions@|tableRoleDefinitions@|raiPolicies@|Microsoft\.EventGrid/systemTopics" "${TARGET_DIR}"; then
  echo "Export-generated child resources or role definitions found." >&2
  exit 1
fi

if rg -n --glob '*.bicep' "kind:[[:space:]]*'AIServices'|accounts/projects|networkInjections|Microsoft\.Bing" "${TARGET_DIR}"; then
  echo "Foundry or Bing resources are not part of the direct Azure OpenAI IFISCAF spoke." >&2
  exit 1
fi

if rg -n --glob '*.bicep' "/subscriptions/[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}" "${TARGET_DIR}"; then
  echo "Hard-coded subscription ID found in IFISCAF Bicep." >&2
  exit 1
fi

rg -q "routeTableResourceId" "${TARGET_DIR}/modules/network.bicep"
rg -q "privateEndpointNetworkPolicies: 'Enabled'" "${TARGET_DIR}/modules/network.bicep"
rg -q "Microsoft.Databricks/workspaces" "${TARGET_DIR}/modules/network.bicep"
rg -q "enableNoPublicIp" "${TARGET_DIR}/modules/databricks.bicep"
rg -q "AzureWebJobsStorage__accountName" "${TARGET_DIR}/modules/function-app.bicep"
rg -q "enableFreeTier: false" "${TARGET_DIR}/modules/cosmos-db.bicep"
rg -q "containerThroughput: 400" "${TARGET_DIR}/main.bicep"
rg -q "'/id'" "${TARGET_DIR}/modules/cosmos-db.bicep"
rg -q "authentication: 'MSI'" "${TARGET_DIR}/adf-assets.bicep"
rg -q "name: 'RunProcess'" "${TARGET_DIR}/adf-assets.bicep"
rg -q "name: 'UpdateCosmosOnFail'" "${TARGET_DIR}/adf-assets.bicep"
rg -q "'Failed'" "${TARGET_DIR}/adf-assets.bicep"
rg -q "blobPathBeginsWith: '/source/blobs/'" "${TARGET_DIR}/adf-assets.bicep"
rg -q "blobPathEndsWith: 'ParametrosAnio.json'" "${TARGET_DIR}/adf-assets.bicep"
rg -Fq 'blobPathBeginsWith: '\''/${sharedSyntheticContainerName}/blobs/ejecuciones/'\''' "${TARGET_DIR}/adf-assets.bicep"
rg -q "Definition only. Start explicitly after migration validation." "${TARGET_DIR}/adf-assets.bicep"
rg -q "output triggersStarted bool = false" "${TARGET_DIR}/adf-assets.bicep"
rg -q "Storage Blob Data Reader" "${REPO_ROOT}/infra/ifiscaf-spoke/README.md"

echo "IFISCAF spoke Bicep and security contracts passed."
