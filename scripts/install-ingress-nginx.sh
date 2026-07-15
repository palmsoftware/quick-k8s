#!/usr/bin/env bash
set -euo pipefail

INGRESS_NGINX_VERSION="${1:-v1.14.3}"
CLUSTER_PROVIDER="${2:-kind}"
TIMEOUT="${COMPONENT_TIMEOUT:-300}"

# shellcheck source=diagnose-failure.sh
source "$(dirname "$0")/diagnose-failure.sh"

echo "Installing ingress-nginx version $INGRESS_NGINX_VERSION for $CLUSTER_PROVIDER"

# Verify required tools are available
for cmd in curl kubectl; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Error: $cmd is not installed." >&2
    exit 1
  fi
done

# Use provider-specific manifest
if [ "$CLUSTER_PROVIDER" = "kind" ]; then
  MANIFEST_URL="https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-${INGRESS_NGINX_VERSION}/deploy/static/provider/kind/deploy.yaml"
elif [ "$CLUSTER_PROVIDER" = "minikube" ]; then
  MANIFEST_URL="https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-${INGRESS_NGINX_VERSION}/deploy/static/provider/baremetal/deploy.yaml"
else
  MANIFEST_URL="https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-${INGRESS_NGINX_VERSION}/deploy/static/provider/cloud/deploy.yaml"
fi

echo "Downloading ingress-nginx manifest from: $MANIFEST_URL"

apply_output=$(kubectl apply --timeout=5m -f "$MANIFEST_URL" 2>&1) || {
  echo "$apply_output"
  diagnose_failure "ingress-nginx" "$apply_output"
  exit 1
}
echo "$apply_output"

echo "Waiting for ingress-nginx controller to be ready..."
wait_output=$(kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout="${TIMEOUT}s" 2>&1) || {
  echo "$wait_output"
  dump_pod_status "ingress-nginx" "ingress-nginx"
  diagnose_failure "ingress-nginx" "$wait_output"
  exit 1
}
echo "$wait_output"

kubectl get pods -n ingress-nginx
echo "ingress-nginx $INGRESS_NGINX_VERSION installed successfully!"
