#!/usr/bin/env bash
set -euo pipefail

CALICO_VERSION="${1:?Usage: $0 <calico-version>}"
TIMEOUT="${COMPONENT_TIMEOUT:-300}"
IP_FAMILY="${IP_FAMILY:-ipv4}"

# shellcheck source=diagnose-failure.sh
source "$(dirname "$0")/diagnose-failure.sh"
# shellcheck source=lib/retry.sh
source "$(dirname "$0")/lib/retry.sh"

echo "::group::Installing Calico CNI $CALICO_VERSION"
trap 'echo "::endgroup::"' EXIT

echo "Installing Calico CNI version $CALICO_VERSION..."

if ! command -v kubectl >/dev/null 2>&1; then
  echo "::error::kubectl is not installed." >&2
  exit 1
fi

CALICO_URL="https://raw.githubusercontent.com/projectcalico/calico/$CALICO_VERSION/manifests/calico.yaml"

_last_apply_output=""
apply_calico_manifest() {
  echo "Applying Calico manifest..."
  _last_apply_output=$(kubectl apply --timeout=5m -f "$CALICO_URL" 2>&1) || {
    echo "$_last_apply_output"

    # Calico v3.32+ includes CRDs using CEL functions (e.g. isCIDR) not available
    # in K8s < 1.31. The core CNI components still install correctly, so treat
    # CRD validation errors as non-fatal if the calico-node daemonset exists.
    if echo "$_last_apply_output" | grep -q "is invalid:.*compilation failed"; then
      if kubectl get daemonset calico-node -n kube-system &>/dev/null; then
        echo "::warning::Some Calico CRDs failed validation (likely K8s version incompatibility) but core components installed successfully" >&2
        return 0
      fi
    fi

    return 1
  }
  echo "$_last_apply_output"
  echo "Calico CNI installed successfully"
}

retry_with_backoff 3 5 apply_calico_manifest || {
  diagnose_failure "Calico" "$_last_apply_output"
  exit 1
}

if [ "$IP_FAMILY" != "ipv4" ]; then
  CALICO_ENVS=(IP6=autodetect FELIX_IPV6SUPPORT=true)
  if [ "$IP_FAMILY" = "ipv6" ]; then
    echo "Configuring Calico for IPv6-only networking..."
    CALICO_ENVS+=(CALICO_IPV4POOL_CIDR- CALICO_IPV4POOL_IPIP- IP=none)
  else
    echo "Configuring Calico for dual-stack networking..."
  fi
  kubectl set env daemonset/calico-node -n kube-system "${CALICO_ENVS[@]}"

  if [ "$IP_FAMILY" = "ipv6" ]; then
    echo "Removing default IPv4 pool (incompatible with IPv6-only)..."
    kubectl delete ippools default-ipv4-ippool --ignore-not-found --timeout=30s
  fi

  echo "Waiting for calico-node rollout..."
  wait_output=$(kubectl rollout status daemonset/calico-node -n kube-system --timeout="${TIMEOUT}s" 2>&1) || {
    echo "$wait_output"
    dump_pod_status "kube-system" "Calico"
    diagnose_failure "Calico" "$wait_output"
    exit 1
  }
  echo "$wait_output"
fi

echo "Waiting for calico-node pods to be ready..."
wait_for_pods_ready "kube-system" "Calico" "$TIMEOUT" --selector=k8s-app=calico-node || exit 1

if [ "$IP_FAMILY" != "ipv4" ]; then
  echo "Restarting calico-kube-controllers to acquire IPv6 pod IP..."
  kubectl delete pods -n kube-system -l k8s-app=calico-kube-controllers --wait=false
  echo "Restarting CoreDNS pods to acquire IPv6 pod IPs..."
  kubectl delete pods -n kube-system -l k8s-app=kube-dns --wait=false
fi

echo "Waiting for calico-kube-controllers to be ready..."
wait_output=$(kubectl rollout status deployment/calico-kube-controllers \
  -n kube-system --timeout="${TIMEOUT}s" 2>&1) || {
  echo "$wait_output"
  dump_pod_status "kube-system" "Calico"
  diagnose_failure "Calico" "$wait_output"
  exit 1
}
echo "$wait_output"

kubectl get pods -n kube-system -l k8s-app=calico-node
echo "Calico CNI $CALICO_VERSION is ready"
