#!/usr/bin/env bash
set -euo pipefail

# Pre-pull Kind node image so it's cached before kind create cluster,
# which has no retry logic and fails hard on Docker Hub rate limits.
# Usage: pull-kind-image.sh <image>

IMAGE="${1:-}"

if [ -z "$IMAGE" ]; then
  echo "Usage: $0 <image>" >&2
  echo "Example: $0 kindest/node:v1.35.0@sha256:452d707d..." >&2
  exit 1
fi

# shellcheck source=lib/retry.sh
source "$(dirname "$0")/lib/retry.sh"

echo "::group::Pre-pulling KinD node image"
trap 'echo "::endgroup::"' EXIT

echo "Pre-pulling Kind node image: $IMAGE"

retry_with_backoff 3 30 docker pull "$IMAGE" || {
  echo ""
  echo "Failed to pull image after 3 attempts"
  echo ""
  echo "This is likely due to:"
  echo "  1. Docker Hub rate limiting (unauthenticated pulls are limited to 100 per 6 hours)"
  echo "  2. Network connectivity issues"
  echo "  3. Docker daemon issues"
  echo ""
  echo "Tip: If this is a rate limiting issue, you can:"
  echo "     - Wait and re-run the workflow later"
  echo "     - Configure Docker Hub authentication in your workflow"
  echo "     - Use a Docker registry mirror"
  exit 1
}

echo ""
echo "Successfully pulled Kind node image"
