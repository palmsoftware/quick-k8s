#!/usr/bin/env bash

# Pre-Cluster Container Optimization for GitHub Actions Runners
# This script performs final Docker and containerd cleanup immediately
# before creating the kind cluster to maximize available resources.

set -e

echo "=============================================="
echo "⚡ FINAL PRE-CLUSTER OPTIMIZATION"
echo "=============================================="
START_TIME=$(date +%s)
echo "Started at: $(date)"
df -h

echo "=== Aggressive Docker cleanup ==="
# Stop all containers and remove everything
docker ps -aq | xargs -r docker stop || true
docker ps -aq | xargs -r docker rm -f || true
docker images -aq | xargs -r docker rmi -f || true
docker volume ls -q | xargs -r docker volume rm || true
docker network ls --filter type=custom -q | xargs -r docker network rm || true
docker system prune -af --volumes || true

echo "=== Comprehensive containerd cleanup ==="
if command -v ctr &> /dev/null; then
  # Clean all namespaces
  for ns in $(sudo ctr namespace ls -q); do
    echo "Cleaning namespace: $ns"
    sudo ctr -n "$ns" container ls -q | xargs -r sudo ctr -n "$ns" container rm || true
    sudo ctr -n "$ns" image ls -q | xargs -r sudo ctr -n "$ns" image rm || true
    sudo ctr -n "$ns" snapshot ls -q | xargs -r sudo ctr -n "$ns" snapshot rm || true
  done
fi

echo "=== Deep containerd storage cleanup ==="
sudo systemctl stop containerd || true
if [ -d /var/lib/containerd ]; then
  sudo rm -rf /var/lib/containerd/io.containerd.content.v1.content/blobs/* || true
  sudo rm -rf /var/lib/containerd/io.containerd.content.v1.content/ingest/* || true
  sudo rm -rf /var/lib/containerd/io.containerd.snapshotter.v1.overlayfs/snapshots/* || true
  sudo rm -rf /var/lib/containerd/io.containerd.snapshotter.v1.overlayfs/metadata.db || true
  sudo rm -rf /var/lib/containerd/tmpmounts/* || true
fi
sudo systemctl start containerd || true

echo "=== Validate storage configuration ==="
if [ -d /mnt/docker-storage ]; then
  STORAGE_SIZE=$(sudo du -sh /mnt/docker-storage 2>/dev/null | cut -f1 || echo "unknown")
  echo "✓ Docker storage directory exists: ${STORAGE_SIZE}"
  STORAGE_AVAILABLE_KB=$(df /mnt | tail -1 | awk '{print $4}')
  STORAGE_AVAILABLE_GB=$((STORAGE_AVAILABLE_KB / 1024 / 1024))
  echo "✓ Storage partition available: ${STORAGE_AVAILABLE_GB}GB"
else
  echo "⚠ Docker storage not yet configured"
fi

echo "=== Final optimization results ==="
df -h
echo ""
echo "📊 SYSTEM STATE AFTER OPTIMIZATION"
echo "├─ Memory: $(free -h | grep '^Mem:' | awk '{print $3 "/" $2 " used"}')"
echo "├─ Disk: $(df -h / | tail -1 | awk '{print $4 " available"}')"
echo "└─ Docker storage: $(df -h /mnt | tail -1 | awk '{print $4 " available"}')"

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
echo ""
echo "⏱️  Optimization completed in ${DURATION}s"
echo "=============================================="
