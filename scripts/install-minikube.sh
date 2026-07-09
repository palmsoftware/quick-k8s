#!/usr/bin/env bash
set -euo pipefail

# Script to install Minikube binary with caching support
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

# shellcheck source=map-platform.sh
source "$(dirname "$0")/map-platform.sh"
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

# Download the binary
DOWNLOAD_URL="https://storage.googleapis.com/minikube/releases/${VERSION}/minikube-${PLATFORM}"

echo "Downloading Minikube ${VERSION} for ${PLATFORM}..."
echo "📥 Attempting download from: ${DOWNLOAD_URL}"

if ! curl -fsSL -o minikube "${DOWNLOAD_URL}"; then
  echo "❌ Failed to download Minikube binary"
  echo ""
  echo "Attempted URL: ${DOWNLOAD_URL}"
  echo ""
  echo "This may be due to:"
  echo "  1. Network connectivity issues"
  echo "  2. Google Cloud Storage outage"
  echo "  3. Invalid version: ${VERSION}"
  echo "  4. Unsupported platform: ${PLATFORM}"
  echo ""
  echo "💡 Tip: Try re-running the workflow later"
  echo "        The binary will be cached for future runs once successfully downloaded"
  exit 1
fi

echo "✅ Successfully downloaded Minikube binary"

# Install the binary
chmod +x minikube

# Save to cache location
cp minikube /tmp/minikube-binary

# Move to final location
sudo mv minikube /usr/local/bin/

echo "✅ Minikube ${VERSION} installed successfully"

