#!/usr/bin/env bash
# Compilación y contratos locales; no consulta ni modifica Azure.
set -euo pipefail
cd "$(dirname "$0")/.."
foundry_temp=$(mktemp -d)
trap 'rm -rf "$foundry_temp"' EXIT
export DOTNET_BUNDLE_EXTRACT_BASE_DIR=${DOTNET_BUNDLE_EXTRACT_BASE_DIR:-/private/tmp/bicep-dotnet}
BICEP_BIN=${BICEP_BIN:-$HOME/.azure/bin/bicep}
"$BICEP_BIN" build infra/main.bicep --outfile "$foundry_temp/main.json"
"$BICEP_BIN" lint infra/main.bicep
ARM_TEMPLATE="$foundry_temp/main.json" PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests -v
if python3 scripts/check_parameters.py environments/main.parameters.example.json > "$foundry_temp/expected-errors.txt"; then
  echo 'Error: el ejemplo con marcadores no debe aceptarse.'; exit 1
fi
