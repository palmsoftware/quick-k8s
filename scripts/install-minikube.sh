#!/usr/bin/env bash
set -euo pipefail

# Script to install Minikube binary with caching and fallback support
# Usage: install-minikube.sh <version> <os> <arch>
# Example: install-minikube.sh v1.37.0 linux amd64

VERSION="${1:-}"
OS="${2:-}"
ARCH="${3:-}"

if [ -z "$VERSION" ] || [ -z "$OS" ] || [ -z "$ARCH" ]; then
  echo "Usage: $0 <version> <os> <arch>"
  echo "Example: $0 v1.37.0 linux amd64"
  exit 1
fi

echo "::group::Installing Minikube $VERSION"
trap 'echo "::endgroup::"' EXIT

# shellcheck source=map-platform.sh
source "$(dirname "$0")/map-platform.sh"
# shellcheck source=verify-checksum.sh
source "$(dirname "$0")/verify-checksum.sh"
OS=$(map_os "$OS")
ARCH=$(map_arch "$ARCH")

# Determine the platform string for Minikube
PLATFORM="${OS}-${ARCH}"

echo "Installing Minikube ${VERSION} for ${PLATFORM}..."

# Check if binary is already cached
if [ -f /tmp/minikube-binary ]; then
  echo "✅ Using cached Minikube binary"
  sudo cp /tmp/minikube-binary /usr/local/bin/minikube
  sudo chmod +x /usr/local/bin/minikube
  exit 0
fi

# Download the binary with fallback
echo "Downloading Minikube ${VERSION} for ${PLATFORM}..."

# Primary URL
PRIMARY_URL="https://github.com/kubernetes/minikube/releases/download/${VERSION}/minikube-${PLATFORM}"
FALLBACK_URL="https://storage.googleapis.com/minikube/releases/${VERSION}/minikube-${PLATFORM}"

echo "📥 Attempting download from: ${PRIMARY_URL}"

# Try primary source
if curl -fsSL -o minikube "${PRIMARY_URL}"; then
  echo "✅ Downloaded from GitHub releases"
# Try Google Cloud Storage as fallback
else
  echo "⚠️  Primary URL failed, trying fallback: ${FALLBACK_URL}"
  if curl -fsSL -o minikube "${FALLBACK_URL}"; then
    echo "✅ Downloaded from Google Cloud Storage (fallback)"
  else
    echo "❌ Failed to download Minikube binary from both sources"
    echo ""
    echo "Attempted URLs:"
    echo "  Primary:  ${PRIMARY_URL}"
    echo "  Fallback: ${FALLBACK_URL}"
    echo ""
    echo "This may be due to:"
    echo "  1. GitHub service outage (check output above for status)"
    echo "  2. Network connectivity issues"
    echo "  3. Invalid version: ${VERSION}"
    echo "  4. Unsupported platform: ${PLATFORM}"
    echo ""
    echo "💡 Tip: If GitHub is experiencing issues, try re-running the workflow later"
    echo "        The binary will be cached for future runs once successfully downloaded"
    exit 1
  fi
fi

echo "✅ Successfully downloaded Minikube binary"

# Verify SHA256 checksum
CHECKSUM_URL="https://github.com/kubernetes/minikube/releases/download/${VERSION}/minikube-${PLATFORM}.sha256"
if ! download_and_verify_checksum minikube "$CHECKSUM_URL"; then
  echo "::error::Minikube binary checksum verification failed - the download may be corrupted or tampered with"
  rm -f minikube
  exit 1
fi

# Install the binary
chmod +x minikube

# Save to cache location
cp minikube /tmp/minikube-binary

# Move to final location
sudo mv minikube /usr/local/bin/

echo "✅ Minikube ${VERSION} installed successfully"

