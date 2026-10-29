#!/usr/bin/env bash
# Keep the pinned versions shown in the docs in sync with action.yml.
#
# .github/workflows/version-updates.yml bumps a component's `default:` in
# action.yml only. The docs repeat those defaults in YAML snippets
# (docs/configuration.md, docs/optional-features.md, README.md, examples/*.yml),
# so they used to drift on every automated bump — e.g. action.yml said
# certManagerVersion v1.21.3 while the docs still said v1.21.2.
#
# Usage:
#   update-docs-version.sh <field> <old-version> <new-version> [path...]
#   update-docs-version.sh --check <field> <old-version> [path...]
#
# With no paths, docs/, README.md and examples/ are searched. Directories are
# scanned for *.md, *.yml and *.yaml files. Only lines of the form
# `<field>: <old-version>` (optionally followed by a `#` comment) are rewritten,
# so a coincidental match of the same version string under a different key is
# left alone.
#
# --check turns the "stale version left behind" case into a failure: it reports
# every line that still pairs <field> with <old-version> in any form (wider than
# the rewrite pattern, so oddly formatted snippets are caught) and exits 1.
set -euo pipefail

DEFAULT_PATHS=(docs README.md examples)

usage() {
  cat >&2 <<'EOF'
Usage:
  update-docs-version.sh <field> <old-version> <new-version> [path...]
  update-docs-version.sh --check <field> <old-version> [path...]

Rewrites `<field>: <old-version>` to `<field>: <new-version>` in the given
markdown/YAML files and directories (default: docs README.md examples).

  --check   Report lines that still pair <field> with <old-version> and exit 1.
EOF
}

check_only=false
if [ "${1:-}" = "--check" ]; then
  check_only=true
  shift
fi

if [ "$check_only" = true ]; then
  if [ "$#" -lt 2 ]; then
    usage
    exit 2
  fi
else
  if [ "$#" -lt 3 ]; then
    usage
    exit 2
  fi
fi

field="$1"
old_version="$2"
if [ "$check_only" = true ]; then
  new_version=""
  shift 2
else
  new_version="$3"
  shift 3
fi

if [ "$#" -eq 0 ]; then
  set -- "${DEFAULT_PATHS[@]}"
fi

# Escape the version for use in an ERE; versions are dotted, e.g. v1.21.3.
escape_ere() {
  printf '%s' "$1" | sed 's/[][\\.*^$+?(){}|]/\\&/g'
}

old_re=$(escape_ere "$old_version")

collect_files() {
  local path
  for path in "$@"; do
    if [ -d "$path" ]; then
      find "$path" -type f \( -name '*.md' -o -name '*.yml' -o -name '*.yaml' \) -print0
    elif [ -f "$path" ]; then
      printf '%s\0' "$path"
    else
      echo "warning: $path does not exist, skipping" >&2
    fi
  done
}

if [ "$check_only" = true ]; then
  stale=0
  while IFS= read -r -d '' file; do
    if matches=$(grep -nE "${field}.*${old_re}" "$file"); then
      printf '%s:\n%s\n' "$file" "$matches"
      stale=1
    fi
  done < <(collect_files "$@")

  if [ "$stale" -eq 1 ]; then
    echo "error: ${field} is still documented at ${old_version}; update the snippet(s) above." >&2
    exit 1
  fi
  exit 0
fi

while IFS= read -r -d '' file; do
  tmp=$(mktemp)
  # shellcheck disable=SC2016  # \1/\2 are sed backreferences, not shell expansions
  sed -E "s|^([[:space:]]*${field}:[[:space:]]*)${old_re}([[:space:]]*(#.*)?)\$|\\1${new_version}\\2|" \
    "$file" > "$tmp"
  if cmp -s "$file" "$tmp"; then
    rm -f "$tmp"
    continue
  fi
  # Overwrite in place so file mode and ownership are preserved.
  cat "$tmp" > "$file"
  rm -f "$tmp"
  echo "Updated ${field} ${old_version} -> ${new_version} in ${file}"
done < <(collect_files "$@")
