#!/usr/bin/env bash
set -euo pipefail

METALLB_VERSION="${1:-v0.16.0}"
CLUSTER_PROVIDER="${2:-kind}"
TIMEOUT="${COMPONENT_TIMEOUT:-300}"

# shellcheck source=diagnose-failure.sh
source "$(dirname "$0")/diagnose-failure.sh"
# shellcheck source=lib/retry.sh
source "$(dirname "$0")/lib/retry.sh"

echo "::group::Installing MetalLB $METALLB_VERSION"
trap 'echo "::endgroup::"' EXIT

echo "Installing MetalLB version $METALLB_VERSION"

# Verify required tools are available
if ! command -v kubectl >/dev/null 2>&1; then
  echo "Error: kubectl is not installed." >&2
  exit 1
fi

if command -v docker >/dev/null 2>&1; then
  CONTAINER_RUNTIME="docker"
elif command -v podman >/dev/null 2>&1; then
  CONTAINER_RUNTIME="podman"
else
  echo "Error: neither docker nor podman is installed." >&2
  exit 1
fi

MANIFEST_URL="https://raw.githubusercontent.com/metallb/metallb/${METALLB_VERSION}/config/manifests/metallb-native.yaml"
echo "Downloading MetalLB manifest from: $MANIFEST_URL"

apply_output=$(kubectl apply --timeout=5m -f "$MANIFEST_URL" 2>&1) || {
  echo "$apply_output"
  diagnose_failure "MetalLB" "$apply_output"
  exit 1
}
echo "$apply_output"

echo "Waiting for MetalLB controller to be ready..."
wait_output=$(kubectl wait --namespace metallb-system \
  --for=condition=ready pod \
  --selector=app=metallb,component=controller \
  --timeout="${TIMEOUT}s" 2>&1) || {
  echo "$wait_output"
  dump_pod_status "metallb-system" "MetalLB"
  diagnose_failure "MetalLB" "$wait_output"
  exit 1
}
echo "$wait_output"

echo "Waiting for MetalLB speaker pods to be ready..."
wait_output=$(kubectl wait --namespace metallb-system \
  --for=condition=ready pod \
  --selector=app=metallb,component=speaker \
  --timeout="${TIMEOUT}s" 2>&1) || {
  echo "$wait_output"
  dump_pod_status "metallb-system" "MetalLB"
  diagnose_failure "MetalLB" "$wait_output"
  exit 1
}
echo "$wait_output"

kubectl get pods -n metallb-system

# Auto-detect the IP range from the container network used by the cluster
echo "Detecting container network subnet for address pool configuration..."

if [ "$CLUSTER_PROVIDER" = "kind" ]; then
  NETWORK_NAME="kind"
else
  NETWORK_NAME="bridge"
fi

# Use the first IPv4 subnet (skip any IPv6 entries in dual-stack networks)
SUBNET=$($CONTAINER_RUNTIME network inspect "$NETWORK_NAME" -f '{{range .IPAM.Config}}{{.Subnet}} {{end}}' 2>/dev/null \
  | tr ' ' '\n' | grep -E '^[0-9]+\.' | head -1) || {
  echo "Warning: Could not detect container network subnet, using default 172.18.255.200-172.18.255.250"
  SUBNET=""
}

if [ -n "$SUBNET" ]; then
  # Extract base network and construct a range in the .255.200-.255.250 space
  # For example, 172.18.0.0/16 -> 172.18.255.200-172.18.255.250
  #              192.168.49.0/24 -> 192.168.49.200-192.168.49.250
  IFS='/' read -r NETWORK_ADDR PREFIX_LEN <<< "$SUBNET"
  IFS='.' read -r O1 O2 O3 _O4 <<< "$NETWORK_ADDR"

  if [ "$PREFIX_LEN" -le 16 ]; then
    POOL_START="${O1}.${O2}.255.200"
    POOL_END="${O1}.${O2}.255.250"
  else
    POOL_START="${O1}.${O2}.${O3}.200"
    POOL_END="${O1}.${O2}.${O3}.250"
  fi
else
  POOL_START="172.18.255.200"
  POOL_END="172.18.255.250"
fi

echo "Configuring MetalLB address pool: ${POOL_START}-${POOL_END}"

# Webhook may not be ready immediately after pods report Ready
apply_metallb_pool() {
  echo "Applying MetalLB address pool configuration..."
  cat <<EOF | kubectl apply -f - 2>/dev/null
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: quick-k8s-pool
  namespace: metallb-system
spec:
  addresses:
    - ${POOL_START}-${POOL_END}
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: quick-k8s-l2
  namespace: metallb-system
spec:
  ipAddressPools:
    - quick-k8s-pool
EOF
}

retry_with_backoff 5 2 apply_metallb_pool || {
  echo "Failed to configure MetalLB address pool after 5 attempts"
  exit 1
}

echo "MetalLB $METALLB_VERSION installed successfully!"
echo "LoadBalancer IP range: ${POOL_START}-${POOL_END}"
