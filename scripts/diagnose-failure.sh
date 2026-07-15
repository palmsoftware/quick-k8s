#!/usr/bin/env bash
# Sourceable utility that diagnoses common Kubernetes component installation
# failures and prints actionable GitHub Actions error annotations.
#
# Usage:
#   source "$(dirname "$0")/diagnose-failure.sh"
#   output=$(kubectl apply -f manifest.yaml 2>&1) || diagnose_failure "Calico" "$output"

diagnose_failure() {
  local component="$1"
  local output="$2"
  local matched=false

  # Disk space exhaustion
  if echo "$output" | grep -qiE "no space left on device|disk pressure|DiskPressure"; then
    echo "::error::${component} installation failed: disk space exhausted. Enable disk cleanup with quick-cleanup or use a larger runner."
    matched=true
  fi

  # OOM / memory pressure
  if echo "$output" | grep -qiE "OOMKill|oom-kill|Cannot allocate memory|MemoryPressure|memory pressure"; then
    echo "::error::${component} installation failed: out of memory. Reduce resource requests, enable swap, or use a larger runner."
    matched=true
  fi

  # Timeout / deadline exceeded
  if echo "$output" | grep -qiE "timeout|timed out|deadline exceeded|context deadline exceeded"; then
    echo "::error::${component} installation timed out. Try increasing COMPONENT_TIMEOUT (current: ${COMPONENT_TIMEOUT:-300}s) or check cluster health with 'kubectl get nodes' and 'kubectl get pods -A'."
    matched=true
  fi

  # Image pull failures
  if echo "$output" | grep -qiE "ImagePullBackOff|ErrImagePull|image pull|failed to pull image|manifest unknown"; then
    echo "::error::${component} installation failed: unable to pull container image. Check that the version exists, your network allows registry access, and no rate limits apply."
    matched=true
  fi

  # CrashLoopBackOff
  if echo "$output" | grep -qiE "CrashLoopBackOff|crash loop"; then
    echo "::error::${component} pods are crash-looping. Check pod logs with 'kubectl logs -n <namespace> <pod>' and events with 'kubectl describe pod'. This may indicate version incompatibility or missing prerequisites."
    matched=true
  fi

  # Network / connectivity issues
  if echo "$output" | grep -qiE "connection refused|connection reset|no route to host|network is unreachable|dial tcp.*timeout|i/o timeout"; then
    echo "::error::${component} installation failed: network connectivity issue. Verify the cluster network is healthy and external URLs are reachable."
    matched=true
  fi

  # DNS resolution failures
  if echo "$output" | grep -qiE "no such host|could not resolve|lookup.*server misbehaving"; then
    echo "::error::${component} installation failed: DNS resolution error. Check that cluster DNS (CoreDNS) is running and the runner has network access."
    matched=true
  fi

  # API version / compatibility issues
  if echo "$output" | grep -qiE "no matches for kind|the server doesn.t have a resource type|unable to recognize|unsupported value|is invalid:.*compilation failed"; then
    echo "::error::${component} installation failed: Kubernetes API incompatibility. The ${component} version may not be compatible with your cluster's Kubernetes version. Try a different ${component} version."
    matched=true
  fi

  # RBAC / permission issues
  if echo "$output" | grep -qiE "forbidden|Forbidden|RBAC|unauthorized|cannot create|cannot patch"; then
    echo "::error::${component} installation failed: insufficient permissions. Ensure the kubeconfig has cluster-admin privileges."
    matched=true
  fi

  # Generic fallback
  if [ "$matched" = false ]; then
    echo "::error::${component} installation failed. Review the error output above. Common causes: resource exhaustion, version incompatibility, or network issues."
  fi
}

# Collects pod status from a namespace to add context to failure diagnostics.
# Call after a kubectl wait failure to show what went wrong.
dump_pod_status() {
  local namespace="$1"
  local component="${2:-}"

  echo "--- ${component:+$component }Pod status in namespace ${namespace} ---"
  kubectl get pods -n "$namespace" -o wide 2>/dev/null || true
  # Show events for non-running pods
  local problem_pods
  problem_pods=$(kubectl get pods -n "$namespace" --no-headers 2>/dev/null \
    | awk '$3 != "Running" && $3 != "Completed" {print $1}') || true
  for pod in $problem_pods; do
    echo "--- Events for pod ${pod} ---"
    kubectl describe pod -n "$namespace" "$pod" 2>/dev/null | tail -20 || true
  done
  echo "---"
}
