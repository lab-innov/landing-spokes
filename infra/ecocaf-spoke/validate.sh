#!/usr/bin/env bash
# Comprobación local: compilación, linter, ejemplo y pruebas.
set -euo pipefail
ECO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ECO_TEMP="$(mktemp -d)"
trap 'rm -rf "$ECO_TEMP"' EXIT
az bicep build --file "$ECO_ROOT/main.bicep" --outfile "$ECO_TEMP/main.json"
az bicep lint --file "$ECO_ROOT/main.bicep"
az bicep build-params --file "$ECO_ROOT/main.bicepparam" --outfile "$ECO_TEMP/example.json"
ECO_ARM="$ECO_TEMP/main.json" PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s "$ECO_ROOT/tests" -v
if python3 "$ECO_ROOT/check_parameters.py" "$ECO_TEMP/example.json" >/dev/null; then
  echo 'Error: el ejemplo con marcadores no debe superar la validación.' >&2; exit 1
fi
