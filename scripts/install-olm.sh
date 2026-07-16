#!/usr/bin/env bash
set -euo pipefail

OLM_VERSION="${1:-v0.45.0}"
TIMEOUT="${COMPONENT_TIMEOUT:-300}"

# shellcheck source=diagnose-failure.sh
source "$(dirname "$0")/diagnose-failure.sh"

echo "::group::Installing OLM $OLM_VERSION"
trap 'echo "::endgroup::"' EXIT

echo "Installing OLM version $OLM_VERSION"

for cmd in curl kubectl; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Error: $cmd is not installed." >&2
    exit 1
  fi
done

if ! curl -fSL --retry 3 --retry-delay 5 --retry-all-errors \
  "https://github.com/operator-framework/operator-lifecycle-manager/releases/download/$OLM_VERSION/install.sh" \
  -o install.sh; then
  echo "::error::Failed to download OLM install script for version $OLM_VERSION. Check network connectivity or verify the OLM version exists."
  exit 1
fi

echo "::warning::Checksum verification skipped for OLM install script - no checksum published for install.sh"

chmod +x install.sh
install_output=$(./install.sh "$OLM_VERSION" 2>&1) || {
  echo "$install_output"
  diagnose_failure "OLM" "$install_output"
  rm -f install.sh
  exit 1
}
echo "$install_output"
rm -f install.sh

echo "Waiting for OLM pods to be ready..."
wait_output=$(kubectl wait --for=condition=ready pod --all --namespace=olm --timeout="${TIMEOUT}s" 2>&1) || {
  echo "$wait_output"
  dump_pod_status "olm" "OLM"
  diagnose_failure "OLM" "$wait_output"
  exit 1
}
echo "$wait_output"

wait_output=$(kubectl wait --for=condition=ready pod --all --namespace=operators --timeout="${TIMEOUT}s" 2>&1) || {
  echo "$wait_output"
  dump_pod_status "operators" "OLM operators"
  diagnose_failure "OLM" "$wait_output"
  exit 1
}
echo "$wait_output"
