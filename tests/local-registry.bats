#!/usr/bin/env bats

setup() {
  TEST_TMPDIR=$(mktemp -d)
  export TEST_TMPDIR
  mkdir -p "$TEST_TMPDIR/bin"
}

teardown() {
  rm -rf "$TEST_TMPDIR"
}

create_local_registry_mocks() {
  export DOCKER_CALLS="$TEST_TMPDIR/docker-calls"
  export KIND_CALLS="$TEST_TMPDIR/kind-calls"
  export HOSTS_TOML_CAPTURE="$TEST_TMPDIR/hosts.toml"
  export KUBECTL_MANIFEST="$TEST_TMPDIR/manifest.yaml"

  cat > "$TEST_TMPDIR/bin/docker" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$DOCKER_CALLS"
case "$1" in
  ps) ;;
  run) printf 'registry-container-id\n' ;;
  exec)
    if [ "${2:-}" = "-i" ]; then
      cat > "$HOSTS_TOML_CAPTURE"
    fi
    ;;
esac
EOF

  cat > "$TEST_TMPDIR/bin/kind" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$KIND_CALLS"
if [ "${KIND_EXIT:-0}" -ne 0 ]; then
  exit "$KIND_EXIT"
fi
printf 'custom-control-plane\ncustom-worker\n'
EOF

  cat > "$TEST_TMPDIR/bin/curl" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF

  cat > "$TEST_TMPDIR/bin/kubectl" <<'EOF'
#!/usr/bin/env bash
cat > "$KUBECTL_MANIFEST"
EOF

  chmod +x "$TEST_TMPDIR/bin/"*
  PATH="$TEST_TMPDIR/bin:$PATH"
  export PATH
}

@test "generate-kind-config enables containerd registry config when requested" {
  kind_config="$TEST_TMPDIR/kind.yaml"

  run "$BATS_TEST_DIRNAME/../scripts/generate-kind-config.sh" \
    6443 127.0.0.1 false ipv4 kindest/node:v1.37.0 1 1 "$kind_config" custom true

  [ "$status" -eq 0 ]
  grep -Fq 'containerdConfigPatches:' "$kind_config"
  grep -Fq 'config_path = "/etc/containerd/certs.d"' "$kind_config"
}

@test "generate-kind-config omits containerd registry config when disabled" {
  kind_config="$TEST_TMPDIR/kind.yaml"

  run "$BATS_TEST_DIRNAME/../scripts/generate-kind-config.sh" \
    6443 127.0.0.1 false ipv4 kindest/node:v1.37.0 1 1 "$kind_config" custom false

  [ "$status" -eq 0 ]
  ! grep -Fq 'containerdConfigPatches:' "$kind_config"
}

@test "setup-local-registry configures every KinD node and preserves the hosting ConfigMap" {
  create_local_registry_mocks

  run "$BATS_TEST_DIRNAME/../scripts/setup-local-registry.sh" 5010 kind custom

  [ "$status" -eq 0 ]
  grep -Fq 'network connect kind quick-k8s-registry' "$DOCKER_CALLS"
  grep -Fq 'custom-control-plane mkdir -p /etc/containerd/certs.d/localhost:5010' "$DOCKER_CALLS"
  grep -Fq 'custom-worker mkdir -p /etc/containerd/certs.d/localhost:5010' "$DOCKER_CALLS"
  grep -Fq 'get nodes --name custom' "$KIND_CALLS"
  grep -Fq '[host."http://quick-k8s-registry:5000"]' "$HOSTS_TOML_CAPTURE"
  grep -Fq 'name: local-registry-hosting' "$KUBECTL_MANIFEST"
  grep -Fq 'host: "localhost:5010"' "$KUBECTL_MANIFEST"
}

@test "setup-local-registry fails when KinD cannot list cluster nodes" {
  create_local_registry_mocks
  export KIND_EXIT=1

  run "$BATS_TEST_DIRNAME/../scripts/setup-local-registry.sh" 5010 kind custom

  [ "$status" -ne 0 ]
  [[ "$output" == *"Failed to list KinD nodes for cluster 'custom'"* ]]
  [ ! -e "$KUBECTL_MANIFEST" ]
}
