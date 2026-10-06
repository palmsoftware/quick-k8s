#!/usr/bin/env bats

source "$BATS_TEST_DIRNAME/../scripts/map-platform.sh"
source "$BATS_TEST_DIRNAME/../scripts/lib/retry.sh"
source "$BATS_TEST_DIRNAME/../scripts/verify-checksum.sh"

setup() {
  TEST_TMPDIR=$(mktemp -d)
  export TEST_TMPDIR
  mkdir -p "$TEST_TMPDIR/bin"

  ATTEMPT_LOG="$TEST_TMPDIR/attempts"
  SLEEP_LOG="$TEST_TMPDIR/sleeps"
  SUCCEED_ON_ATTEMPT=1
  export ATTEMPT_LOG SLEEP_LOG SUCCEED_ON_ATTEMPT

  PATH="$TEST_TMPDIR/bin:$PATH"
  export PATH

  cat > "$TEST_TMPDIR/bin/sleep" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$1" >> "$SLEEP_LOG"
EOF
  chmod +x "$TEST_TMPDIR/bin/sleep"

  cat > "$TEST_TMPDIR/bin/curl" <<'EOF'
#!/usr/bin/env bash
url=
for argument in "$@"; do
  url="$argument"
done

case "$url" in
  file://*) cat "${url#file://}" ;;
  *) exit 22 ;;
esac
EOF
  chmod +x "$TEST_TMPDIR/bin/curl"

  # macOS has shasum instead of sha256sum; provide the interface the helper uses.
  if ! command -v sha256sum >/dev/null 2>&1; then
    cat > "$TEST_TMPDIR/bin/sha256sum" <<'EOF'
#!/usr/bin/env bash
exec shasum -a 256 "$@"
EOF
    chmod +x "$TEST_TMPDIR/bin/sha256sum"
  fi

  cat > "$TEST_TMPDIR/bin/retry-command" <<'EOF'
#!/usr/bin/env bash
attempt=0
if [ -f "$ATTEMPT_LOG" ]; then
  read -r attempt < "$ATTEMPT_LOG"
fi
attempt=$((attempt + 1))
printf '%s\n' "$attempt" > "$ATTEMPT_LOG"
[ "$attempt" -ge "$SUCCEED_ON_ATTEMPT" ]
EOF
  chmod +x "$TEST_TMPDIR/bin/retry-command"
}

teardown() {
  rm -rf "$TEST_TMPDIR"
}

checksum_for() {
  sha256sum "$1" | awk '{print $1}'
}

@test "map_os normalizes macOS and lowercases other operating systems" {
  run map_os macOS
  [ "$status" -eq 0 ]
  [ "$output" = "darwin" ]

  run map_os Linux
  [ "$status" -eq 0 ]
  [ "$output" = "linux" ]
}

@test "map_arch maps supported aliases and lowercases other architectures" {
  run map_arch x64
  [ "$status" -eq 0 ]
  [ "$output" = "amd64" ]

  run map_arch X86_64
  [ "$status" -eq 0 ]
  [ "$output" = "amd64" ]

  run map_arch aarch64
  [ "$status" -eq 0 ]
  [ "$output" = "arm64" ]

  run map_arch RISC-V
  [ "$status" -eq 0 ]
  [ "$output" = "risc-v" ]
}

@test "retry_with_backoff succeeds after a transient failure" {
  SUCCEED_ON_ATTEMPT=2
  export SUCCEED_ON_ATTEMPT
  run retry_with_backoff 3 2 retry-command

  [ "$status" -eq 0 ]
  [ "$(cat "$ATTEMPT_LOG")" = "2" ]
  [ "$(cat "$SLEEP_LOG")" = "2" ]
}

@test "retry_with_backoff stops after exhaustion and doubles its delays" {
  SUCCEED_ON_ATTEMPT=4
  export SUCCEED_ON_ATTEMPT
  run retry_with_backoff 3 2 retry-command

  [ "$status" -eq 1 ]
  [ "$(cat "$ATTEMPT_LOG")" = "3" ]
  [ "$(cat "$SLEEP_LOG")" = $'2\n4' ]
}

@test "verify_checksum accepts a matching checksum" {
  printf 'test binary contents\n' > "$TEST_TMPDIR/binary"
  expected=$(checksum_for "$TEST_TMPDIR/binary")

  run verify_checksum "$TEST_TMPDIR/binary" "$expected"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Checksum verified"* ]]
}

@test "verify_checksum rejects a mismatching checksum" {
  printf 'test binary contents\n' > "$TEST_TMPDIR/binary"

  run verify_checksum "$TEST_TMPDIR/binary" "0000000000000000000000000000000000000000000000000000000000000000"

  [ "$status" -eq 1 ]
  [[ "$output" == *"Checksum verification failed"* ]]
}

@test "verify_checksum rejects a missing file" {
  run verify_checksum "$TEST_TMPDIR/missing" "expected-checksum"

  [ "$status" -eq 1 ]
  [[ "$output" == *"file not found"* ]]
}

@test "download_and_verify_checksum verifies a hash-only local fixture" {
  printf 'test binary contents\n' > "$TEST_TMPDIR/binary"
  expected=$(checksum_for "$TEST_TMPDIR/binary")
  printf '%s\n' "$expected" > "$TEST_TMPDIR/checksum"

  run download_and_verify_checksum "$TEST_TMPDIR/binary" "file://$TEST_TMPDIR/checksum"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Checksum verified"* ]]
}

@test "download_and_verify_checksum selects the matching binary entry" {
  printf 'test binary contents\n' > "$TEST_TMPDIR/binary"
  expected=$(checksum_for "$TEST_TMPDIR/binary")
  printf '%064d  another-binary\n%s  test-binary\n' 0 "$expected" > "$TEST_TMPDIR/checksums"

  run download_and_verify_checksum "$TEST_TMPDIR/binary" "file://$TEST_TMPDIR/checksums" test-binary

  [ "$status" -eq 0 ]
  [[ "$output" == *"Checksum verified"* ]]
}

@test "download_and_verify_checksum fails when the downloaded checksum mismatches" {
  printf 'test binary contents\n' > "$TEST_TMPDIR/binary"
  printf '%064d  test-binary\n' 0 > "$TEST_TMPDIR/checksums"

  run download_and_verify_checksum "$TEST_TMPDIR/binary" "file://$TEST_TMPDIR/checksums" test-binary

  [ "$status" -eq 1 ]
  [[ "$output" == *"Checksum verification failed"* ]]
}

@test "download_and_verify_checksum warns and skips when the checksum cannot be downloaded" {
  printf 'test binary contents\n' > "$TEST_TMPDIR/binary"

  run download_and_verify_checksum "$TEST_TMPDIR/binary" "file://$TEST_TMPDIR/missing"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Could not download checksum file"* ]]
}

@test "download_and_verify_checksum warns and skips when no binary entry matches" {
  printf 'test binary contents\n' > "$TEST_TMPDIR/binary"
  printf '%064d  another-binary\n' 0 > "$TEST_TMPDIR/checksums"

  run download_and_verify_checksum "$TEST_TMPDIR/binary" "file://$TEST_TMPDIR/checksums" test-binary

  [ "$status" -eq 0 ]
  [[ "$output" == *"No checksum entry found for test-binary"* ]]
}

@test "download_and_verify_checksum warns and skips when checksum data is empty" {
  printf 'test binary contents\n' > "$TEST_TMPDIR/binary"
  : > "$TEST_TMPDIR/checksum"

  run download_and_verify_checksum "$TEST_TMPDIR/binary" "file://$TEST_TMPDIR/checksum"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Could not parse checksum"* ]]
}
