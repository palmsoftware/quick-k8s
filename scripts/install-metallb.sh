#!/usr/bin/env bash
set -euo pipefail

METALLB_VERSION="${1:-v0.16.0}"
CLUSTER_PROVIDER="${2:-kind}"
TIMEOUT="${COMPONENT_TIMEOUT:-300}"
IP_FAMILY="${IP_FAMILY:-ipv4}"
SCRIPT_DIR="$(dirname "$0")"

# shellcheck source=diagnose-failure.sh
source "$(dirname "$0")/diagnose-failure.sh"
# shellcheck source=lib/retry.sh
source "$(dirname "$0")/lib/retry.sh"

echo "::group::Installing MetalLB $METALLB_VERSION"
trap 'echo "::endgroup::"' EXIT

echo "Installing MetalLB version $METALLB_VERSION"

# Verify required tools are available
if ! command -v kubectl >/dev/null 2>&1; then
  echo "::error::kubectl is not installed." >&2
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "::error::python3 is required to calculate MetalLB address pools." >&2
  exit 1
fi

if command -v docker >/dev/null 2>&1; then
  CONTAINER_RUNTIME="docker"
elif command -v podman >/dev/null 2>&1; then
  CONTAINER_RUNTIME="podman"
else
  echo "::error::neither docker nor podman is installed." >&2
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

SUBNETS=$($CONTAINER_RUNTIME network inspect "$NETWORK_NAME" -f '{{range .IPAM.Config}}{{.Subnet}} {{end}}' 2>/dev/null) || {
  echo "::warning::Could not detect container network subnets; using address pool defaults" >&2
  SUBNETS=""
}

POOL_ADDRESSES=$(python3 "$SCRIPT_DIR/metallb-address-pool.py" "$IP_FAMILY" "$SUBNETS") || {
  echo "::error::Could not calculate MetalLB address pools for IP family '$IP_FAMILY'" >&2
  exit 1
}
POOL_ADDRESS_YAML=$(printf '%s\n' "$POOL_ADDRESSES" | sed 's/^/    - /')

echo "Configuring MetalLB address pool for IP family '$IP_FAMILY':"
printf '%s\n' "$POOL_ADDRESSES"

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
${POOL_ADDRESS_YAML}
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
  echo "::error::Failed to configure MetalLB address pool after 5 attempts"
  exit 1
}

echo "MetalLB $METALLB_VERSION installed successfully!"
echo "LoadBalancer address pool:"
printf '%s\n' "$POOL_ADDRESSES"
