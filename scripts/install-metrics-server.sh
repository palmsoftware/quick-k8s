#!/usr/bin/env bash
set -euo pipefail

METRICS_SERVER_VERSION="${1:-v0.8.1}"

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
if ! curl -sL "$MANIFEST_URL" | \
  sed '/args:/a\        - --kubelet-insecure-tls' | \
  kubectl apply -f -; then
  echo "Error: Failed to apply metrics-server manifest" >&2
  exit 1
fi

echo "Waiting for metrics-server to be ready..."
kubectl wait --namespace kube-system \
  --for=condition=ready pod \
  --selector=k8s-app=metrics-server \
  --timeout=300s || {
  echo "Warning: metrics-server may not be ready yet. Continuing..."
}

kubectl get pods -n kube-system -l k8s-app=metrics-server
echo "metrics-server $METRICS_SERVER_VERSION installed successfully!"
