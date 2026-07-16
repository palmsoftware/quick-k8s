#!/usr/bin/env bash
set -euo pipefail

CILIUM_VERSION="${1:-}"
TIMEOUT="${COMPONENT_TIMEOUT:-300}"

# shellcheck source=diagnose-failure.sh
source "$(dirname "$0")/diagnose-failure.sh"

echo "::group::Installing Cilium CNI"
trap 'echo "::endgroup::"' EXIT

# Verify required tools are available
for cmd in curl kubectl; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Error: $cmd is not installed." >&2
    exit 1
  fi
done

# Determine architecture
CLI_ARCH="amd64"
if [ "$(uname -m)" = "aarch64" ]; then
  CLI_ARCH="arm64"
fi

# Determine Cilium CLI version
if [ -n "$CILIUM_VERSION" ]; then
  CILIUM_CLI_VERSION="$CILIUM_VERSION"
  echo "Installing Cilium CLI version $CILIUM_CLI_VERSION..."
else
  echo "Fetching latest stable Cilium CLI version..."
  CILIUM_CLI_VERSION=$(curl -sS --retry 3 --retry-delay 5 https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)
  echo "Latest Cilium CLI version: $CILIUM_CLI_VERSION"
fi

# Download Cilium CLI with retry
max_attempts=3
attempt=1
delay=5

while [ $attempt -le $max_attempts ]; do
  echo "Attempt $attempt/$max_attempts: Downloading Cilium CLI..."
  DOWNLOAD_URL="https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-${CLI_ARCH}.tar.gz"
  CHECKSUM_URL="${DOWNLOAD_URL}.sha256sum"

  if curl -L --fail --retry 3 -o "/tmp/cilium-linux-${CLI_ARCH}.tar.gz" "$DOWNLOAD_URL" && \
     curl -L --fail --retry 3 -o "/tmp/cilium-linux-${CLI_ARCH}.tar.gz.sha256sum" "$CHECKSUM_URL"; then

    # Verify checksum
    if (cd /tmp && sha256sum --check "cilium-linux-${CLI_ARCH}.tar.gz.sha256sum"); then
      echo "Checksum verified successfully"
      sudo tar xzf "/tmp/cilium-linux-${CLI_ARCH}.tar.gz" -C /usr/local/bin
      rm -f "/tmp/cilium-linux-${CLI_ARCH}.tar.gz" "/tmp/cilium-linux-${CLI_ARCH}.tar.gz.sha256sum"
      break
    else
      echo "Checksum verification failed"
      rm -f "/tmp/cilium-linux-${CLI_ARCH}.tar.gz" "/tmp/cilium-linux-${CLI_ARCH}.tar.gz.sha256sum"
    fi
  fi

  if [ $attempt -eq $max_attempts ]; then
    echo "::error::Failed to download Cilium CLI after $max_attempts attempts"
    exit 1
  fi

  echo "Retrying in $delay seconds..."
  sleep $delay
  delay=$((delay * 2))
  attempt=$((attempt + 1))
done

# Verify Cilium CLI installation
if ! command -v cilium >/dev/null 2>&1; then
  echo "::error::Cilium CLI installation failed - binary not found"
  exit 1
fi
echo "Cilium CLI installed: $(cilium version --client 2>/dev/null || cilium version 2>&1 | head -1)"

# Install Cilium into the cluster
echo "Installing Cilium into the cluster..."
install_output=$(cilium install --wait=false 2>&1) || {
  echo "$install_output"
  diagnose_failure "Cilium" "$install_output"
  exit 1
}
echo "$install_output"

# Wait for Cilium to be ready
echo "Waiting for Cilium to be ready (timeout: ${TIMEOUT}s)..."
wait_output=$(cilium status --wait --wait-duration "${TIMEOUT}s" 2>&1) || {
  echo "$wait_output"
  dump_pod_status "kube-system" "Cilium"
  diagnose_failure "Cilium" "$wait_output"
  exit 1
}
echo "$wait_output"

kubectl get pods -n kube-system -l k8s-app=cilium
echo "Cilium CNI installed successfully!"
