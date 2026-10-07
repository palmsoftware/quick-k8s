#!/usr/bin/env bats

source "$BATS_TEST_DIRNAME/../scripts/diagnose-failure.sh"

setup() {
  TEST_TMPDIR=$(mktemp -d)
  export TEST_TMPDIR
  export KUBECTL_CALLS="$TEST_TMPDIR/kubectl-calls"
  mkdir -p "$TEST_TMPDIR/bin"

  cat > "$TEST_TMPDIR/bin/kubectl" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$KUBECTL_CALLS"

case "$*" in
  "get pods -n sample -o wide")
    printf 'NAME READY STATUS RESTARTS AGE IP NODE\nrunning-pod 1/1 Running 0 1m 10.0.0.1 node\nsucceeded-job 0/1 Succeeded 0 1m 10.0.0.2 node\ncompleted-job 0/1 Completed 0 1m 10.0.0.3 node\n'
    ;;
  "get pods -n sample --no-headers")
    printf 'running-pod 1/1 Running 0 1m 10.0.0.1 node\nsucceeded-job 0/1 Succeeded 0 1m 10.0.0.2 node\ncompleted-job 0/1 Completed 0 1m 10.0.0.3 node\n'
    ;;
  "describe pod"*)
    printf 'unexpected pod event lookup\n'
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

@test "dump_pod_status skips event lookups for Running, Succeeded, and Completed pods" {
  run dump_pod_status sample "test component"

  [ "$status" -eq 0 ]
  [[ "$output" != *"Events for pod"* ]]
  ! grep -q '^describe pod ' "$KUBECTL_CALLS"
}
