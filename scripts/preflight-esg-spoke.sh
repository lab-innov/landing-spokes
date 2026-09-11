#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
PARAM_FILE="${1:-}"

if [[ -z "${PARAM_FILE}" || ! -f "${PARAM_FILE}" ]]; then
  echo "Usage: $0 <parameters.bicepparam>" >&2
  exit 1
fi

for command_name in az rg; do
  if ! command -v "${command_name}" >/dev/null 2>&1; then
    echo "Required command not found: ${command_name}" >&2
    exit 1
  fi
done

az account show --query '{subscription:name,id:id,state:state}' -o table
az bicep build --file "${REPO_ROOT}/infra/esg-spoke/main.bicep" --stdout >/dev/null
az bicep build-params --file "${PARAM_FILE}" --stdout >/dev/null
"${REPO_ROOT}/tests/esg-spoke-contracts.sh"

PARAM_TEMP="$(mktemp -d)"
trap 'rm -rf "$PARAM_TEMP"' EXIT
az bicep build-params --file "$PARAM_FILE" --outfile "$PARAM_TEMP/parameters.json"
python3 "$SCRIPT_DIR/check-esg-parameters.py" "$PARAM_TEMP/parameters.json"

required_providers=(Microsoft.Security Microsoft.App Microsoft.Bing Microsoft.CognitiveServices Microsoft.Databricks Microsoft.DataFactory Microsoft.DocumentDB Microsoft.Insights Microsoft.Network Microsoft.Storage Microsoft.Web)
for provider_namespace in "${required_providers[@]}"; do
  registration_state="$(az provider show --namespace "${provider_namespace}" --query registrationState -o tsv 2>/dev/null || true)"
  if [[ "${registration_state}" != "Registered" ]]; then
    echo "Provider is not registered: ${provider_namespace} (${registration_state:-unknown})" >&2
    exit 1
  fi
done

echo "ESG spoke preflight passed. Run validate and what-if before create."
