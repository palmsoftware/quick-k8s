#!/usr/bin/env bash
set -euo pipefail

INGRESS_NGINX_VERSION="${1:-v1.14.3}"
CLUSTER_PROVIDER="${2:-kind}"

echo "Installing ingress-nginx version $INGRESS_NGINX_VERSION for $CLUSTER_PROVIDER"

# Verify required tools are available
for cmd in curl kubectl; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Error: $cmd is not installed." >&2
    exit 1
  fi
done

# Use provider-specific manifest for KinD, generic for others
if [ "$CLUSTER_PROVIDER" = "kind" ]; then
  MANIFEST_URL="https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-${INGRESS_NGINX_VERSION}/deploy/static/provider/kind/deploy.yaml"
else
  MANIFEST_URL="https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-${INGRESS_NGINX_VERSION}/deploy/static/provider/cloud/deploy.yaml"
fi

echo "Downloading ingress-nginx manifest from: $MANIFEST_URL"

if ! kubectl apply -f "$MANIFEST_URL"; then
  echo "Error: Failed to apply ingress-nginx manifest" >&2
  exit 1
fi

echo "Waiting for ingress-nginx controller to be ready..."
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=300s || {
  echo "Warning: ingress-nginx controller may not be ready yet. Continuing..."
}

kubectl get pods -n ingress-nginx
echo "ingress-nginx $INGRESS_NGINX_VERSION installed successfully!"
