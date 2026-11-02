#!/usr/bin/env bats

source "$BATS_TEST_DIRNAME/../scripts/lib/retry.sh"
source "$BATS_TEST_DIRNAME/../scripts/lib/release-txt.sh"

URL="https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/latest-4.22/release.txt"

setup() {
  TEST_TMPDIR=$(mktemp -d)
  mkdir -p "$TEST_TMPDIR/bin"

  CURL_LOG="$TEST_TMPDIR/curl-calls"
  SLEEP_LOG="$TEST_TMPDIR/sleeps"
  RELEASE_BODY="$TEST_TMPDIR/release.txt"
  # curl fails on calls before this number, then prints RELEASE_BODY.
  CURL_SUCCEED_ON_CALL=1
  export CURL_LOG SLEEP_LOG RELEASE_BODY CURL_SUCCEED_ON_CALL

  cat >"$RELEASE_BODY" <<'EOF'
Client tools for OpenShift
--------------------------

Name:      4.22.3
Digest:    sha256:0000000000000000000000000000000000000000000000000000000000000000
Created:   2026-10-30T12:00:00Z
EOF

  cat >"$TEST_TMPDIR/bin/curl" <<'EOF'
#!/usr/bin/env bash
call=0
if [ -f "$CURL_LOG" ]; then
  call=$(wc -l <"$CURL_LOG")
fi
call=$((call + 1))
printf '%s\n' "$*" >>"$CURL_LOG"
if [ "$call" -lt "$CURL_SUCCEED_ON_CALL" ]; then
  exit 7
fi
cat "$RELEASE_BODY"
EOF
  chmod +x "$TEST_TMPDIR/bin/curl"

  cat >"$TEST_TMPDIR/bin/sleep" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$1" >>"$SLEEP_LOG"
EOF
  chmod +x "$TEST_TMPDIR/bin/sleep"

  PATH="$TEST_TMPDIR/bin:$PATH"
  export PATH
}

teardown() {
  rm -rf "$TEST_TMPDIR"
}

curl_calls() {
  wc -l <"$CURL_LOG" | tr -d ' '
}

@test "release_name fails with an error annotation when the mirror is unreachable" {
  CURL_SUCCEED_ON_CALL=99
  export CURL_SUCCEED_ON_CALL

  run release_name "$URL"

  [ "$status" -eq 1 ]
  [[ "$output" == *"::error::Failed to fetch $URL"* ]]
  [ "$(curl_calls)" = "3" ]
  [ "$(cat "$SLEEP_LOG")" = $'10\n20' ]
}

@test "release_name fails with an error annotation when release.txt has no Name line" {
  printf '<html>503 Service Unavailable</html>\n' >"$RELEASE_BODY"

  run release_name "$URL"

  [ "$status" -eq 1 ]
  [[ "$output" == *"::error::No 'Name:' line in $URL"* ]]
}

@test "release_name succeeds after a transient failure and prints only the name" {
  CURL_SUCCEED_ON_CALL=2
  export CURL_SUCCEED_ON_CALL

  # Capture stdout only: retry messages must go to stderr.
  name=$(release_name "$URL" 2>/dev/null)

  [ "$name" = "4.22.3" ]
  [ "$(curl_calls)" = "2" ]
}

@test "release_name passes fail-on-HTTP-error flags to curl" {
  run release_name "$URL"

  [ "$status" -eq 0 ]
  [[ "$(cat "$CURL_LOG")" == "-fsSL $URL" ]]
}

@test "fetch_release_txt returns the full release.txt body" {
  run fetch_release_txt "$URL"

  [ "$status" -eq 0 ]
  [ "$output" = "$(cat "$RELEASE_BODY")" ]
  [ "$(curl_calls)" = "1" ]
}

@test "install-oc-tools.sh has no mirror lookups without retries" {
  run grep -nE 'curl (-s |--silent|--write-out)' "$BATS_TEST_DIRNAME/../scripts/install-oc-tools.sh"

  [ "$status" -eq 1 ]
}
