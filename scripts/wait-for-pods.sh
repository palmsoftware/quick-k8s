#!/bin/bash
set -euo pipefail

echo "::group::Waiting for pods to be ready"
trap 'echo "::endgroup::"' EXIT

if ! command -v kubectl >/dev/null 2>&1; then
  echo "Error: kubectl is not installed." >&2
  exit 1
fi

timeout=1200  # 20 minutes in seconds
elapsed=0
interval=10

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
    echo "All pods are running or completed"
    break
  else
    echo "Waiting for all pods to be running or completed..."
    echo "$pod_output" | awk '{if ($4 != "Running" && $4 != "Completed") print "Pending pod: " $2 " in namespace: " $1}'
    sleep $interval
    elapsed=$((elapsed + interval))
    if [ $elapsed -ge $timeout ]; then
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
