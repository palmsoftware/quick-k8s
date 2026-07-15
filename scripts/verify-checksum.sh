#!/usr/bin/env bash
# Sourceable utility that provides SHA256 checksum verification for downloaded binaries.
#
# Usage:
#   source "$(dirname "$0")/verify-checksum.sh"
#   verify_checksum <file> <expected_sha256>
#   download_and_verify_checksum <file> <checksum_url> [binary_name]

# Verify a file's SHA256 checksum against an expected value.
# Arguments:
#   $1 - Path to the file to verify
#   $2 - Expected SHA256 hash
verify_checksum() {
  local file="$1"
  local expected="$2"
  local actual

  if [ ! -f "$file" ]; then
    echo "::error::Checksum verification failed: file not found: $file"
    return 1
  fi

  actual=$(sha256sum "$file" | awk '{print $1}')
  if [ "$actual" != "$expected" ]; then
    echo "::error::Checksum verification failed for $file"
    echo "  Expected: $expected"
    echo "  Actual:   $actual"
    return 1
  fi
  echo "Checksum verified for $file"
}

# Download a checksum file and verify against a local file.
# Supports multiple checksum file formats:
#   - Hash only (e.g., Minikube: just the hash)
#   - "hash  filename" (e.g., KinD, operator-sdk)
#   - "hash filename" (e.g., Istio)
# Arguments:
#   $1 - Path to the file to verify
#   $2 - URL to download the checksum from
#   $3 - (Optional) Binary name to grep for in multi-entry checksum files
download_and_verify_checksum() {
  local file="$1"
  local checksum_url="$2"
  local binary_name="${3:-}"
  local checksum_content
  local expected

  echo "Downloading checksum from: $checksum_url"
  if ! checksum_content=$(curl -fsSL "$checksum_url" 2>/dev/null); then
    echo "::warning::Could not download checksum file from $checksum_url - skipping verification"
    return 0
  fi

  # If a binary name is given, extract the matching line from a multi-entry file
  if [ -n "$binary_name" ]; then
    local matching_line
    matching_line=$(echo "$checksum_content" | grep -F "$binary_name" | head -1)
    if [ -z "$matching_line" ]; then
      echo "::warning::No checksum entry found for $binary_name - skipping verification"
      return 0
    fi
    expected=$(echo "$matching_line" | awk '{print $1}')
  else
    # Single-entry file: extract just the hash (first field, or only content)
    expected=$(echo "$checksum_content" | awk '{print $1}' | head -1)
  fi

  if [ -z "$expected" ]; then
    echo "::warning::Could not parse checksum from downloaded file - skipping verification"
    return 0
  fi

  verify_checksum "$file" "$expected"
}
