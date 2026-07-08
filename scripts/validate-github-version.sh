#!/usr/bin/env bash
set -euo pipefail

# Validates a version string and confirms it exists as a GitHub release.
# Usage: validate-github-version.sh <component> <github-repo> <version> [tag-prefix]

COMPONENT="${1:?Usage: $0 <component> <github-repo> <version> [tag-prefix]}"
GITHUB_REPO="${2:?Usage: $0 <component> <github-repo> <version> [tag-prefix]}"
VERSION="${3:?Usage: $0 <component> <github-repo> <version> [tag-prefix]}"
TAG_PREFIX="${4:-}"

if ! [[ "$VERSION" =~ ^v?[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Invalid ${COMPONENT} version format: ${VERSION}"
  exit 1
fi

max_attempts=5
attempt=1
delay=2
while [ $attempt -le $max_attempts ]; do
  http_code=$(curl --silent --output /dev/null --write-out "%{http_code}" -L \
    -H "Authorization: token ${GITHUB_TOKEN}" \
    "https://api.github.com/repos/${GITHUB_REPO}/releases/tags/${TAG_PREFIX}${VERSION}")
  if [ "$http_code" = "200" ]; then
    echo "${COMPONENT} version ${VERSION} validated successfully"
    break
  fi
  if [ $attempt -eq $max_attempts ]; then
    if [ "$http_code" = "404" ]; then
      echo "${COMPONENT} version ${VERSION} does not exist on GitHub"
    else
      echo "GitHub API failed to validate ${COMPONENT} version ${VERSION} (HTTP $http_code after $max_attempts attempts)"
      echo "This may be a temporary GitHub API issue - consider re-running the workflow"
    fi
    exit 1
  fi
  echo "Attempt $attempt/$max_attempts failed (HTTP $http_code), retrying in $delay seconds..."
  sleep $delay
  delay=$((delay * 2))
  attempt=$((attempt + 1))
done
