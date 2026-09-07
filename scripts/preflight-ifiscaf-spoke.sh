#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
PARAM_FILE="${1:-}"
ACTION="${2:-what-if}"
[[ -f "${PARAM_FILE}" ]] || { echo "Indica un archivo .bicepparam válido." >&2; exit 1; }
case "${ACTION}" in create|validate|what-if) ;; *) echo "Acción inválida." >&2; exit 1;; esac
for dependency in az jq python3; do command -v "${dependency}" >/dev/null; done
resolved="$(az bicep build-params --file "${PARAM_FILE}" --stdout | python3 "${SCRIPT_DIR}/validate-inputs.py")"
region="$(jq -r '.location' <<<"${resolved}")"
az account show --query '{subscription:name,id:id,state:state}' -o table
"${REPO_ROOT}/tests/ifiscaf-spoke-contracts.sh"
for provider in Microsoft.CognitiveServices Microsoft.Databricks Microsoft.DataFactory Microsoft.DocumentDB Microsoft.EventGrid Microsoft.Insights Microsoft.Network Microsoft.Storage Microsoft.Web; do
  [[ "$(az provider show --namespace "${provider}" --query registrationState -o tsv)" == Registered ]] || { echo "Proveedor no registrado: ${provider}" >&2; exit 1; }
done
for key in hubVnetResourceId existingRouteTableResourceId existingLogAnalyticsWorkspaceResourceId sharedSyntheticStorageAccountResourceId; do
  az resource show --ids "$(jq -r --arg k "${key}" '.[$k]' <<<"${resolved}")" --query id -o tsv >/dev/null
done
catalog="$(az cognitiveservices model list --location "${region}" -o json)"
quota="$(az cognitiveservices usage list --location "${region}" -o json)" || { echo "No se pudo comprobar la cuota; reintenta antes de desplegar." >&2; exit 1; }
while IFS= read -r deployment; do
  model="$(jq -r '.model' <<<"${deployment}")"
  version="$(jq -r '.version' <<<"${deployment}")"
  sku="$(jq -r '.sku' <<<"${deployment}")"
  jq -e --arg m "${model}" --arg v "${version}" --arg s "${sku}" 'any(.[]; .model.name == $m and .model.version == $v and any(.model.skus[]?; .name == $s))' <<<"${catalog}" >/dev/null || { echo "Modelo/versión/SKU no disponible: ${model} ${version} ${sku}" >&2; exit 1; }
done < <(jq -c '.openAiModelDeployments[]' <<<"${resolved}")
while IFS= read -r request; do
  quota_name="$(jq -r '"OpenAI." + .sku + "." + .model' <<<"${request}")"
  capacity="$(jq '.capacity' <<<"${request}")"
  jq -e --arg n "${quota_name}" --argjson c "${capacity}" 'any(.[]; ((.name.value | ascii_downcase) == ($n | ascii_downcase)) and (.limit - .currentValue >= $c))' <<<"${quota}" >/dev/null || { echo "Cuota insuficiente o no verificable para ${quota_name}: ${capacity}." >&2; exit 1; }
done < <(jq -c '.openAiModelDeployments | group_by([.model,.sku])[] | {model:.[0].model,sku:.[0].sku,capacity:(map(.capacity)|add)}' <<<"${resolved}")
echo "Preflight completado. Confirma DNS, rutas, permisos efectivos y aprobaciones de plataforma con validate y what-if."
