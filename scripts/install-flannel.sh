#!/usr/bin/env bash
set -euo pipefail

FLANNEL_VERSION="${1:-v0.26.7}"
TIMEOUT="${COMPONENT_TIMEOUT:-300}"

# shellcheck source=diagnose-failure.sh
source "$(dirname "$0")/diagnose-failure.sh"

echo "::group::Installing Flannel CNI $FLANNEL_VERSION"
trap 'echo "::endgroup::"' EXIT

echo "Installing Flannel CNI version $FLANNEL_VERSION..."

if ! command -v kubectl >/dev/null 2>&1; then
  echo "Error: kubectl is not installed." >&2
  exit 1
fi

FLANNEL_URL="https://github.com/flannel-io/flannel/releases/download/${FLANNEL_VERSION}/kube-flannel.yml"

max_attempts=3
attempt=1
delay=5

while [ $attempt -le $max_attempts ]; do
  echo "Attempt $attempt/$max_attempts: Applying Flannel manifest..."
  apply_output=$(kubectl apply --timeout=5m -f "$FLANNEL_URL" 2>&1) && {
    echo "$apply_output"
    echo "Flannel manifest applied successfully"
    break
  }
  exit_code=$?
  echo "$apply_output"

  if [ $attempt -eq $max_attempts ]; then
    diagnose_failure "Flannel" "$apply_output"
    exit $exit_code
  fi

  echo "Retrying in $delay seconds..."
  sleep $delay
  delay=$((delay * 2))
  attempt=$((attempt + 1))
done

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
