#!/usr/bin/env bash
set -euo pipefail

# Fetches the latest k3s release version from GitHub API with retries.
# Outputs the version to stdout on success, exits non-zero on failure.

RETRIES=3
DELAY=5

for ((i=1; i<=RETRIES; i++)); do
  echo "Attempt $i to fetch k3s version..." >&2

  if response=$(curl -s --max-time 30 https://api.github.com/repos/k3s-io/k3s/releases/latest) && [ -n "$response" ]; then
    version=$(echo "$response" | jq -r '.tag_name // empty')

    if [ -n "$version" ] && [ "$version" != "null" ] && [[ "$version" =~ ^v[0-9]+\.[0-9]+\.[0-9]+\+k3s[0-9]+$ ]]; then
      echo "Successfully fetched k3s version: $version" >&2
      echo "$version"
      exit 0
    else
      echo "Invalid version format: '$version'" >&2
    fi
  else
    echo "API call failed or returned empty response" >&2
  fi

  if [ $i -lt $RETRIES ]; then
    echo "Retrying in $DELAY seconds..." >&2
    sleep $DELAY
  fi
done

echo "Failed to fetch valid k3s version after $RETRIES attempts" >&2
exit 1
