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
# Use a retry loop instead of a single kubectl wait because OLM catalog
# source pods can be recreated during startup, causing kubectl wait --all
# to fail on the deleted pod even when all current pods are ready.
olm_end_time=$((SECONDS + TIMEOUT))
olm_ready=false
while [ $SECONDS -lt $olm_end_time ]; do
  remaining=$((olm_end_time - SECONDS))
  if [ "$remaining" -le 0 ]; then
    break
  fi
  wait_timeout=$((remaining < 30 ? remaining : 30))
  if kubectl wait --for=condition=ready pod --all --namespace=olm --timeout="${wait_timeout}s" 2>/dev/null; then
    olm_ready=true
    break
  fi
  sleep 5
done
if [ "$olm_ready" != "true" ]; then
  dump_pod_status "olm" "OLM"
  diagnose_failure "OLM" "OLM pods not ready after ${TIMEOUT}s"
  exit 1
fi
echo "All OLM pods in namespace olm are ready"

pod_count=$(kubectl get pods --namespace=operators --no-headers 2>/dev/null | wc -l)
if [ "$pod_count" -gt 0 ]; then
  ops_end_time=$((SECONDS + TIMEOUT))
  ops_ready=false
  while [ $SECONDS -lt $ops_end_time ]; do
    remaining=$((ops_end_time - SECONDS))
    if [ "$remaining" -le 0 ]; then
      break
    fi
    wait_timeout=$((remaining < 30 ? remaining : 30))
    if kubectl wait --for=condition=ready pod --all --namespace=operators --timeout="${wait_timeout}s" 2>/dev/null; then
      ops_ready=true
      break
    fi
    sleep 5
  done
  if [ "$ops_ready" != "true" ]; then
    dump_pod_status "operators" "OLM operators"
    diagnose_failure "OLM" "OLM operator pods not ready after ${TIMEOUT}s"
    exit 1
  fi
  echo "All OLM pods in namespace operators are ready"
else
  echo "No pods in operators namespace (expected — pods appear when operators are installed)"
fi
