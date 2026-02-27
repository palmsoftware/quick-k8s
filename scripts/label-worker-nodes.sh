#!/bin/bash

# Script to apply labels to worker nodes after cluster creation
# Usage: label-worker-nodes.sh <expected-worker-count> <comma-separated-labels>
# Example: label-worker-nodes.sh 2 "node-role.kubernetes.io/worker=worker,env=test"

EXPECTED_WORKERS=${1:?"Usage: $0 <expected-worker-count> <comma-separated-labels>"}
LABELS_CSV=${2:?"Usage: $0 <expected-worker-count> <comma-separated-labels>"}

# Command precheck
if ! command -v oc >/dev/null 2>&1; then
  echo "Error: oc is not installed." >&2
  exit 1
fi

echo "Applying labels to worker nodes..."
echo "Waiting for ${EXPECTED_WORKERS} worker node(s) to be registered..."

# Wait for worker nodes to appear (up to 120 seconds)
WORKER_NODES=""
for i in $(seq 1 60); do
  # List all nodes and filter out control-plane nodes by ROLES column
  ALL_OUTPUT=$(oc get nodes --no-headers 2>&1 || true)
  WORKER_NODES=$(echo "$ALL_OUTPUT" | grep -v "control-plane" | awk 'NF{print $1}' || true)

  if [ -n "$WORKER_NODES" ]; then
    COUNT=$(echo "$WORKER_NODES" | wc -l | tr -d ' ')
  else
    COUNT=0
  fi

  if [ "$COUNT" -ge "$EXPECTED_WORKERS" ]; then
    echo "  Found $COUNT worker node(s): $(echo "$WORKER_NODES" | tr '\n' ' ')"
    break
  fi

  if [ $((i % 5)) -eq 0 ]; then
    echo "  Found $COUNT/$EXPECTED_WORKERS worker nodes (attempt $i/60), waiting..."
  fi
  sleep 2
done

if [ -z "$WORKER_NODES" ]; then
  echo "ERROR: No worker nodes found after waiting 120s"
  oc get nodes || true
  exit 1
fi

# Apply labels to each worker node
IFS=',' read -ra LABELS <<< "$LABELS_CSV"
for NODE in $WORKER_NODES; do
  for LABEL in "${LABELS[@]}"; do
    LABEL=$(echo "$LABEL" | xargs)
    echo "  Labeling node $NODE with $LABEL"
    oc label node "$NODE" "$LABEL" --overwrite
  done
done

echo "Worker node labels applied successfully"
