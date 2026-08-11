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
MANIFEST_FILE=$(mktemp /tmp/calico-XXXXXX.yaml)
trap 'rm -f "$MANIFEST_FILE"; echo "::endgroup::"' EXIT

echo "Downloading Calico manifest..."
curl -fsSL "$CALICO_URL" -o "$MANIFEST_FILE"

if [ "$IP_FAMILY" != "ipv4" ]; then
  # Detect the cluster's IPv6 pod CIDR for the Calico IPv6 pool.
  ALL_CIDRS=$(kubectl get cm -n kube-system kubeadm-config -o yaml 2>/dev/null \
    | grep podSubnet | awk '{print $2}' | tr ',' '\n' || true)
  IPV6_POD_CIDR=""
  for cidr in $ALL_CIDRS; do
    if [[ "$cidr" == *:* ]]; then
      IPV6_POD_CIDR="$cidr"
      break
    fi
  done
  if [ -z "$IPV6_POD_CIDR" ]; then
    IPV6_POD_CIDR="fd00:10:244::/56"
    echo "Could not detect IPv6 pod CIDR, using default: $IPV6_POD_CIDR"
  else
    echo "Detected IPv6 pod CIDR: $IPV6_POD_CIDR"
  fi

  # Enable IPv6 in the manifest before applying
  sed -i 's/value: "false"  # felix ipv6/value: "true"/' "$MANIFEST_FILE"
  sed -i '/name: FELIX_IPV6SUPPORT/{n;s/value: "false"/value: "true"/}' "$MANIFEST_FILE"

  if [ "$IP_FAMILY" = "ipv6" ]; then
    echo "Configuring Calico manifest for IPv6-only networking..."
    # Disable IPv4: change IP=autodetect to IP=none
    sed -i '/name: IP$/{n;s/value: "autodetect"/value: "none"/}' "$MANIFEST_FILE"
    # Disable IPIP (IPv4 overlay)
    sed -i '/name: CALICO_IPV4POOL_IPIP/{n;s/value: "Always"/value: "Never"/}' "$MANIFEST_FILE"
  else
    echo "Configuring Calico manifest for dual-stack networking..."
  fi

  # Add IPv6 env vars after the IP line.
  # CALICO_ROUTER_ID=hash is required for IPv6-only because BIRD defaults to
  # using the node's IPv4 address as router ID, which doesn't exist when IP=none.
  sed -i "/- name: IP$/,/value:/{
    /value:/a\\
            - name: IP6\\
              value: \"autodetect\"\\
            - name: CALICO_IPV6POOL_CIDR\\
              value: \"${IPV6_POD_CIDR}\"\\
            - name: CALICO_ROUTER_ID\\
              value: \"hash\"
  }" "$MANIFEST_FILE"

  # Note: CALICO_IPV4POOL_CIDR is intentionally left commented out (unset) in the
  # manifest. calico-node will auto-create a default IPv4 pool; for IPv6-only mode,
  # we delete it after calico-node is ready (see below).
fi

_last_apply_output=""
apply_calico_manifest() {
  echo "Applying Calico manifest..."
  _last_apply_output=$(kubectl apply --timeout=5m -f "$MANIFEST_FILE" 2>&1) || {
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

echo "Waiting for calico-node pods to be ready..."
wait_for_pods_ready "kube-system" "Calico" "$TIMEOUT" --selector=k8s-app=calico-node || exit 1

if [ "$IP_FAMILY" = "ipv6" ]; then
  echo "Removing default IPv4 pool (incompatible with IPv6-only)..."
  kubectl delete ippools default-ipv4-ippool --ignore-not-found --timeout=30s
  echo "Restarting pods to acquire IPv6 IPs..."
  kubectl delete pods -n kube-system -l k8s-app=calico-kube-controllers --wait=false
  kubectl delete pods -n kube-system -l k8s-app=kube-dns --wait=false
elif [ "$IP_FAMILY" = "dual" ]; then
  echo "Restarting CoreDNS pods to acquire dual-stack IPs..."
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
