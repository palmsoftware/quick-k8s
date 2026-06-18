#!/usr/bin/env bash
set -euo pipefail

KUBE_PROMETHEUS_VERSION="${1:-v0.14.0}"

echo "Installing kube-prometheus version $KUBE_PROMETHEUS_VERSION"

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
trap cleanup EXIT

echo "Downloading kube-prometheus from: $TARBALL_URL"

if ! curl -fSL --retry 3 --retry-delay 5 --retry-all-errors "$TARBALL_URL" -o /tmp/kube-prometheus.tar.gz; then
  echo "Error: Failed to download kube-prometheus" >&2
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

echo "Applying kube-prometheus setup manifests (CRDs, namespace)..."
if ! kubectl apply --server-side --timeout=5m -f "${KUBE_PROMETHEUS_DIR}/manifests/setup/"; then
  echo "Error: Failed to apply kube-prometheus setup manifests" >&2
  exit 1
fi

echo "Waiting for CRDs to be established..."
kubectl wait --for condition=Established --all CustomResourceDefinition --timeout=120s

# Apply twice — first pass may fail on CRD-to-CR ordering races
echo "Applying kube-prometheus manifests..."
kubectl apply --timeout=5m -f "${KUBE_PROMETHEUS_DIR}/manifests/" 2>&1 || true
if ! kubectl apply --timeout=5m -f "${KUBE_PROMETHEUS_DIR}/manifests/"; then
  echo "Error: Failed to apply kube-prometheus manifests" >&2
  exit 1
fi

echo "Waiting for monitoring pods to be ready..."
kubectl wait --for=condition=ready pod --all --namespace=monitoring --timeout=300s || {
  echo "Warning: Some monitoring pods may not be ready yet. Continuing..."
}

kubectl get pods -n monitoring
echo "kube-prometheus $KUBE_PROMETHEUS_VERSION installed successfully!"
