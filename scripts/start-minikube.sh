#!/usr/bin/env bash
set -euo pipefail

# Script to start Minikube cluster with configuration
# Usage: start-minikube.sh <node_image> <disable_cni> <driver> <api_port> <num_control_plane> <num_workers> [api_server_address] [cluster_name] [cpus] [memory]
# Example: start-minikube.sh "kindest/node:v1.34.0@sha256:..." true docker 6443 1 1 0.0.0.0 minikube 2 4096

NODE_IMAGE="${1:-}"
DISABLE_CNI="${2:-false}"
DRIVER="${3:-docker}"
API_PORT="${4:-6443}"
NUM_CONTROL_PLANE="${5:-1}"
NUM_WORKERS="${6:-0}"
API_SERVER_ADDRESS="${7:-0.0.0.0}"
CLUSTER_NAME="${8:-minikube}"
CLUSTER_CPUS="${9:-2}"
CLUSTER_MEMORY="${10:-}"

if [ -z "$NODE_IMAGE" ]; then
  echo "Usage: $0 <node_image> [disable_cni] [driver] [api_port] [num_control_plane] [num_workers]"
  echo "Example: $0 'kindest/node:v1.34.0@sha256:...' true docker 6443 1 1"
  exit 1
fi

echo "::group::Starting Minikube cluster"
trap 'echo "::endgroup::"' EXIT

# Extract Kubernetes version from the defaultNodeImage
# Format: 'kindest/node:v1.33.1@sha256:...' -> 'v1.33.1'
K8S_VERSION=$(echo "$NODE_IMAGE" | sed -E 's/.*:([^@]+)@.*/\1/')
echo "Extracted Kubernetes version: $K8S_VERSION"

# Validate that the extracted K8s version is supported by this Minikube binary
MINIKUBE_DEFAULT_K8S=$(minikube config defaults kubernetes-version 2>/dev/null | tr -d '[:space:]' || true)
if [ -n "$MINIKUBE_DEFAULT_K8S" ]; then
  HIGHEST=$(printf '%s\n%s\n' "$K8S_VERSION" "$MINIKUBE_DEFAULT_K8S" | sort -V | tail -n1)
  if [ "$HIGHEST" != "$MINIKUBE_DEFAULT_K8S" ]; then
    echo "::warning::Minikube does not support Kubernetes $K8S_VERSION (max supported: $MINIKUBE_DEFAULT_K8S). Falling back to $MINIKUBE_DEFAULT_K8S."
    K8S_VERSION="$MINIKUBE_DEFAULT_K8S"
  fi
else
  echo "::warning::Unable to query Minikube's supported Kubernetes versions. Proceeding with $K8S_VERSION."
fi

# Build minikube start command with appropriate flags
MINIKUBE_CMD=(minikube start)
MINIKUBE_CMD+=("--driver=$DRIVER")

# Configure CNI and container runtime
# Note: containerd requires CNI in Minikube, so use docker runtime when CNI is disabled
if [ "$DISABLE_CNI" = "true" ]; then
  echo "⚠️  Minikube: Using docker runtime (containerd requires CNI)"
  MINIKUBE_CMD+=(--container-runtime=docker)
  MINIKUBE_CMD+=(--cni=false)
else
  MINIKUBE_CMD+=(--container-runtime=containerd)
fi

MINIKUBE_CMD+=("--kubernetes-version=$K8S_VERSION")

# Configure network settings
MINIKUBE_CMD+=("--apiserver-port=$API_PORT")
if [ "$API_SERVER_ADDRESS" != "0.0.0.0" ]; then
  MINIKUBE_CMD+=("--apiserver-ips=$API_SERVER_ADDRESS")
fi

if [ "$CLUSTER_NAME" != "minikube" ]; then
  MINIKUBE_CMD+=("--profile=$CLUSTER_NAME")
fi

# Configure resource limits
MINIKUBE_CMD+=("--cpus=$CLUSTER_CPUS")
if [ -n "$CLUSTER_MEMORY" ]; then
  MINIKUBE_CMD+=("--memory=${CLUSTER_MEMORY}m")
fi

# Configure nodes
if [ "$NUM_WORKERS" -gt 0 ]; then
  TOTAL_NODES=$((NUM_CONTROL_PLANE + NUM_WORKERS))
  MINIKUBE_CMD+=("--nodes=$TOTAL_NODES")
fi

echo "Starting Minikube with command: ${MINIKUBE_CMD[*]}"
"${MINIKUBE_CMD[@]}"

echo "✅ Minikube cluster started successfully"
