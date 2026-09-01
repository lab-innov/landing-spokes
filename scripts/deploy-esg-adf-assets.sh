#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
TEMPLATE_FILE="${REPO_ROOT}/infra/esg-spoke/adf-assets.bicep"

RESOURCE_GROUP="${1:-}"
PARAM_FILE="${2:-}"
ACTION="${3:-what-if}"
DEPLOYMENT_NAME="${4:-esg-adf-assets-$(date +%Y%m%d%H%M%S)}"

if [[ -z "${RESOURCE_GROUP}" || -z "${PARAM_FILE}" || ! -f "${PARAM_FILE}" ]]; then
  echo "Usage: $0 <resource-group> <parameters.bicepparam> [create|what-if|validate] [deployment-name]" >&2
  exit 1
fi

az bicep build --file "${TEMPLATE_FILE}" --stdout >/dev/null

case "${ACTION}" in
  create)
    az deployment group create --resource-group "${RESOURCE_GROUP}" --name "${DEPLOYMENT_NAME}" --template-file "${TEMPLATE_FILE}" --parameters "${PARAM_FILE}"
    ;;
  what-if)
    az deployment group what-if --resource-group "${RESOURCE_GROUP}" --name "${DEPLOYMENT_NAME}" --template-file "${TEMPLATE_FILE}" --parameters "${PARAM_FILE}"
    ;;
  validate)
    az deployment group validate --resource-group "${RESOURCE_GROUP}" --name "${DEPLOYMENT_NAME}" --template-file "${TEMPLATE_FILE}" --parameters "${PARAM_FILE}"
    ;;
  *)
    echo "Unsupported action: ${ACTION}" >&2
    exit 1
    ;;
esac
