#!/usr/bin/env bash
# Sourceable utility that diagnoses common Kubernetes component installation
# failures and prints actionable GitHub Actions error annotations.
#
# Usage:
#   source "$(dirname "$0")/diagnose-failure.sh"
#   output=$(kubectl apply -f manifest.yaml 2>&1) || diagnose_failure "Calico" "$output"

write_failure_summary() {
  local component="$1"
  local category="$2"
  local message="$3"
  if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
    {
      echo "## :x: ${component} Installation Failed"
      echo ""
      echo "**Category:** ${category}"
      echo ""
      echo "${message}"
      echo ""
    } >> "$GITHUB_STEP_SUMMARY"
  fi
}

diagnose_failure() {
  local component="$1"
  local output="$2"
  local matched=false
  local summary_written=false

  # Disk space exhaustion
  if echo "$output" | grep -qiE "no space left on device|disk pressure|DiskPressure"; then
    echo "::error::${component} installation failed: disk space exhausted. Enable disk cleanup with quick-cleanup or use a larger runner."
    if [ "$summary_written" = false ]; then
      write_failure_summary "$component" "Disk Space Exhaustion" "Disk space exhausted. Enable disk cleanup with quick-cleanup or use a larger runner."
      summary_written=true
    fi
    matched=true
  fi

  # OOM / memory pressure
  if echo "$output" | grep -qiE "OOMKill|oom-kill|Cannot allocate memory|MemoryPressure|memory pressure"; then
    echo "::error::${component} installation failed: out of memory. Reduce resource requests, enable swap, or use a larger runner."
    if [ "$summary_written" = false ]; then
      write_failure_summary "$component" "Out of Memory" "Out of memory. Reduce resource requests, enable swap, or use a larger runner."
      summary_written=true
    fi
    matched=true
  fi

  # Timeout / deadline exceeded
  if echo "$output" | grep -qiE "timeout|timed out|deadline exceeded|context deadline exceeded"; then
    echo "::error::${component} installation timed out. Try increasing COMPONENT_TIMEOUT (current: ${COMPONENT_TIMEOUT:-300}s) or check cluster health with 'kubectl get nodes' and 'kubectl get pods -A'."
    if [ "$summary_written" = false ]; then
      write_failure_summary "$component" "Timeout" "Installation timed out (COMPONENT_TIMEOUT: ${COMPONENT_TIMEOUT:-300}s). Try increasing the timeout or check cluster health."
      summary_written=true
    fi
    matched=true
  fi

  # Image pull failures
  if echo "$output" | grep -qiE "ImagePullBackOff|ErrImagePull|image pull|failed to pull image|manifest unknown"; then
    echo "::error::${component} installation failed: unable to pull container image. Check that the version exists, your network allows registry access, and no rate limits apply."
    if [ "$summary_written" = false ]; then
      write_failure_summary "$component" "Image Pull Failure" "Unable to pull container image. Check that the version exists, your network allows registry access, and no rate limits apply."
      summary_written=true
    fi
    matched=true
  fi

  # CrashLoopBackOff
  if echo "$output" | grep -qiE "CrashLoopBackOff|crash loop"; then
    echo "::error::${component} pods are crash-looping. Check pod logs with 'kubectl logs -n <namespace> <pod>' and events with 'kubectl describe pod'. This may indicate version incompatibility or missing prerequisites."
    if [ "$summary_written" = false ]; then
      write_failure_summary "$component" "CrashLoopBackOff" "Pods are crash-looping. This may indicate version incompatibility or missing prerequisites."
      summary_written=true
    fi
    matched=true
  fi

  # Network / connectivity issues
  if echo "$output" | grep -qiE "connection refused|connection reset|no route to host|network is unreachable|dial tcp.*timeout|i/o timeout"; then
    echo "::error::${component} installation failed: network connectivity issue. Verify the cluster network is healthy and external URLs are reachable."
    if [ "$summary_written" = false ]; then
      write_failure_summary "$component" "Network Connectivity" "Network connectivity issue. Verify the cluster network is healthy and external URLs are reachable."
      summary_written=true
    fi
    matched=true
  fi

  # DNS resolution failures
  if echo "$output" | grep -qiE "no such host|could not resolve|lookup.*server misbehaving"; then
    echo "::error::${component} installation failed: DNS resolution error. Check that cluster DNS (CoreDNS) is running and the runner has network access."
    if [ "$summary_written" = false ]; then
      write_failure_summary "$component" "DNS Resolution" "DNS resolution error. Check that cluster DNS (CoreDNS) is running and the runner has network access."
      summary_written=true
    fi
    matched=true
  fi

  # API version / compatibility issues
  if echo "$output" | grep -qiE "no matches for kind|the server doesn.t have a resource type|unable to recognize|unsupported value|is invalid:.*compilation failed"; then
    echo "::error::${component} installation failed: Kubernetes API incompatibility. The ${component} version may not be compatible with your cluster's Kubernetes version. Try a different ${component} version."
    if [ "$summary_written" = false ]; then
      write_failure_summary "$component" "API Incompatibility" "Kubernetes API incompatibility. The ${component} version may not be compatible with your cluster's Kubernetes version."
      summary_written=true
    fi
    matched=true
  fi

  # RBAC / permission issues
  if echo "$output" | grep -qiE "forbidden|Forbidden|RBAC|unauthorized|cannot create|cannot patch"; then
    echo "::error::${component} installation failed: insufficient permissions. Ensure the kubeconfig has cluster-admin privileges."
    if [ "$summary_written" = false ]; then
      write_failure_summary "$component" "Insufficient Permissions" "Insufficient permissions. Ensure the kubeconfig has cluster-admin privileges."
      summary_written=true
    fi
    matched=true
  fi

  # Generic fallback
  if [ "$matched" = false ]; then
    echo "::error::${component} installation failed. Review the error output above. Common causes: resource exhaustion, version incompatibility, or network issues."
    write_failure_summary "$component" "Unknown" "Installation failed. Common causes: resource exhaustion, version incompatibility, or network issues."
  fi
}

