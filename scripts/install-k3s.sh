#!/usr/bin/env bash
set -euo pipefail

# Usage: install-k3s.sh <version> <os> <arch>

VERSION="${1:-}"
OS="${2:-}"
ARCH="${3:-}"

if [ -z "$VERSION" ] || [ -z "$OS" ] || [ -z "$ARCH" ]; then
  echo "Usage: $0 <version> <os> <arch>"
  echo "Example: $0 v1.35.3+k3s1 linux amd64"
  exit 1
fi

OS=$(echo "$OS" | tr '[:upper:]' '[:lower:]')
ARCH=$(echo "$ARCH" | tr '[:upper:]' '[:lower:]')

if [ "$OS" != "linux" ]; then
  echo "❌ k3s is only supported on Linux (got: $OS)"
  echo "   Use 'kind' or 'minikube' for macOS"
  exit 1
fi

if [ "$ARCH" = "x64" ]; then
  ARCH="amd64"
fi

# k3s binary is 'k3s' for amd64, 'k3s-arm64' for arm64
BINARY_NAME="k3s"
if [ "$ARCH" = "arm64" ]; then
  BINARY_NAME="k3s-arm64"
fi

echo "Installing k3s ${VERSION} for linux/${ARCH}..."

if [ -f /tmp/k3s-binary ]; then
  echo "✅ Using cached k3s binary"
  sudo cp /tmp/k3s-binary /usr/local/bin/k3s
  sudo chmod +x /usr/local/bin/k3s
  exit 0
fi

# + must be URL-encoded as %2B in GitHub releases URLs
ENCODED_VERSION="${VERSION//+/%2B}"

DOWNLOAD_URL="https://github.com/k3s-io/k3s/releases/download/${ENCODED_VERSION}/${BINARY_NAME}"

echo "Downloading k3s ${VERSION} for linux/${ARCH}..."
echo "📥 Attempting download from: ${DOWNLOAD_URL}"

if ! curl -fsSL -o k3s "${DOWNLOAD_URL}"; then
  echo "❌ Failed to download k3s binary"
  echo ""
  echo "Attempted URL: ${DOWNLOAD_URL}"
  echo ""
  echo "This may be due to:"
  echo "  1. Network connectivity issues"
  echo "  2. GitHub releases outage"
  echo "  3. Invalid version: ${VERSION}"
  echo "  4. Unsupported architecture: ${ARCH}"
  echo ""
  echo "💡 Tip: Try re-running the workflow later"
  echo "        The binary will be cached for future runs once successfully downloaded"
  exit 1
fi

if file k3s | grep -q "HTML"; then
  echo "❌ Downloaded file is HTML, not a binary"
  echo "   This usually means the version or URL is incorrect"
  rm -f k3s
  exit 1
fi

echo "✅ Successfully downloaded k3s binary"

chmod +x k3s
cp k3s /tmp/k3s-binary
sudo mv k3s /usr/local/bin/

echo "✅ k3s ${VERSION} installed successfully"
