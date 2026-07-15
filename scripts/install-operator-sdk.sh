#!/usr/bin/env bash
set -euo pipefail

OPERATOR_SDK_VERSION="${1:?operator-sdk version argument is required}"

echo "::group::Installing operator-sdk $OPERATOR_SDK_VERSION"
trap 'echo "::endgroup::"' EXIT

echo "Installing operator-sdk version $OPERATOR_SDK_VERSION"

if ! command -v curl >/dev/null 2>&1; then
  echo "Error: curl is not installed." >&2
  exit 1
fi

# shellcheck source=map-platform.sh
source "$(dirname "$0")/map-platform.sh"
# shellcheck source=verify-checksum.sh
source "$(dirname "$0")/verify-checksum.sh"
ARCH=$(map_arch "$(uname -m)")
OS=$(map_os "$(uname -s)")

DL_URL="https://github.com/operator-framework/operator-sdk/releases/download/${OPERATOR_SDK_VERSION}/operator-sdk_${OS}_${ARCH}"

echo "Downloading operator-sdk from: $DL_URL"
if ! curl -fL --retry 3 --retry-delay 5 -o /tmp/operator-sdk "$DL_URL"; then
  echo "Error: Failed to download operator-sdk" >&2
  exit 1
fi

# Verify SHA256 checksum
BINARY_NAME="operator-sdk_${OS}_${ARCH}"
CHECKSUM_URL="https://github.com/operator-framework/operator-sdk/releases/download/${OPERATOR_SDK_VERSION}/checksums.txt"
if ! download_and_verify_checksum /tmp/operator-sdk "$CHECKSUM_URL" "$BINARY_NAME"; then
  echo "::error::operator-sdk binary checksum verification failed - the download may be corrupted or tampered with"
  rm -f /tmp/operator-sdk
  exit 1
fi

chmod +x /tmp/operator-sdk
sudo mv /tmp/operator-sdk /usr/local/bin/operator-sdk

echo "operator-sdk $OPERATOR_SDK_VERSION installed successfully!"
operator-sdk version