# Waits for pods to be ready with retry, handling pod recreation during startup.
# Usage: wait_for_pods_ready <namespace> <component_label> <timeout> [kubectl_wait_args...]
wait_for_pods_ready() {
  local namespace="$1" component="$2" timeout="$3"
  shift 3
  local end_time=$((SECONDS + timeout)) last_err=""
  while [ $SECONDS -lt $end_time ]; do
    local remaining=$((end_time - SECONDS))
    local wait_timeout=$((remaining < 30 ? remaining : 30))
    last_err=$(kubectl wait --for=condition=ready pod --namespace="$namespace" \
      --timeout="${wait_timeout}s" "$@" 2>&1) && {
      echo "All pods in namespace $namespace are ready"
      return 0
    }
    sleep 5
  done
  echo "$last_err"
  dump_pod_status "$namespace" "$component"
  diagnose_failure "$component" "$last_err"
  return 1
}

# Collects pod status from a namespace to add context to failure diagnostics.
# Call after a kubectl wait failure to show what went wrong.
dump_pod_status() {
  local namespace="$1"
  local component="${2:-}"

  echo "--- ${component:+$component }Pod status in namespace ${namespace} ---"
  local pod_table
  pod_table=$(kubectl get pods -n "$namespace" -o wide 2>/dev/null) || true
  echo "$pod_table"

  local problem_pods
  problem_pods=$(kubectl get pods -n "$namespace" --no-headers 2>/dev/null \
    | awk '$3 != "Running" && $3 != "Completed" {print $1}') || true
  local pod_events=""
  for pod in $problem_pods; do
    echo "--- Events for pod ${pod} ---"
    local events
    events=$(kubectl describe pod -n "$namespace" "$pod" 2>/dev/null | tail -20) || true
    echo "$events"
    pod_events="${pod_events}### ${pod}\n\`\`\`\n${events}\n\`\`\`\n"
  done
  echo "---"

  if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
    {
      echo "<details>"
      echo "<summary>${component:+$component }Pod Status (${namespace})</summary>"
      echo ""
      echo "\`\`\`"
      echo "$pod_table"
      echo "\`\`\`"
      if [ -n "$pod_events" ]; then
        echo ""
        echo -e "$pod_events"
      fi
      echo "</details>"
      echo ""
    } >> "$GITHUB_STEP_SUMMARY"
  fi
}
