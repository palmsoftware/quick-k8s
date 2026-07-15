#!/usr/bin/env bash
set -euo pipefail

CERT_MANAGER_VERSION="${1:-v1.19.3}"
TIMEOUT="${COMPONENT_TIMEOUT:-300}"

# shellcheck source=diagnose-failure.sh
source "$(dirname "$0")/diagnose-failure.sh"

echo "Installing cert-manager version $CERT_MANAGER_VERSION"

# Verify required tools are available
for cmd in curl kubectl; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Error: $cmd is not installed." >&2
    exit 1
  fi
done

MANIFEST_URL="https://github.com/cert-manager/cert-manager/releases/download/${CERT_MANAGER_VERSION}/cert-manager.yaml"
echo "Downloading cert-manager manifest from: $MANIFEST_URL"

apply_output=$(kubectl apply --timeout=5m -f "$MANIFEST_URL" 2>&1) || {
  echo "$apply_output"
  diagnose_failure "cert-manager" "$apply_output"
  exit 1
}
echo "$apply_output"

echo "Waiting for cert-manager pods to be ready..."
wait_output=$(kubectl wait --for=condition=ready pod --all --namespace=cert-manager --timeout="${TIMEOUT}s" 2>&1) || {
  echo "$wait_output"
  dump_pod_status "cert-manager" "cert-manager"
  diagnose_failure "cert-manager" "$wait_output"
  exit 1
}
echo "$wait_output"

kubectl get pods -n cert-manager
echo "cert-manager $CERT_MANAGER_VERSION installed successfully!"
