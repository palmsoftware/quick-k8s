#!/usr/bin/env bash
set -euo pipefail

CALICO_VERSION="${1:?Usage: $0 <calico-version>}"

# shellcheck source=diagnose-failure.sh
source "$(dirname "$0")/diagnose-failure.sh"
# shellcheck source=lib/retry.sh
source "$(dirname "$0")/lib/retry.sh"

echo "::group::Installing Calico CNI $CALICO_VERSION"
trap 'echo "::endgroup::"' EXIT

echo "Installing Calico CNI version $CALICO_VERSION..."

if ! command -v kubectl >/dev/null 2>&1; then
  echo "Error: kubectl is not installed." >&2
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
        echo "Warning: Some Calico CRDs failed validation (likely K8s version incompatibility) but core components installed successfully"
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
