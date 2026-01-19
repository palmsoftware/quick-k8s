#!/bin/bash

# Setup a local Docker registry accessible from the KinD/Minikube cluster
# Usage: setup-local-registry.sh <port> <cluster-provider>

set -e

REGISTRY_PORT="${1:-5001}"
CLUSTER_PROVIDER="${2:-kind}"
REGISTRY_NAME="quick-k8s-registry"

echo "Setting up local Docker registry on port ${REGISTRY_PORT}..."

# Check if registry already exists
if docker ps -a --format '{{.Names}}' | grep -q "^${REGISTRY_NAME}$"; then
  echo "Registry container '${REGISTRY_NAME}' already exists, removing..."
  docker rm -f "${REGISTRY_NAME}" >/dev/null 2>&1 || true
fi

# Start the registry container
echo "Starting local registry container..."
docker run -d \
  --restart=always \
  --name "${REGISTRY_NAME}" \
  -p "127.0.0.1:${REGISTRY_PORT}:5000" \
  registry:2

# Wait for registry to be ready
echo "Waiting for registry to be ready..."
max_attempts=30
attempt=1
while [ $attempt -le $max_attempts ]; do
  if curl -s "http://localhost:${REGISTRY_PORT}/v2/" >/dev/null 2>&1; then
    echo "Registry is ready!"
    break
  fi
  if [ $attempt -eq $max_attempts ]; then
    echo "ERROR: Registry failed to start after ${max_attempts} attempts"
    exit 1
  fi
  sleep 1
  attempt=$((attempt + 1))
done

if [ "${CLUSTER_PROVIDER}" = "kind" ]; then
  # Connect registry to the KinD network
  echo "Connecting registry to KinD network..."
  docker network connect "kind" "${REGISTRY_NAME}" 2>/dev/null || true

  # Document the local registry for KinD
  # See: https://kind.sigs.k8s.io/docs/user/local-registry/
  echo "Configuring KinD to use local registry..."

  cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: local-registry-hosting
  namespace: kube-public
data:
  localRegistryHosting.v1: |
    host: "localhost:${REGISTRY_PORT}"
    help: "https://kind.sigs.k8s.io/docs/user/local-registry/"
EOF
fi

if [ "${CLUSTER_PROVIDER}" = "minikube" ]; then
  echo "Configuring Minikube to use local registry..."

  # For Minikube, we need to configure the registry as an insecure registry
  # This is typically done at minikube start, but we can add the ConfigMap for documentation
  cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: local-registry-hosting
  namespace: kube-public
data:
  localRegistryHosting.v1: |
    host: "localhost:${REGISTRY_PORT}"
    help: "Local registry for quick-k8s"
EOF
fi

echo ""
echo "=============================================="
echo "Local Docker Registry Setup Complete!"
echo "=============================================="
echo ""
echo "Registry URL: localhost:${REGISTRY_PORT}"
echo ""
echo "Usage examples:"
echo "  # Tag and push an image:"
echo "  docker tag my-image:latest localhost:${REGISTRY_PORT}/my-image:latest"
echo "  docker push localhost:${REGISTRY_PORT}/my-image:latest"
echo ""
echo "  # Use in Kubernetes manifests:"
echo "  image: localhost:${REGISTRY_PORT}/my-image:latest"
echo ""
echo "=============================================="
