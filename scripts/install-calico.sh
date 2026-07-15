#!/usr/bin/env bash
set -euo pipefail

CALICO_VERSION="${1:?Usage: $0 <calico-version>}"

echo "::group::Installing Calico CNI $CALICO_VERSION"
trap 'echo "::endgroup::"' EXIT

echo "Installing Calico CNI version $CALICO_VERSION..."

if ! command -v kubectl >/dev/null 2>&1; then
  echo "Error: kubectl is not installed." >&2
  exit 1
fi

CALICO_URL="https://raw.githubusercontent.com/projectcalico/calico/$CALICO_VERSION/manifests/calico.yaml"

max_attempts=3
attempt=1
delay=5

while [ $attempt -le $max_attempts ]; do
  echo "Attempt $attempt/$max_attempts: Applying Calico manifest..."
  output=$(kubectl apply --timeout=5m -f "$CALICO_URL" 2>&1) && {
    echo "$output"
    echo "Calico CNI installed successfully"
    break
  }
  exit_code=$?
  echo "$output"

  # Calico v3.32+ includes CRDs using CEL functions (e.g. isCIDR) not available
  # in K8s < 1.31. The core CNI components still install correctly, so treat
  # CRD validation errors as non-fatal if the calico-node daemonset exists.
  if echo "$output" | grep -q "is invalid:.*compilation failed"; then
    if kubectl get daemonset calico-node -n kube-system &>/dev/null; then
      echo "Warning: Some Calico CRDs failed validation (likely K8s version incompatibility) but core components installed successfully"
      break
    fi
  fi

  if [ $attempt -eq $max_attempts ]; then
    echo "Calico installation failed after $max_attempts attempts"
    exit $exit_code
  fi

  echo "Retrying in $delay seconds..."
  sleep $delay
  delay=$((delay * 2))
  attempt=$((attempt + 1))
done
