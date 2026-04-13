#!/usr/bin/env bash
set -euo pipefail

OPERATOR_SDK_VERSION="${1:-v1.42.2}"

echo "Installing operator-sdk version $OPERATOR_SDK_VERSION"

for cmd in curl chmod; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Error: $cmd is not installed." >&2
    exit 1
  fi
done

if command -v operator-sdk >/dev/null 2>&1; then
  echo "operator-sdk is already installed: $(operator-sdk version)"
  exit 0
fi

ARCH="$(case $(uname -m) in x86_64) echo -n amd64 ;; aarch64) echo -n arm64 ;; *) echo -n "$(uname -m)" ;; esac)"
OS="$(uname | awk '{print tolower($0)}')"

DL_URL="https://github.com/operator-framework/operator-sdk/releases/download/${OPERATOR_SDK_VERSION}/operator-sdk_${OS}_${ARCH}"

echo "Downloading operator-sdk from: $DL_URL"
if ! curl -fL --retry 3 --retry-delay 5 -o /tmp/operator-sdk "$DL_URL"; then
  echo "Error: Failed to download operator-sdk" >&2
  exit 1
fi

chmod +x /tmp/operator-sdk
sudo mv /tmp/operator-sdk /usr/local/bin/operator-sdk

echo "operator-sdk $OPERATOR_SDK_VERSION installed successfully!"
operator-sdk version
