#!/usr/bin/env bash

set -euo pipefail

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
  echo "Usage: $0 <version-regex> [tag-prefix]" >&2
  exit 2
fi

version_regex="$1"
tag_prefix="${2:-}"

while IFS= read -r tag; do
  [ -z "$tag" ] && continue

  version="$tag"
  if [ -n "$tag_prefix" ] && [[ "$version" == "$tag_prefix"* ]]; then
    version="${version#"$tag_prefix"}"
  fi

  if [[ "$version" =~ $version_regex ]]; then
    printf '%s\n' "$version"
  fi
done | sort -V | tail -n 1
