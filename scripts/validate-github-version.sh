#!/usr/bin/env bash
set -euo pipefail

# Validates a version string and confirms it exists as a GitHub release.
# Usage: validate-github-version.sh <component> <github-repo> <version> [tag-prefix]

COMPONENT="${1:?Usage: $0 <component> <github-repo> <version> [tag-prefix]}"
GITHUB_REPO="${2:?Usage: $0 <component> <github-repo> <version> [tag-prefix]}"
VERSION="${3:?Usage: $0 <component> <github-repo> <version> [tag-prefix]}"
TAG_PREFIX="${4:-}"

# shellcheck source=lib/retry.sh
source "$(dirname "$0")/lib/retry.sh"

if ! [[ "$VERSION" =~ ^v?[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Invalid ${COMPONENT} version format: ${VERSION}"
  exit 1
fi

_last_http_code=""
check_github_release() {
  echo "Checking ${COMPONENT} version ${VERSION} on GitHub..."
  _last_http_code=$(curl --silent --output /dev/null --write-out "%{http_code}" -L \
    -H "Authorization: token ${GITHUB_TOKEN}" \
    "https://api.github.com/repos/${GITHUB_REPO}/releases/tags/${TAG_PREFIX}${VERSION}")
  if [ "$_last_http_code" = "200" ]; then
    echo "${COMPONENT} version ${VERSION} validated successfully"
    return 0
  fi
  echo "HTTP $_last_http_code"
  return 1
}

retry_with_backoff 5 2 check_github_release || {
  if [ "$_last_http_code" = "404" ]; then
    echo "${COMPONENT} version ${VERSION} does not exist on GitHub"
  else
    echo "GitHub API failed to validate ${COMPONENT} version ${VERSION} (HTTP $_last_http_code after 5 attempts)"
    echo "This may be a temporary GitHub API issue - consider re-running the workflow"
  fi
  exit 1
}
