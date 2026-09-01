#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
TEMPLATE_FILE="${REPO_ROOT}/infra/esg-spoke/main.bicep"

PARAM_FILE="${1:-}"
ACTION="${2:-what-if}"
DEPLOYMENT_NAME="${3:-esg-secure-spoke-$(date +%Y%m%d%H%M%S)}"
DEPLOYMENT_LOCATION="${AZURE_LOCATION:-eastus}"

if [[ -z "${PARAM_FILE}" || ! -f "${PARAM_FILE}" ]]; then
  echo "Usage: $0 <parameters.bicepparam> [create|what-if|validate] [deployment-name]" >&2
  exit 1
fi

"${SCRIPT_DIR}/preflight-esg-spoke.sh" "${PARAM_FILE}"

case "${ACTION}" in
  create)
    az deployment sub create --name "${DEPLOYMENT_NAME}" --location "${DEPLOYMENT_LOCATION}" --template-file "${TEMPLATE_FILE}" --parameters "${PARAM_FILE}"
    ;;
  what-if)
    az deployment sub what-if --name "${DEPLOYMENT_NAME}" --location "${DEPLOYMENT_LOCATION}" --template-file "${TEMPLATE_FILE}" --parameters "${PARAM_FILE}"
    ;;
  validate)
    az deployment sub validate --name "${DEPLOYMENT_NAME}" --location "${DEPLOYMENT_LOCATION}" --template-file "${TEMPLATE_FILE}" --parameters "${PARAM_FILE}"
    ;;
  *)
    echo "Unsupported action: ${ACTION}" >&2
    exit 1
    ;;
esac
