#!/usr/bin/env bash
# Compilación, linter, parámetros y contratos locales; no consulta Azure.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
ESG_TEMP="$(mktemp -d)"
trap 'rm -rf "$ESG_TEMP"' EXIT
bicep_cmd=(az bicep)
for entry in main adf-assets; do
  "${bicep_cmd[@]}" build --file "$REPO_ROOT/infra/esg-spoke/$entry.bicep" --outfile "$ESG_TEMP/$entry.json"
  "${bicep_cmd[@]}" lint --file "$REPO_ROOT/infra/esg-spoke/$entry.bicep"
done
for file in "$REPO_ROOT"/environments/esg-spoke/*.example.bicepparam; do
  "${bicep_cmd[@]}" build-params --file "$file" --outfile "$ESG_TEMP/$(basename "$file").json"
done
ESG_ARM="$ESG_TEMP/main.json" PYTHONDONTWRITEBYTECODE=1 python3 "$SCRIPT_DIR/esg_security.py" -v
if python3 "$REPO_ROOT/scripts/check-esg-parameters.py" "$ESG_TEMP/esg-spoke.example.bicepparam.json" >/dev/null; then
  echo 'Error: el ejemplo con marcadores no debe ser desplegable.' >&2; exit 1
fi
for file in "$REPO_ROOT"/scripts/*.sh; do bash -n "$file"; done
echo 'Compilación, linter y contratos ESG correctos. Pendiente validación Azure.'
