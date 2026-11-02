#!/usr/bin/env bash
# Sourceable helpers for reading OpenShift mirror release.txt files.
#
# Requires lib/retry.sh to be sourced first (for retry_with_backoff).
#
# Usage:
#   source "$(dirname "$0")/lib/retry.sh"
#   source "$(dirname "$0")/lib/release-txt.sh"
#   VERSION=$(release_name "https://mirror.openshift.com/.../release.txt") || exit 1
#
# RELEASE_TXT_ATTEMPTS and RELEASE_TXT_DELAY override the retry count and the
# initial backoff delay in seconds (defaults: 3 and 10).

# fetch_release_txt <url>: print the body of release.txt, with retries.
fetch_release_txt() {
  local body
  if ! body=$(retry_with_backoff "${RELEASE_TXT_ATTEMPTS:-3}" "${RELEASE_TXT_DELAY:-10}" curl -fsSL "$1"); then
    echo "::error::Failed to fetch $1 after retries (mirror unreachable or version does not exist)" >&2
    return 1
  fi
  printf '%s\n' "$body"
}

# release_name <url>: print the release name from the Name: line of release.txt.
release_name() {
  local body name
  body=$(fetch_release_txt "$1") || return 1
  name=$(awk '/Name:/ { print $NF; exit }' <<<"$body")
  if [[ -z "$name" ]]; then
    echo "::error::No 'Name:' line in $1" >&2
    return 1
  fi
  printf '%s\n' "$name"
}
