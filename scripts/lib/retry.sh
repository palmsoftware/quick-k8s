#!/usr/bin/env bash
# Sourceable retry-with-backoff utility.
#
# Usage:
#   source "$(dirname "$0")/lib/retry.sh"
#   retry_with_backoff 3 5 kubectl apply -f manifest.yaml
#
# For commands that need output capture or custom error handling,
# wrap them in a shell function:
#
#   apply_manifest() {
#     output=$(kubectl apply -f url 2>&1) || { echo "$output"; return 1; }
#     echo "$output"
#   }
#   retry_with_backoff 3 5 apply_manifest

retry_with_backoff() {
  local max_attempts="${1:?Usage: retry_with_backoff <max_attempts> <initial_delay> <command...>}"
  local initial_delay="${2:?Usage: retry_with_backoff <max_attempts> <initial_delay> <command...>}"
  shift 2

  local attempt=1
  local delay="$initial_delay"

  while [ "$attempt" -le "$max_attempts" ]; do
    if "$@"; then
      return 0
    fi
    if [ "$attempt" -eq "$max_attempts" ]; then
      return 1
    fi
    echo "Attempt $attempt/$max_attempts failed, retrying in ${delay}s..."
    sleep "$delay"
    delay=$((delay * 2))
    attempt=$((attempt + 1))
  done
  return 1
}
