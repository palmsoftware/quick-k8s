#!/bin/bash

# Script to remove the control plane taint from the control-plane nodes

# Command precheck
if ! command -v oc >/dev/null 2>&1; then
  echo "Error: oc is not installed." >&2
  exit 1
fi

# Get the list of control-plane nodes
CONTROL_PLANE_NODES=$(oc get nodes --selector=node-role.kubernetes.io/control-plane -o name)
MASTER_NODES=$(oc get nodes --selector=node-role.kubernetes.io/master -o name)

# Remove the control-plane taint from the control-plane nodes
for node in $CONTROL_PLANE_NODES; do
	oc taint nodes "$node" node-role.kubernetes.io/control-plane:NoSchedule-
done

# Remove the master taint from the master nodes (deprecated)
for node in $MASTER_NODES; do
	oc taint nodes "$node" node-role.kubernetes.io/master:NoSchedule-
done
