#!/usr/bin/env bash

set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "Usage: $0 <current-version> <candidate-version>" >&2
  exit 2
fi

current_version="$1"
candidate_version="$2"

if [ -z "$current_version" ] || [ -z "$candidate_version" ]; then
  exit 1
fi

highest_version=$(printf '%s\n' "$current_version" "$candidate_version" | sort -V | tail -n 1)

[ "$candidate_version" != "$current_version" ] && [ "$highest_version" = "$candidate_version" ]
