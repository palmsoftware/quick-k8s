#!/usr/bin/env bash
set -euo pipefail

ISTIO_VERSION="${1:-1.28.1}"
ISTIO_PROFILE="${2:-minimal}"

echo "Installing Istio version $ISTIO_VERSION with profile $ISTIO_PROFILE"

# Check for required commands
for cmd in curl kubectl tar; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Error: $cmd is not installed." >&2
    exit 1
  fi
done

# Determine architecture
ARCH=$(uname -m)
case $ARCH in
  x86_64)
    ARCH="amd64"
    ;;
  aarch64|arm64)
    ARCH="arm64"
    ;;
  *)
    echo "Error: Unsupported architecture: $ARCH" >&2
    exit 1
    ;;
esac

# Determine OS (Istio uses 'osx' for macOS, not 'darwin')
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
if [ "$OS" = "darwin" ]; then
  OS="osx"
fi

echo "Detected OS: $OS, Architecture: $ARCH"

# Download istioctl
# Istio naming convention: linux-{arch}, osx (universal), osx-arm64
if [ "$OS" = "osx" ] && [ "$ARCH" = "amd64" ]; then
  # macOS Intel uses universal 'osx' build (not osx-amd64)
  ISTIO_URL="https://github.com/istio/istio/releases/download/${ISTIO_VERSION}/istio-${ISTIO_VERSION}-osx.tar.gz"
else
  ISTIO_URL="https://github.com/istio/istio/releases/download/${ISTIO_VERSION}/istio-${ISTIO_VERSION}-${OS}-${ARCH}.tar.gz"
fi
echo "Downloading Istio from: $ISTIO_URL"

if ! curl -fSL "$ISTIO_URL" -o istio.tar.gz; then
  echo "Error: Failed to download Istio from $ISTIO_URL" >&2
  echo "This may indicate:" >&2
  echo "  1. Network connectivity issues" >&2
  echo "  2. Istio version $ISTIO_VERSION may not be available for $OS-$ARCH" >&2
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
istioctl install --set profile="$ISTIO_PROFILE" -y

# Wait for Istio pods to be ready
echo "Waiting for Istio control plane pods to be ready..."
kubectl wait --for=condition=ready pod \
  --all \
  --namespace=istio-system \
  --timeout=300s || {
    echo "Warning: Some Istio pods may not be ready yet. Continuing..."
  }

# Show Istio status
echo "Istio installation complete!"
istioctl version

# Clean up
echo "Cleaning up installation files..."
rm -rf istio.tar.gz "$ISTIO_DIR"

echo "Istio $ISTIO_VERSION with profile $ISTIO_PROFILE installed successfully!"

