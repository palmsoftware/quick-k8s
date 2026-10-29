#!/usr/bin/env bats

source "$BATS_TEST_DIRNAME/../scripts/lib/cert-manager.sh"

setup() {
  TEST_TMPDIR=$(mktemp -d)
  export TEST_TMPDIR
  export KUBECTL_CALLS="$TEST_TMPDIR/kubectl-calls"
  export SLEEP_LOG="$TEST_TMPDIR/sleeps"
  export CA_INJECTED_AFTER_SLEEPS="${CA_INJECTED_AFTER_SLEEPS:-0}"
  mkdir -p "$TEST_TMPDIR/bin"

  # Stub sleep so the wait loop runs instantly but still counts elapsed polls.
  cat > "$TEST_TMPDIR/bin/sleep" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$1" >> "$SLEEP_LOG"
n=0
if [ -f "$TEST_TMPDIR/sleep_count" ]; then
  read -r n < "$TEST_TMPDIR/sleep_count"
fi
printf '%s\n' "$((n + 1))" > "$TEST_TMPDIR/sleep_count"
EOF
  chmod +x "$TEST_TMPDIR/bin/sleep"

  # Stub kubectl: returns an empty caBundle until CA_INJECTED_AFTER_SLEEPS polls.
  cat > "$TEST_TMPDIR/bin/kubectl" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$KUBECTL_CALLS"

case "$*" in
  "get validatingwebhookconfiguration/cert-manager-webhook "* | "get mutatingwebhookconfiguration/cert-manager-webhook "*)
    n=0
    if [ -f "$TEST_TMPDIR/sleep_count" ]; then
      read -r n < "$TEST_TMPDIR/sleep_count"
    fi
    if [ "$n" -ge "$CA_INJECTED_AFTER_SLEEPS" ]; then
      printf '%s' 'ZmFrZS1jYQ=='
    fi
    ;;
  *)
    printf 'unexpected kubectl invocation: %s\n' "$*" >&2
    exit 1
    ;;
esac
EOF
  chmod +x "$TEST_TMPDIR/bin/kubectl"

  PATH="$TEST_TMPDIR/bin:$PATH"
  export PATH
}

teardown() {
  rm -rf "$TEST_TMPDIR"
}

@test "wait_for_cert_manager_webhook_ca succeeds when the caBundle is already injected" {
  run wait_for_cert_manager_webhook_ca 10 1

  [ "$status" -eq 0 ]
  [[ "$output" == *"caBundle injected"* ]]
  [ ! -f "$SLEEP_LOG" ]
  grep -q '^get validatingwebhookconfiguration/cert-manager-webhook ' "$KUBECTL_CALLS"
  grep -q '^get mutatingwebhookconfiguration/cert-manager-webhook ' "$KUBECTL_CALLS"
}

@test "wait_for_cert_manager_webhook_ca polls until cainjector injects the caBundle" {
  export CA_INJECTED_AFTER_SLEEPS=2

  run wait_for_cert_manager_webhook_ca 10 1

  [ "$status" -eq 0 ]
  [[ "$output" == *"caBundle injected"* ]]
  [ "$(wc -l < "$SLEEP_LOG" | tr -d ' ')" = "2" ]
}

@test "wait_for_cert_manager_webhook_ca fails after the timeout elapses" {
  export CA_INJECTED_AFTER_SLEEPS=999

  run wait_for_cert_manager_webhook_ca 4 1

  [ "$status" -eq 1 ]
  [[ "$output" == *"Timed out after 4s"* ]]
  [ "$(wc -l < "$SLEEP_LOG" | tr -d ' ')" = "3" ]
}
