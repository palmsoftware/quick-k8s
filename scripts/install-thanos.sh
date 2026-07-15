#!/usr/bin/env bash
set -euo pipefail

THANOS_VERSION="${1:-v0.37.2}"
TIMEOUT="${COMPONENT_TIMEOUT:-300}"

# shellcheck source=diagnose-failure.sh
source "$(dirname "$0")/diagnose-failure.sh"

echo "::group::Installing Thanos $THANOS_VERSION"
trap 'echo "::endgroup::"' EXIT

echo "Installing Thanos version $THANOS_VERSION"

# Verify required tools are available
if ! command -v kubectl >/dev/null 2>&1; then
  echo "Error: kubectl is not installed." >&2
  exit 1
fi

# Verify Prometheus is running (Thanos requires it)
if ! kubectl get namespace monitoring >/dev/null 2>&1; then
  echo "::error::Thanos installation failed: monitoring namespace not found. Prometheus (kube-prometheus) must be installed first. Set installPrometheus: true in your action inputs."
  exit 1
fi

# kube-prometheus ships NetworkPolicies that block Thanos Query from reaching the
# Prometheus sidecar gRPC port. Remove them so the monitoring stack works out of the box.
echo "Removing kube-prometheus NetworkPolicies (they block Thanos Query -> sidecar gRPC)..."
kubectl delete networkpolicies --all -n monitoring 2>/dev/null || true

# Patch the Prometheus CR to add Thanos sidecar via the Prometheus Operator's built-in spec.thanos field
echo "Configuring Thanos sidecar on Prometheus..."
patch_output=$(kubectl -n monitoring patch prometheus k8s --type=merge -p "{
  \"spec\": {
    \"thanos\": {
      \"version\": \"${THANOS_VERSION}\",
      \"image\": \"quay.io/thanos/thanos:${THANOS_VERSION}\",
      \"resources\": {
        \"requests\": {
          \"memory\": \"128Mi\",
          \"cpu\": \"100m\"
        },
        \"limits\": {
          \"memory\": \"256Mi\"
        }
      }
    }
  }
}" 2>&1) || {
  echo "$patch_output"
  diagnose_failure "Thanos" "$patch_output"
  exit 1
}
echo "$patch_output"

# Deploy Thanos Query and headless sidecar service
echo "Deploying Thanos Query and services..."
apply_output=$(cat <<EOF | kubectl apply --timeout=5m -f - 2>&1
apiVersion: v1
kind: Service
metadata:
  name: thanos-sidecar
  namespace: monitoring
  labels:
    app.kubernetes.io/name: thanos-sidecar
spec:
  clusterIP: None
  selector:
    app.kubernetes.io/name: prometheus
  ports:
    - name: grpc
      port: 10901
      targetPort: 10901
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: thanos-query
  namespace: monitoring
  labels:
    app.kubernetes.io/name: thanos-query
spec:
  replicas: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: thanos-query
  template:
    metadata:
      labels:
        app.kubernetes.io/name: thanos-query
    spec:
      containers:
        - name: thanos-query
          image: quay.io/thanos/thanos:${THANOS_VERSION}
          args:
            - query
            - --http-address=0.0.0.0:9090
            - --grpc-address=0.0.0.0:10901
            - --endpoint=dnssrv+_grpc._tcp.thanos-sidecar.monitoring.svc.cluster.local
          ports:
            - name: http
              containerPort: 9090
            - name: grpc
              containerPort: 10901
          resources:
            requests:
              memory: 128Mi
              cpu: 100m
            limits:
              memory: 256Mi
---
apiVersion: v1
kind: Service
metadata:
  name: thanos-query
  namespace: monitoring
  labels:
    app.kubernetes.io/name: thanos-query
spec:
  selector:
    app.kubernetes.io/name: thanos-query
  ports:
    - name: http
      port: 9090
      targetPort: http
    - name: grpc
      port: 10901
      targetPort: grpc
EOF
) || {
  echo "$apply_output"
  diagnose_failure "Thanos" "$apply_output"
  exit 1
}
echo "$apply_output"

echo "Waiting for Prometheus to restart with Thanos sidecar..."
rollout_output=$(kubectl rollout status statefulset/prometheus-k8s -n monitoring --timeout="${TIMEOUT}s" 2>&1) || {
  echo "$rollout_output"
  dump_pod_status "monitoring" "Thanos/Prometheus"
  diagnose_failure "Thanos" "$rollout_output"
  exit 1
}
echo "$rollout_output"

echo "Waiting for Thanos Query to be ready..."
rollout_output=$(kubectl rollout status deployment/thanos-query -n monitoring --timeout="${TIMEOUT}s" 2>&1) || {
  echo "$rollout_output"
  dump_pod_status "monitoring" "Thanos Query"
  diagnose_failure "Thanos" "$rollout_output"
  exit 1
}
echo "$rollout_output"

kubectl get pods -n monitoring
echo "Thanos $THANOS_VERSION installed successfully!"
