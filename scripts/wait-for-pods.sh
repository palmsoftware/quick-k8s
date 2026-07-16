#!/bin/bash
set -euo pipefail

echo "::group::Waiting for pods to be ready"
trap 'echo "::endgroup::"' EXIT

if ! command -v kubectl >/dev/null 2>&1; then
  echo "Error: kubectl is not installed." >&2
  exit 1
fi

timeout="${WAIT_TIMEOUT:-1200}"  # Default: 20 minutes in seconds
elapsed=0
interval=10

# Format elapsed seconds as human-readable time (e.g., "2m 30s")
format_time() {
  local secs=$1
  local mins=$((secs / 60))
  local rem=$((secs % 60))
  if [ "$mins" -gt 0 ]; then
    echo "${mins}m ${rem}s"
  else
    echo "${rem}s"
  fi
}

# Print a progress summary of pod states
print_pod_progress() {
  local pods=$1
  local time_str=$2

  local total=0
  local ready=0
  local pending=0
  local initializing=0
  local failed=0
  local other=0

  while IFS= read -r line; do
    [ -z "$line" ] && continue
    total=$((total + 1))
    local status
    status=$(echo "$line" | awk '{print $4}')
    case "$status" in
      Running|Completed|Succeeded)
        ready=$((ready + 1))
        ;;
      Pending)
        pending=$((pending + 1))
        ;;
      Init:*|PodInitializing)
        initializing=$((initializing + 1))
        ;;
      Error|CrashLoopBackOff|ImagePullBackOff|ErrImagePull|CreateContainerError|InvalidImageName)
        failed=$((failed + 1))
        ;;
      *)
        other=$((other + 1))
        ;;
    esac
  done <<< "$pods"

  # Build detail string
  local details=""
  if [ "$pending" -gt 0 ]; then
    details="${pending} pending"
  fi
  if [ "$initializing" -gt 0 ]; then
    [ -n "$details" ] && details="${details}, "
    details="${details}${initializing} initializing"
  fi
  if [ "$failed" -gt 0 ]; then
    [ -n "$details" ] && details="${details}, "
    details="${details}${failed} failed"
  fi
  if [ "$other" -gt 0 ]; then
    [ -n "$details" ] && details="${details}, "
    details="${details}${other} other"
  fi

  echo "[${time_str}] Pods: ${ready}/${total} ready (${details})"

  # List pods that are not ready
  echo "$pods" | awk '$4 != "Running" && $4 != "Completed" && $4 != "Succeeded" {
    printf "  Not ready: %-50s %-20s %s\n", $2, $4, "(ns: " $1 ")"
  }'
}

# Build the list of namespaces to monitor
get_namespaces() {
  if [ -n "${WAIT_NAMESPACES:-}" ]; then
    # Include only specified namespaces
    echo "$WAIT_NAMESPACES" | tr ',' '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
  elif [ -n "${EXCLUDE_NAMESPACES:-}" ]; then
    # Get all namespaces and exclude specified ones
    local all_ns
    all_ns=$(kubectl get namespaces --no-headers -o custom-columns=':metadata.name')
    local exclude_list
    exclude_list=$(echo "$EXCLUDE_NAMESPACES" | tr ',' '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    for ns in $all_ns; do
      if ! echo "$exclude_list" | grep -qx "$ns"; then
        echo "$ns"
      fi
    done
  fi
}

# Get pods from the appropriate namespaces
get_pods() {
  local namespaces
  namespaces=$(get_namespaces)

  if [ -z "$namespaces" ]; then
    # No filtering — monitor all namespaces
    kubectl get pods --all-namespaces --no-headers
  else
    # Monitor specific namespaces
    for ns in $namespaces; do
      kubectl get pods -n "$ns" --no-headers 2>/dev/null | awk -v ns="$ns" '{print ns " " $0}'
    done
  fi
}

# Log which namespaces are being monitored
if [ -n "${WAIT_NAMESPACES:-}" ]; then
  echo "Monitoring pods in namespaces: ${WAIT_NAMESPACES}"
elif [ -n "${EXCLUDE_NAMESPACES:-}" ]; then
  echo "Monitoring all namespaces except: ${EXCLUDE_NAMESPACES}"
else
  echo "Monitoring pods in all namespaces"
fi

while true; do
  pod_output=$(get_pods)
  if [ -z "$pod_output" ] || echo "$pod_output" | awk '{if ($4 != "Running" && $4 != "Completed") exit 1}'; then
    time_str=$(format_time "$elapsed")
    echo "[${time_str}] All pods are running or completed"
    break
  else
    time_str=$(format_time "$elapsed")
    print_pod_progress "$pod_output" "$time_str"
    sleep $interval
    elapsed=$((elapsed + interval))
    if [ $elapsed -ge "$timeout" ]; then
      echo "Timeout reached: Not all pods are running or completed"
      echo ""
      echo "=== Pod State Dump (all namespaces) ==="
      kubectl get pods -A
      echo ""
      echo "=== Describing non-Running pods ==="
      kubectl get pods -A --no-headers | awk '$4 != "Running" && $4 != "Completed" && $4 != "Succeeded" {print $1, $2}' | while read -r ns pod; do
        echo "--- Describing ${ns}/${pod} ---"
        kubectl describe pod "$pod" -n "$ns"
        echo ""
      done
      exit 1
    fi
  fi
done
