#!/usr/bin/env bash
set -euo pipefail

ISTIO_VERSION="${1:-1.28.1}"
ISTIO_PROFILE="${2:-minimal}"
TIMEOUT="${COMPONENT_TIMEOUT:-300}"

# shellcheck source=diagnose-failure.sh
source "$(dirname "$0")/diagnose-failure.sh"

echo "::group::Installing Istio $ISTIO_VERSION"
trap 'echo "::endgroup::"' EXIT

echo "Installing Istio version $ISTIO_VERSION with profile $ISTIO_PROFILE"

# Check for required commands
for cmd in curl kubectl tar; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Error: $cmd is not installed." >&2
    exit 1
  fi
done

# shellcheck source=map-platform.sh
source "$(dirname "$0")/map-platform.sh"
# shellcheck source=verify-checksum.sh
source "$(dirname "$0")/verify-checksum.sh"
ARCH=$(map_arch "$(uname -m)")
OS=$(map_os "$(uname -s)")

echo "Detected OS: $OS, Architecture: $ARCH"

ISTIO_URL="https://github.com/istio/istio/releases/download/${ISTIO_VERSION}/istio-${ISTIO_VERSION}-${OS}-${ARCH}.tar.gz"
echo "Downloading Istio from: $ISTIO_URL"

if ! curl -fSL --retry 3 --retry-delay 5 --retry-all-errors "$ISTIO_URL" -o istio.tar.gz; then
  echo "::error::Failed to download Istio from $ISTIO_URL after multiple attempts. Check network connectivity or verify Istio version $ISTIO_VERSION is available for $OS-$ARCH."
  rm -f istio.tar.gz
  exit 1
fi
echo "Istio download succeeded"

# Verify SHA256 checksum
ISTIO_TARBALL="istio-${ISTIO_VERSION}-${OS}-${ARCH}.tar.gz"
CHECKSUM_URL="https://github.com/istio/istio/releases/download/${ISTIO_VERSION}/${ISTIO_TARBALL}.sha256"
if ! download_and_verify_checksum istio.tar.gz "$CHECKSUM_URL"; then
  echo "::error::Istio tarball checksum verification failed - the download may be corrupted or tampered with"
  rm -f istio.tar.gz
  exit 1
fi

# Extract istioctl
echo "Extracting istioctl..."
tar -xzf istio.tar.gz
ISTIO_DIR="istio-${ISTIO_VERSION}"

# Move istioctl to /usr/local/bin
if [ -f "$ISTIO_DIR/bin/istioctl" ]; then
  sudo mv "$ISTIO_DIR/bin/istioctl" /usr/local/bin/istioctl
  sudo chmod +x /usr/local/bin/istioctl
  echo "istioctl installed successfully"
else
  echo "Error: istioctl binary not found in extracted archive" >&2
  exit 1
fi

# Verify installation
if ! command -v istioctl >/dev/null 2>&1; then
  echo "Error: istioctl installation failed" >&2
  exit 1
fi

echo "istioctl version:"
istioctl version --remote=false

# Install Istio using the specified profile
echo "Installing Istio with profile: $ISTIO_PROFILE"
install_output=$(istioctl install --set profile="$ISTIO_PROFILE" -y 2>&1) || {
  echo "$install_output"
  diagnose_failure "Istio" "$install_output"
  exit 1
}
echo "$install_output"

# Wait for Istio pods to be ready
echo "Waiting for Istio control plane pods to be ready..."
wait_output=$(kubectl wait --for=condition=ready pod \
  --all \
  --namespace=istio-system \
  --timeout="${TIMEOUT}s" 2>&1) || {
  echo "$wait_output"
  dump_pod_status "istio-system" "Istio"
  diagnose_failure "Istio" "$wait_output"
  exit 1
}
echo "$wait_output"

# Show Istio status
echo "Istio installation complete!"
istioctl version

# Clean up
echo "Cleaning up installation files..."
rm -rf istio.tar.gz "$ISTIO_DIR"

echo "Istio $ISTIO_VERSION with profile $ISTIO_PROFILE installed successfully!"
