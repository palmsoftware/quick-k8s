#!/usr/bin/env bash
set -euo pipefail

# Pre-pull Kind node image so it's cached before kind create cluster,
# which has no retry logic and fails hard on Docker Hub rate limits.
# Usage: pull-kind-image.sh <image>

IMAGE="${1:-}"

if [ -z "$IMAGE" ]; then
  echo "Usage: $0 <image>"
  echo "Example: $0 kindest/node:v1.35.0@sha256:452d707d..."
  exit 1
fi

max_attempts=3
delay=30

echo "Pre-pulling Kind node image: $IMAGE"

attempt=1
while [ $attempt -le $max_attempts ]; do
  echo ""
  echo "📥 Attempt $attempt/$max_attempts: Pulling Kind node image..."

  set +e
  docker pull "$IMAGE"
  exit_code=$?
  set -e

  if [ $exit_code -eq 0 ]; then
    echo ""
    echo "✅ Successfully pulled Kind node image"
    exit 0
  fi

  if [ $attempt -eq $max_attempts ]; then
    echo ""
    echo "❌ Failed to pull image after $max_attempts attempts (exit code: $exit_code)"
    echo ""
    echo "This is likely due to:"
    echo "  1. Docker Hub rate limiting (unauthenticated pulls are limited to 100 per 6 hours)"
    echo "  2. Network connectivity issues"
    echo "  3. Docker daemon issues"
    echo ""
    echo "💡 Tip: If this is a rate limiting issue, you can:"
    echo "        - Wait and re-run the workflow later"
    echo "        - Configure Docker Hub authentication in your workflow"
    echo "        - Use a Docker registry mirror"
    exit 1
  fi

  echo ""
  echo "⚠️  Pull failed (exit code: $exit_code), retrying in ${delay}s..."
  sleep $delay
  attempt=$((attempt + 1))
  delay=$((delay * 2))
done

exit 1
