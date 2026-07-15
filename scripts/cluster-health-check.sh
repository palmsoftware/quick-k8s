#!/usr/bin/env bash
set -euo pipefail

# Verify cluster health after creation and before component installation.
# Checks: API server, node readiness, kube-system pods, CoreDNS.

TIMEOUT="${HEALTH_CHECK_TIMEOUT:-120}"
INTERVAL=5

echo "::group::Cluster health check"
trap 'echo "::endgroup::"' EXIT

if ! command -v kubectl >/dev/null 2>&1; then
  echo "::error::kubectl is not installed, cannot perform health check"
  exit 1
fi

# --- API server ---
echo "Checking API server connectivity..."
elapsed=0
while true; do
  if kubectl cluster-info >/dev/null 2>&1; then
    echo "API server is responding"
    break
  fi
  elapsed=$((elapsed + INTERVAL))
  if [ "$elapsed" -ge "$TIMEOUT" ]; then
    echo "::error::API server did not respond within ${TIMEOUT}s"
    kubectl cluster-info 2>&1 || true
    exit 1
  fi
  echo "  Waiting for API server... (${elapsed}s/${TIMEOUT}s)"
  sleep "$INTERVAL"
done

# --- Node readiness ---
echo "Checking node readiness..."
elapsed=0
while true; do
  not_ready=$(kubectl get nodes --no-headers 2>/dev/null \
    | awk '$2 != "Ready" {print $1}') || true
  if [ -z "$not_ready" ]; then
    node_count=$(kubectl get nodes --no-headers 2>/dev/null | wc -l)
    if [ "$node_count" -gt 0 ]; then
      echo "All $node_count node(s) are Ready"
      break
    fi
  fi
  elapsed=$((elapsed + INTERVAL))
  if [ "$elapsed" -ge "$TIMEOUT" ]; then
    echo "::error::Not all nodes became Ready within ${TIMEOUT}s"
    echo "Node status:"
    kubectl get nodes 2>/dev/null || true
    for node in $not_ready; do
      echo "--- Describing node $node ---"
      kubectl describe node "$node" 2>/dev/null | tail -30 || true
    done
    exit 1
  fi
  echo "  Waiting for nodes to be Ready... (${elapsed}s/${TIMEOUT}s)"
  if [ -n "$not_ready" ]; then
    echo "  Not ready: $not_ready"
  fi
  sleep "$INTERVAL"
done

# --- Core kube-system pods ---
echo "Checking kube-system pods..."
elapsed=0
while true; do
  bad_pods=$(kubectl get pods -n kube-system --no-headers 2>/dev/null \
    | awk '$3 != "Running" && $3 != "Completed" && $3 != "Succeeded" {
        print $1, $3
      }') || true
  if [ -z "$bad_pods" ]; then
    pod_count=$(kubectl get pods -n kube-system --no-headers 2>/dev/null | wc -l)
    if [ "$pod_count" -gt 0 ]; then
      echo "All $pod_count kube-system pod(s) are healthy"
      break
    fi
  fi
  elapsed=$((elapsed + INTERVAL))
  if [ "$elapsed" -ge "$TIMEOUT" ]; then
    echo "::error::Not all kube-system pods became healthy within ${TIMEOUT}s"
    echo "Pod status:"
    kubectl get pods -n kube-system 2>/dev/null || true
    exit 1
  fi
  echo "  Waiting for kube-system pods... (${elapsed}s/${TIMEOUT}s)"
  if [ -n "$bad_pods" ]; then
    echo "$bad_pods" | while read -r pod status; do
      echo "    $pod ($status)"
    done
  fi
  sleep "$INTERVAL"
done

# --- CoreDNS / kube-dns ---
echo "Checking CoreDNS availability..."
elapsed=0
while true; do
  dns_running=$(kubectl get pods -n kube-system --no-headers 2>/dev/null \
    | grep -E '(coredns|kube-dns)' \
    | awk '$3 == "Running" {print $1}') || true
  if [ -n "$dns_running" ]; then
    dns_count=$(echo "$dns_running" | wc -l)
    echo "CoreDNS is running ($dns_count instance(s))"
    break
  fi
  elapsed=$((elapsed + INTERVAL))
  if [ "$elapsed" -ge "$TIMEOUT" ]; then
    echo "::error::CoreDNS did not reach Running state within ${TIMEOUT}s"
    echo "DNS-related pods:"
    kubectl get pods -n kube-system 2>/dev/null \
      | grep -E '(coredns|kube-dns|NAME)' || true
    exit 1
  fi
  echo "  Waiting for CoreDNS... (${elapsed}s/${TIMEOUT}s)"
  sleep "$INTERVAL"
done

echo ""
echo "Cluster health check passed"
