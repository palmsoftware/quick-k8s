#!/usr/bin/env bats

SCRIPT="$BATS_TEST_DIRNAME/../scripts/update-docs-version.sh"

setup() {
  TEST_TMPDIR=$(mktemp -d)
  export TEST_TMPDIR
  mkdir -p "$TEST_TMPDIR/docs"
  cat > "$TEST_TMPDIR/docs/configuration.md" <<'EOF'
      istioVersion: 1.31.0
      ciliumVersion: v0.20.0        # Cilium CLI version (when cniPlugin: cilium)
EOF
  cat > "$TEST_TMPDIR/README.md" <<'EOF'
minikubeVersion: v1.39.0
EOF
  mkdir -p "$TEST_TMPDIR/examples"
  cat > "$TEST_TMPDIR/examples/istio.yml" <<'EOF'
        with:
          installIstio: true
          istioVersion: 1.31.0
EOF
  cat > "$TEST_TMPDIR/COMPATIBILITY.md" <<'EOF'
| 1.37.x | v3.32.0+ | v1.17.0+ | 1.31.0+ |
EOF
}

teardown() {
  rm -rf "$TEST_TMPDIR"
}

@test "rewrites the field's version and keeps indentation and comments" {
  run "$SCRIPT" istioVersion 1.31.0 1.31.3 "$TEST_TMPDIR/docs" "$TEST_TMPDIR/README.md"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Updated istioVersion 1.31.0 -> 1.31.3 in"* ]]
  grep -qx '      istioVersion: 1.31.3' "$TEST_TMPDIR/docs/configuration.md"
  grep -qx '      ciliumVersion: v0.20.0        # Cilium CLI version (when cniPlugin: cilium)' \
    "$TEST_TMPDIR/docs/configuration.md"
  grep -qx 'minikubeVersion: v1.39.0' "$TEST_TMPDIR/README.md"
}

@test "rewrites the same version under a different key only when that key is targeted" {
  printf '      otherVersion: 1.31.0\n' >> "$TEST_TMPDIR/docs/configuration.md"

  run "$SCRIPT" istioVersion 1.31.0 1.31.3 "$TEST_TMPDIR/docs"

  [ "$status" -eq 0 ]
  grep -qx '      istioVersion: 1.31.3' "$TEST_TMPDIR/docs/configuration.md"
  grep -qx '      otherVersion: 1.31.0' "$TEST_TMPDIR/docs/configuration.md"
}

@test "rewrites the version in README when no paths are given" {
  cd "$TEST_TMPDIR" || return 1
  printf 'ignored\n' > note.txt

  run "$SCRIPT" minikubeVersion v1.39.0 v1.40.0

  [ "$status" -eq 0 ]
  grep -qx 'minikubeVersion: v1.40.0' "$TEST_TMPDIR/README.md"
}

@test "rewrites pinned versions in example workflows by default" {
  cd "$TEST_TMPDIR" || return 1

  run "$SCRIPT" istioVersion 1.31.0 1.31.3

  [ "$status" -eq 0 ]
  grep -qx '          istioVersion: 1.31.3' "$TEST_TMPDIR/examples/istio.yml"
  grep -qx '      istioVersion: 1.31.3' "$TEST_TMPDIR/docs/configuration.md"

  run "$SCRIPT" --check istioVersion 1.31.0

  [ "$status" -eq 0 ]
}

@test "reports no changes when the old version is not present" {
  run "$SCRIPT" istioVersion 9.9.9 9.9.10 "$TEST_TMPDIR/docs"

  [ "$status" -eq 0 ]
  [ -z "$output" ]
  grep -qx '      istioVersion: 1.31.0' "$TEST_TMPDIR/docs/configuration.md"
}

@test "check passes once the docs are updated" {
  "$SCRIPT" istioVersion 1.31.0 1.31.3 "$TEST_TMPDIR/docs"

  run "$SCRIPT" --check istioVersion 1.31.0 "$TEST_TMPDIR/docs"

  [ "$status" -eq 0 ]
}

@test "check fails and names the line when a stale version remains" {
  printf 'The istioVersion default is 1.31.0 today.\n' >> "$TEST_TMPDIR/docs/configuration.md"

  run "$SCRIPT" --check istioVersion 1.31.0 "$TEST_TMPDIR/docs"

  [ "$status" -eq 1 ]
  [[ "$output" == *"configuration.md"* ]]
  [[ "$output" == *"The istioVersion default is 1.31.0 today."* ]]
  [[ "$output" == *"still documented at 1.31.0"* ]]
}

@test "rewrites pinned versions in a root-level COMPATIBILITY.md by default" {
  cd "$TEST_TMPDIR" || return 1
  printf 'minikubeVersion: v1.39.0\n' > "$TEST_TMPDIR/COMPATIBILITY.md"

  run "$SCRIPT" minikubeVersion v1.39.0 v1.40.0

  [ "$status" -eq 0 ]
  grep -qx 'minikubeVersion: v1.40.0' "$TEST_TMPDIR/COMPATIBILITY.md"

  run "$SCRIPT" --check minikubeVersion v1.39.0

  [ "$status" -eq 0 ]
}

@test "check flags a prose mention in COMPATIBILITY.md" {
  printf 'installed by the `istioVersion` pin (`1.31.0`).\n' >> "$TEST_TMPDIR/COMPATIBILITY.md"

  run "$SCRIPT" --check istioVersion 1.31.0 "$TEST_TMPDIR/COMPATIBILITY.md"

  [ "$status" -eq 1 ]
  [[ "$output" == *"COMPATIBILITY.md"* ]]
}

@test "usage error when arguments are missing" {
  run "$SCRIPT" istioVersion

  [ "$status" -eq 2 ]
  [[ "$output" == *"Usage:"* ]]
}
