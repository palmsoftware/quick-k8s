#!/usr/bin/env bash
set -euo pipefail

# Script to start Minikube cluster with configuration
# Usage: start-minikube.sh <node_image> <disable_cni> <driver> <api_port> <num_control_plane> <num_workers>
# Example: start-minikube.sh "kindest/node:v1.34.0@sha256:..." true docker 6443 1 1

NODE_IMAGE="${1:-}"
DISABLE_CNI="${2:-false}"
DRIVER="${3:-docker}"
API_PORT="${4:-6443}"
NUM_CONTROL_PLANE="${5:-1}"
NUM_WORKERS="${6:-0}"

if [ -z "$NODE_IMAGE" ]; then
  echo "Usage: $0 <node_image> [disable_cni] [driver] [api_port] [num_control_plane] [num_workers]"
  echo "Example: $0 'kindest/node:v1.34.0@sha256:...' true docker 6443 1 1"
  exit 1
fi

# Extract Kubernetes version from the defaultNodeImage
# Format: 'kindest/node:v1.33.1@sha256:...' -> 'v1.33.1'
K8S_VERSION=$(echo "$NODE_IMAGE" | sed -E 's/.*:([^@]+)@.*/\1/')
echo "Extracted Kubernetes version: $K8S_VERSION"

# Build minikube start command with appropriate flags
MINIKUBE_CMD="minikube start"
MINIKUBE_CMD="$MINIKUBE_CMD --driver=$DRIVER"

# Configure CNI and container runtime
# Note: containerd requires CNI in Minikube, so use docker runtime when CNI is disabled
if [ "$DISABLE_CNI" = "true" ]; then
  echo "⚠️  Minikube: Using docker runtime (containerd requires CNI)"
  MINIKUBE_CMD="$MINIKUBE_CMD --container-runtime=docker"
  MINIKUBE_CMD="$MINIKUBE_CMD --cni=false"
else
  MINIKUBE_CMD="$MINIKUBE_CMD --container-runtime=containerd"
fi

MINIKUBE_CMD="$MINIKUBE_CMD --kubernetes-version=$K8S_VERSION"

# Configure network settings
MINIKUBE_CMD="$MINIKUBE_CMD --apiserver-port=$API_PORT"

# Configure nodes
if [ "$NUM_WORKERS" -gt 0 ]; then
  TOTAL_NODES=$((NUM_CONTROL_PLANE + NUM_WORKERS))
  MINIKUBE_CMD="$MINIKUBE_CMD --nodes=$TOTAL_NODES"
fi

echo "Starting Minikube with command: $MINIKUBE_CMD"
eval "$MINIKUBE_CMD"

echo "✅ Minikube cluster started successfully"

