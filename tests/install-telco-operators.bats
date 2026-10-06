#!/usr/bin/env bats

SCRIPT="$BATS_TEST_DIRNAME/../scripts/install-telco-operators.sh"
TLS_COMPLIANCE_OPERATOR_URL="https://github.com/sebrandon1/tls-compliance-operator/releases/latest/download/install.yaml"
IMAGE_CERT_INFO_OPERATOR_URL="https://github.com/sebrandon1/imagecertinfo-operator/releases/latest/download/install.yaml"

setup() {
  TEST_ROOT=$(mktemp -d)
  export KUBECTL_CALL_LOG="$TEST_ROOT/kubectl-calls"
  export PATH="$TEST_ROOT/bin:$PATH"

  mkdir -p "$TEST_ROOT/bin"
  cat >"$TEST_ROOT/bin/kubectl" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$KUBECTL_CALL_LOG"
if [[ "${FAIL_ON_URL:-}" != "" && "$*" == *"$FAIL_ON_URL"* ]]; then
  exit 1
fi
EOF
  chmod +x "$TEST_ROOT/bin/kubectl"
}

teardown() {
  rm -rf "$TEST_ROOT"
}

@test "skips both operators when the input is unset" {
  unset INSTALL_TELCO_OPERATORS

  run bash "$SCRIPT"

  [ "$status" -eq 0 ]
  [ ! -s "$KUBECTL_CALL_LOG" ]
}

@test "installs both latest operator releases when enabled" {
  export INSTALL_TELCO_OPERATORS=true

  run bash "$SCRIPT"

  [ "$status" -eq 0 ]
  [ "$(wc -l <"$KUBECTL_CALL_LOG")" -eq 2 ]
  grep -Fq "apply -f $TLS_COMPLIANCE_OPERATOR_URL" "$KUBECTL_CALL_LOG"
  grep -Fq "apply -f $IMAGE_CERT_INFO_OPERATOR_URL" "$KUBECTL_CALL_LOG"
}

@test "fails when kubectl is unavailable" {
  export INSTALL_TELCO_OPERATORS=true
  rm "$TEST_ROOT/bin/kubectl"
  export PATH="$TEST_ROOT/bin:/usr/bin:/bin"

  run /bin/bash "$SCRIPT"

  [ "$status" -eq 1 ]
  [[ "$output" == *"kubectl is not installed"* ]]
}

@test "returns a failure when applying either operator manifest fails" {
  export INSTALL_TELCO_OPERATORS=true

  for url in "$TLS_COMPLIANCE_OPERATOR_URL" "$IMAGE_CERT_INFO_OPERATOR_URL"; do
    : >"$KUBECTL_CALL_LOG"
    export FAIL_ON_URL="$url"
    run bash "$SCRIPT"

    [ "$status" -eq 1 ]
    grep -Fq "apply -f $url" "$KUBECTL_CALL_LOG"
  done
}
