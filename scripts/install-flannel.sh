#!/usr/bin/env bash
set -euo pipefail

FLANNEL_VERSION="${1:-v0.28.7}"
TIMEOUT="${COMPONENT_TIMEOUT:-300}"

# shellcheck source=diagnose-failure.sh
source "$(dirname "$0")/diagnose-failure.sh"
# shellcheck source=lib/retry.sh
source "$(dirname "$0")/lib/retry.sh"

echo "::group::Installing Flannel CNI $FLANNEL_VERSION"
trap 'echo "::endgroup::"' EXIT

echo "Installing Flannel CNI version $FLANNEL_VERSION..."

if ! command -v kubectl >/dev/null 2>&1; then
  echo "Error: kubectl is not installed." >&2
  exit 1
fi

FLANNEL_URL="https://github.com/flannel-io/flannel/releases/download/${FLANNEL_VERSION}/kube-flannel.yml"

_last_apply_output=""
apply_flannel_manifest() {
  echo "Applying Flannel manifest..."
  _last_apply_output=$(kubectl apply --timeout=5m -f "$FLANNEL_URL" 2>&1)
  local rc=$?
  echo "$_last_apply_output"
  return $rc
}

retry_with_backoff 3 5 apply_flannel_manifest || {
  diagnose_failure "Flannel" "$_last_apply_output"
  exit 1
}
echo "Flannel manifest applied successfully"

echo "Waiting for Flannel pods to be ready (timeout: ${TIMEOUT}s)..."
wait_output=$(kubectl wait --for=condition=ready pod -l app=flannel -n kube-flannel --timeout="${TIMEOUT}s" 2>&1) || {
  echo "$wait_output"
  dump_pod_status "kube-flannel" "Flannel"
  diagnose_failure "Flannel" "$wait_output"
  exit 1
}
echo "$wait_output"

kubectl get pods -n kube-flannel
echo "Flannel CNI $FLANNEL_VERSION installed successfully!"
