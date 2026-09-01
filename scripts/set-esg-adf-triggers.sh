#!/usr/bin/env bash
set -euo pipefail

RESOURCE_GROUP="${1:-}"
FACTORY_NAME="${2:-}"
ACTION="${3:-}"

if [[ -z "${RESOURCE_GROUP}" || -z "${FACTORY_NAME}" || ( "${ACTION}" != "start" && "${ACTION}" != "stop" ) ]]; then
  echo "Usage: $0 <resource-group> <factory-name> <start|stop>" >&2
  exit 1
fi

trigger_names=(poc_esg_trigger_from_blob esg-trigger-monthly-report)
for trigger_name in "${trigger_names[@]}"; do
  if [[ "${ACTION}" == "start" ]]; then
    az datafactory trigger start --resource-group "${RESOURCE_GROUP}" --factory-name "${FACTORY_NAME}" --name "${trigger_name}"
  else
    az datafactory trigger stop --resource-group "${RESOURCE_GROUP}" --factory-name "${FACTORY_NAME}" --name "${trigger_name}"
  fi
done

az datafactory trigger list --resource-group "${RESOURCE_GROUP}" --factory-name "${FACTORY_NAME}" --query '[].{name:name,state:properties.runtimeState}' -o table
