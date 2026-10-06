#!/usr/bin/env bats

SCRIPT="$BATS_TEST_DIRNAME/../scripts/install-telco-operators.sh"
TLS_COMPLIANCE_OPERATOR_URL="https://github.com/sebrandon1/tls-compliance-operator/releases/latest/download/install.yaml"
IMAGE_CERT_INFO_OPERATOR_URL="https://github.com/sebrandon1/imagecertinfo-operator/releases/latest/download/install.yaml"

setup() {
  TEST_ROOT=$(mktemp -d)
  export KUBECTL_CALL_LOG="$TEST_ROOT/kubectl-calls"
  export INSTALL_TLS_COMPLIANCE_OPERATOR=false
  export INSTALL_IMAGE_CERT_INFO_OPERATOR=false
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

@test "skips both operators when neither is selected" {
  run bash "$SCRIPT"

  [ "$status" -eq 0 ]
  [ ! -s "$KUBECTL_CALL_LOG" ]
}

@test "installs only the TLS Compliance Operator when selected" {
  export INSTALL_TLS_COMPLIANCE_OPERATOR=true

  run bash "$SCRIPT"

  [ "$status" -eq 0 ]
  [ "$(wc -l <"$KUBECTL_CALL_LOG")" -eq 1 ]
  grep -Fq "apply -f $TLS_COMPLIANCE_OPERATOR_URL" "$KUBECTL_CALL_LOG"
  ! grep -Fq "$IMAGE_CERT_INFO_OPERATOR_URL" "$KUBECTL_CALL_LOG"
}

@test "installs only the Image Cert Info Operator when selected" {
  export INSTALL_IMAGE_CERT_INFO_OPERATOR=true

  run bash "$SCRIPT"

  [ "$status" -eq 0 ]
  [ "$(wc -l <"$KUBECTL_CALL_LOG")" -eq 1 ]
  grep -Fq "apply -f $IMAGE_CERT_INFO_OPERATOR_URL" "$KUBECTL_CALL_LOG"
  ! grep -Fq "$TLS_COMPLIANCE_OPERATOR_URL" "$KUBECTL_CALL_LOG"
}

@test "installs both operators when both are selected" {
  export INSTALL_TLS_COMPLIANCE_OPERATOR=true
  export INSTALL_IMAGE_CERT_INFO_OPERATOR=true

  run bash "$SCRIPT"

  [ "$status" -eq 0 ]
  [ "$(wc -l <"$KUBECTL_CALL_LOG")" -eq 2 ]
  grep -Fq "apply -f $TLS_COMPLIANCE_OPERATOR_URL" "$KUBECTL_CALL_LOG"
  grep -Fq "apply -f $IMAGE_CERT_INFO_OPERATOR_URL" "$KUBECTL_CALL_LOG"
}

@test "fails when kubectl is unavailable" {
  export INSTALL_TLS_COMPLIANCE_OPERATOR=true
  rm "$TEST_ROOT/bin/kubectl"

  run env PATH="$TEST_ROOT/bin" /bin/bash "$SCRIPT"

  [ "$status" -eq 1 ]
  [[ "$output" == *"kubectl is not installed"* ]]
}

@test "returns a failure when applying either operator manifest fails" {
  for operator_flag in INSTALL_TLS_COMPLIANCE_OPERATOR INSTALL_IMAGE_CERT_INFO_OPERATOR; do
    : >"$KUBECTL_CALL_LOG"
    export INSTALL_TLS_COMPLIANCE_OPERATOR=false
    export INSTALL_IMAGE_CERT_INFO_OPERATOR=false
    export "$operator_flag=true"
    if [[ "$operator_flag" == "INSTALL_TLS_COMPLIANCE_OPERATOR" ]]; then
      url="$TLS_COMPLIANCE_OPERATOR_URL"
    else
      url="$IMAGE_CERT_INFO_OPERATOR_URL"
    fi
    export FAIL_ON_URL="$url"
    run bash "$SCRIPT"

    [ "$status" -eq 1 ]
    grep -Fq "apply -f $url" "$KUBECTL_CALL_LOG"
  done
}
