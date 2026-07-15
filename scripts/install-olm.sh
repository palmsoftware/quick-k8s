#!/usr/bin/env bash
set -euo pipefail

OLM_VERSION="v0.45.0"
TIMEOUT="${COMPONENT_TIMEOUT:-300}"

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
  echo "Error: Failed to download OLM install script for version $OLM_VERSION" >&2
  exit 1
fi

chmod +x install.sh
./install.sh "$OLM_VERSION"
rm install.sh

echo "Waiting for OLM pods to be ready..."
kubectl wait --for=condition=ready pod --all --namespace=olm --timeout="${TIMEOUT}s" || {
  echo "Warning: Some OLM pods may not be ready yet. Continuing..."
}
kubectl wait --for=condition=ready pod --all --namespace=operators --timeout="${TIMEOUT}s" || {
  echo "Warning: Some operator pods may not be ready yet. Continuing..."
}
