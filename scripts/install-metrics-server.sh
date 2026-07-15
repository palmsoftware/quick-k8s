#!/usr/bin/env bash
set -euo pipefail

METRICS_SERVER_VERSION="${1:-v0.8.1}"
TIMEOUT="${COMPONENT_TIMEOUT:-300}"

# shellcheck source=diagnose-failure.sh
source "$(dirname "$0")/diagnose-failure.sh"

echo "::group::Installing metrics-server $METRICS_SERVER_VERSION"
trap 'echo "::endgroup::"' EXIT

echo "Installing metrics-server version $METRICS_SERVER_VERSION"

# Verify required tools are available
for cmd in curl kubectl; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Error: $cmd is not installed." >&2
    exit 1
  fi
done

MANIFEST_URL="https://github.com/kubernetes-sigs/metrics-server/releases/download/${METRICS_SERVER_VERSION}/components.yaml"
echo "Downloading metrics-server manifest from: $MANIFEST_URL"

# Download and patch for local clusters (add --kubelet-insecure-tls)
# This is required for KinD/Minikube where kubelet uses self-signed certs
apply_output=$(curl -sL "$MANIFEST_URL" | \
  sed '/args:/a\        - --kubelet-insecure-tls' | \
  kubectl apply --timeout=5m -f - 2>&1) || {
  echo "$apply_output"
  diagnose_failure "metrics-server" "$apply_output"
  exit 1
}
echo "$apply_output"

echo "Waiting for metrics-server to be ready..."
wait_output=$(kubectl wait --namespace kube-system \
  --for=condition=ready pod \
  --selector=k8s-app=metrics-server \
  --timeout="${TIMEOUT}s" 2>&1) || {
  echo "$wait_output"
  dump_pod_status "kube-system" "metrics-server"
  diagnose_failure "metrics-server" "$wait_output"
  exit 1
}
echo "$wait_output"

kubectl get pods -n kube-system -l k8s-app=metrics-server
echo "metrics-server $METRICS_SERVER_VERSION installed successfully!"
