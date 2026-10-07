#!/usr/bin/env bash

# Setup a local Docker registry accessible from the KinD/Minikube cluster
# Usage: setup-local-registry.sh <port> <cluster-provider> [cluster-name]

set -euo pipefail

REGISTRY_PORT="${1:-5001}"
CLUSTER_PROVIDER="${2:-kind}"
CLUSTER_NAME="${3:-kind}"
REGISTRY_NAME="quick-k8s-registry"

echo "::group::Setting up local Docker registry on port ${REGISTRY_PORT}"
trap 'echo "::endgroup::"' EXIT

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
    echo "::error::Registry failed to start after ${max_attempts} attempts"
    exit 1
  fi
  sleep 1
  attempt=$((attempt + 1))
done

# Provider-specific network configuration
if [ "${CLUSTER_PROVIDER}" = "kind" ]; then
  echo "Connecting registry to the KinD network..."
  docker network connect kind "${REGISTRY_NAME}" 2>/dev/null || true

  echo "Configuring KinD nodes to use the local registry..."
  registry_dir="/etc/containerd/certs.d/localhost:${REGISTRY_PORT}"
  if ! kind_nodes=$(kind get nodes --name "${CLUSTER_NAME}"); then
    echo "::error::Failed to list KinD nodes for cluster '${CLUSTER_NAME}'"
    exit 1
  fi
  if [ -z "${kind_nodes}" ]; then
    echo "::error::No KinD nodes found for cluster '${CLUSTER_NAME}'"
    exit 1
  fi
  while IFS= read -r node; do
    [ -z "${node}" ] && continue
    docker exec "${node}" mkdir -p "${registry_dir}"
    cat <<EOF | docker exec -i "${node}" cp /dev/stdin "${registry_dir}/hosts.toml"
[host."http://${REGISTRY_NAME}:5000"]
EOF
  done <<< "${kind_nodes}"
fi

# Create ConfigMap for registry discoverability (all providers)
echo "Configuring ${CLUSTER_PROVIDER} to use local registry..."
cat <<EOF | kubectl apply --timeout=5m -f -
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
