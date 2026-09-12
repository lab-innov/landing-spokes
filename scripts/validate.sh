#!/bin/sh
# Comprobaciones locales; no autentica ni despliega en Azure.
set -eu
cd "$(dirname "$0")/.."
BICEP_BIN=${BICEP_BIN:-$HOME/.azure/bin/bicep}
export DOTNET_BUNDLE_EXTRACT_BASE_DIR=${DOTNET_BUNDLE_EXTRACT_BASE_DIR:-/private/tmp/bicep-dotnet}
validation_dir=$(mktemp -d)
trap 'rm -rf "$validation_dir"' EXIT
"$BICEP_BIN" build infra/main.bicep --outfile "$validation_dir/main.json"
"$BICEP_BIN" lint infra/main.bicep
"$BICEP_BIN" build-params environments/dev.example.bicepparam --outfile "$validation_dir/example.json"
ANALISISDEC_ARM="$validation_dir/main.json" python3 -m unittest discover -s tests -v
if python3 scripts/check_parameters.py "$validation_dir/example.json" > "$validation_dir/expected-errors.txt"; then
  echo 'ERROR: se aceptaron marcadores del ejemplo.'; exit 1
fi
if [ "$#" -gt 0 ]; then
  python3 scripts/check_parameters.py "$1"
fi
