#!/usr/bin/env bash

# Script to clean up Kubernetes cluster resources created by quick-k8s
#
# Reads configuration from environment variables set during action execution:
#   QUICK_K8S_PROVIDER     - Cluster provider (kind, minikube, k3s)
#   QUICK_K8S_CLUSTER_NAME - Name of the cluster
#
# This script is copied to /tmp/quick-k8s-cleanup.sh during action setup.
# Add to your workflow as a post-job cleanup step:
#
#   - name: Cleanup cluster
#     if: always()
#     run: /tmp/quick-k8s-cleanup.sh
#
# The script is intentionally lenient with errors — cleanup should never
# cause a workflow failure.

PROVIDER="${QUICK_K8S_PROVIDER:-}"
CLUSTER_NAME="${QUICK_K8S_CLUSTER_NAME:-}"

if [ -z "$PROVIDER" ]; then
  echo "QUICK_K8S_PROVIDER not set, skipping cleanup"
  exit 0
fi

if [ -z "$CLUSTER_NAME" ]; then
  echo "QUICK_K8S_CLUSTER_NAME not set, skipping cleanup"
  exit 0
fi

echo "::group::Quick-K8s Cluster Cleanup"

echo "Cleaning up $PROVIDER cluster '$CLUSTER_NAME'..."

case "$PROVIDER" in
  kind)
    if command -v kind &>/dev/null; then
      echo "Deleting KinD cluster '$CLUSTER_NAME'..."
      kind delete cluster --name "$CLUSTER_NAME" 2>/dev/null || true
      echo "KinD cluster deleted"
    else
      echo "KinD binary not found, skipping cluster deletion"
    fi
    ;;
  minikube)
    if command -v minikube &>/dev/null; then
      echo "Deleting Minikube cluster '$CLUSTER_NAME'..."
      if [ "$CLUSTER_NAME" != "minikube" ]; then
        minikube delete --profile "$CLUSTER_NAME" 2>/dev/null || true
      else
        minikube delete 2>/dev/null || true
      fi
      echo "Minikube cluster deleted"
    else
      echo "Minikube binary not found, skipping cluster deletion"
    fi
    ;;
  k3s)
    echo "Stopping k3s..."
    if [ -x /usr/local/bin/k3s-killall.sh ]; then
      /usr/local/bin/k3s-killall.sh 2>/dev/null || true
    fi
    if [ -x /usr/local/bin/k3s-uninstall.sh ]; then
      /usr/local/bin/k3s-uninstall.sh 2>/dev/null || true
    fi
    echo "k3s stopped and uninstalled"
    ;;
  *)
    echo "Unknown provider '$PROVIDER', skipping cluster cleanup"
    ;;
esac

# Clean up local registry container if it exists
REGISTRY_NAME="quick-k8s-registry"
if command -v docker &>/dev/null; then
  if docker ps -a --format '{{.Names}}' 2>/dev/null | grep -q "^${REGISTRY_NAME}$"; then
    echo "Removing local registry container..."
    docker rm -f "$REGISTRY_NAME" 2>/dev/null || true
  fi
fi

# Remove temporary files created by the action
echo "Removing temporary files..."
rm -f /tmp/quick-k8s-cleanup.sh 2>/dev/null || true

echo "::endgroup::"
echo "Cluster cleanup complete"
