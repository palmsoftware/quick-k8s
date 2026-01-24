#!/usr/bin/env bash
OLM_VERSION="v0.39.0"
echo "Installing OLM version $OLM_VERSION"

for cmd in curl kubectl; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Error: $cmd is not installed." >&2
    exit 1
  fi
done

curl -L https://github.com/operator-framework/operator-lifecycle-manager/releases/download/$OLM_VERSION/install.sh -o install.sh
chmod +x install.sh
./install.sh $OLM_VERSION
rm install.sh
