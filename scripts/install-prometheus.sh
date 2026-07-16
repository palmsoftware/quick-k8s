#!/usr/bin/env bash
set -euo pipefail

KUBE_PROMETHEUS_VERSION="${1:-v0.14.0}"
TIMEOUT="${COMPONENT_TIMEOUT:-300}"

# shellcheck source=diagnose-failure.sh
source "$(dirname "$0")/diagnose-failure.sh"

echo "Installing kube-prometheus version $KUBE_PROMETHEUS_VERSION"

echo "::group::Installing kube-prometheus $KUBE_PROMETHEUS_VERSION"

# Wait for CNI to be fully ready before deploying the monitoring stack.
# kube-prometheus creates many pods at once; if Calico hasn't finished
# initializing, pod sandbox creation fails and containers CrashLoop.
if kubectl get daemonset calico-node -n kube-system &>/dev/null; then
  echo "Waiting for Calico CNI to be fully ready..."
  kubectl rollout status daemonset/calico-node -n kube-system --timeout=120s || true
fi

# Verify required tools are available
for cmd in curl kubectl tar; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Error: $cmd is not installed." >&2
    exit 1
  fi
done

VERSION_NO_V="${KUBE_PROMETHEUS_VERSION#v}"
TARBALL_URL="https://github.com/prometheus-operator/kube-prometheus/archive/refs/tags/${KUBE_PROMETHEUS_VERSION}.tar.gz"
KUBE_PROMETHEUS_DIR="/tmp/kube-prometheus-${VERSION_NO_V}"

cleanup() { rm -rf /tmp/kube-prometheus.tar.gz "${KUBE_PROMETHEUS_DIR}"; }
trap 'cleanup; echo "::endgroup::"' EXIT

echo "Downloading kube-prometheus from: $TARBALL_URL"

if ! curl -fSL --retry 3 --retry-delay 5 --retry-all-errors "$TARBALL_URL" -o /tmp/kube-prometheus.tar.gz; then
  echo "::error::Failed to download kube-prometheus from $TARBALL_URL. Check network connectivity or verify the version exists."
  exit 1
fi

tar -xzf /tmp/kube-prometheus.tar.gz -C /tmp

# Reduce resource requests so the stack fits on free-tier CI runners (~7GB RAM)
echo "Patching resource requests for CI environment..."
grep -rl 'memory:\|cpu:' "${KUBE_PROMETHEUS_DIR}/manifests/" --include="*.yaml" | xargs sed -i \
  -e 's/memory: 2Gi/memory: 256Mi/g' \
  -e 's/memory: 1Gi/memory: 256Mi/g' \
  -e 's/memory: 400Mi/memory: 128Mi/g' \
  -e 's/memory: 200Mi/memory: 128Mi/g' \
  -e 's/cpu: 500m/cpu: 100m/g' \
  -e 's/cpu: "2"/cpu: 200m/g'

# Scale down Grafana to 0 replicas — it's too resource-heavy for free-tier
# runners and is not required to validate core monitoring functionality.
GRAFANA_DEPLOY="${KUBE_PROMETHEUS_DIR}/manifests/grafana-deployment.yaml"
if [ -f "$GRAFANA_DEPLOY" ]; then
  echo "Scaling down Grafana (too resource-heavy for CI runners)..."
  sed -i 's/replicas: 1/replicas: 0/' "$GRAFANA_DEPLOY"
fi

echo "Applying kube-prometheus setup manifests (CRDs, namespace)..."
setup_output=$(kubectl apply --server-side --timeout=5m -f "${KUBE_PROMETHEUS_DIR}/manifests/setup/" 2>&1) || {
  echo "$setup_output"
  diagnose_failure "kube-prometheus" "$setup_output"
  exit 1
}
echo "$setup_output"

echo "Waiting for CRDs to be established..."
kubectl wait --for condition=Established --all CustomResourceDefinition --timeout=120s

# Apply twice — first pass may fail on CRD-to-CR ordering races
echo "Applying kube-prometheus manifests..."
kubectl apply --timeout=5m -f "${KUBE_PROMETHEUS_DIR}/manifests/" 2>&1 || true
apply_output=$(kubectl apply --timeout=5m -f "${KUBE_PROMETHEUS_DIR}/manifests/" 2>&1) || {
  echo "$apply_output"
  diagnose_failure "kube-prometheus" "$apply_output"
  exit 1
}
echo "$apply_output"

echo "Waiting for monitoring pods to be ready..."
wait_output=$(kubectl wait --for=condition=ready pod --all --namespace=monitoring --timeout="${TIMEOUT}s" 2>&1) || {
  echo "$wait_output"
  dump_pod_status "monitoring" "kube-prometheus"
  diagnose_failure "kube-prometheus" "$wait_output"
  exit 1
}
echo "$wait_output"

kubectl get pods -n monitoring
echo "kube-prometheus $KUBE_PROMETHEUS_VERSION installed successfully!"
