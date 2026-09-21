#!/usr/bin/env bash

set -euo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

assert_equal() {
  local expected="$1"
  local actual="$2"
  local description="$3"

  if [ "$expected" != "$actual" ]; then
    echo "FAIL: $description (expected '$expected', got '$actual')" >&2
    exit 1
  fi

  echo "PASS: $description"
}

assert_status() {
  local expected_status="$1"
  shift
  local description="$1"
  shift

  set +e
  "$@"
  local actual_status=$?
  set -e

  if [ "$expected_status" -ne "$actual_status" ]; then
    echo "FAIL: $description (expected status $expected_status, got $actual_status)" >&2
    exit 1
  fi

  echo "PASS: $description"
}

versions=$'v1.20.4\nv1.21.2\nv1.21.0-beta.0\nv1.19.9'
selected=$(printf '%s\n' "$versions" | "$script_dir/select-highest-version.sh" '^v[0-9]+\.[0-9]+\.[0-9]+$')
assert_equal 'v1.21.2' "$selected" 'select highest stable version'

prefixed_tags=$'controller-v1.15.0\ncontroller-v1.14.1\ncontroller-v1.15.1'
selected=$(printf '%s\n' "$prefixed_tags" | "$script_dir/select-highest-version.sh" '^v[0-9]+\.[0-9]+\.[0-9]+$' 'controller-')
assert_equal 'v1.15.1' "$selected" 'strip prefix and select highest version'

assert_status 0 'candidate greater than current is newer' \
  "$script_dir/is-version-newer.sh" 'v1.21.2' 'v1.22.0'
assert_status 1 'equal candidate is not newer' \
  "$script_dir/is-version-newer.sh" 'v1.21.2' 'v1.21.2'
assert_status 1 'lower candidate is not newer' \
  "$script_dir/is-version-newer.sh" 'v1.21.2' 'v1.20.4'

echo 'All version helper tests passed.'
