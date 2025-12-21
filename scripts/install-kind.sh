#!/usr/bin/env bash
set -euo pipefail

# Script to install KinD binary with caching and fallback support
# Usage: install-kind.sh <version> <os> <arch>
# Example: install-kind.sh v0.31.0 linux amd64

VERSION="${1:-}"
OS="${2:-}"
ARCH="${3:-}"

if [ -z "$VERSION" ] || [ -z "$OS" ] || [ -z "$ARCH" ]; then
  echo "Usage: $0 <version> <os> <arch>"
  echo "Example: $0 v0.31.0 linux amd64"
  exit 1
fi

# Map architecture names (GitHub Actions uses X64/x64/ARM64/arm64, KinD uses amd64/arm64)
# Convert to lowercase first
ARCH=$(echo "$ARCH" | tr '[:upper:]' '[:lower:]')

# Then map to KinD's naming convention
if [ "$ARCH" = "x64" ]; then
  ARCH="amd64"
fi

# Determine the platform string for KinD
PLATFORM="${OS}-${ARCH}"

echo "Installing KinD ${VERSION} for ${PLATFORM}..."

# Check if binary is already cached
if [ -f /tmp/kind-binary ]; then
  echo "✅ Using cached KinD binary"
  sudo cp /tmp/kind-binary /usr/local/bin/kind
  sudo chmod +x /usr/local/bin/kind
  exit 0
fi

# Download the binary with fallback
echo "Downloading KinD ${VERSION} for ${PLATFORM}..."

# Primary URL
PRIMARY_URL="https://kind.sigs.k8s.io/dl/${VERSION}/kind-${PLATFORM}"
FALLBACK_URL="https://github.com/kubernetes-sigs/kind/releases/download/${VERSION}/kind-${PLATFORM}"

echo "📥 Attempting download from: ${PRIMARY_URL}"

# Try primary source
if curl -fsSL -o kind "${PRIMARY_URL}"; then
  echo "✅ Downloaded from kind.sigs.k8s.io"
# Try GitHub releases as fallback
else
  echo "⚠️  Primary URL failed, trying fallback: ${FALLBACK_URL}"
  if curl -fsSL -o kind "${FALLBACK_URL}"; then
    echo "✅ Downloaded from GitHub releases (fallback)"
  else
    echo "❌ Failed to download KinD binary from both sources"
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

# Verify it's a binary, not HTML
if file kind | grep -q "HTML"; then
  echo "ERROR: Downloaded file is HTML, not a binary"
  exit 1
fi

# Install the binary
chmod +x kind

# Save to cache location
cp kind /tmp/kind-binary

# Move to final location
sudo mv kind /usr/local/bin/

echo "✅ KinD ${VERSION} installed successfully"

