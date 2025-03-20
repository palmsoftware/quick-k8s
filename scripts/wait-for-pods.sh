#!/bin/bash

timeout=600  # 10 minutes in seconds
elapsed=0
interval=10

while true; do
  if oc get pods --all-namespaces --no-headers | awk '{if ($4 != "Running" && $4 != "Completed") exit 1}'; then
    echo "All pods are running or completed"
    break
  else
    echo "Waiting for all pods to be running or completed..."
    oc get pods --all-namespaces --no-headers | awk '{if ($4 != "Running" && $4 != "Completed") print "Pending pod: " $1 " in namespace: " $2}'
    sleep $interval
    elapsed=$((elapsed + interval))
    if [ $elapsed -ge $timeout ]; then
      echo "Timeout reached: Not all pods are running or completed"
      exit 1
    fi
  fi
done
