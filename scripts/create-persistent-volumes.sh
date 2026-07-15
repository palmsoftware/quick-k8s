#!/usr/bin/env bash
set -euo pipefail

PV_COUNT="${1:-5}"
PV_SIZE="${2:-10Gi}"

echo "::group::Creating $PV_COUNT PersistentVolumes ($PV_SIZE each)"
trap 'echo "::endgroup::"' EXIT

# Verify kubectl is available
if ! command -v kubectl >/dev/null 2>&1; then
  echo "Error: kubectl is not installed." >&2
  exit 1
fi

# Create a StorageClass for the test PVs
echo "Creating test-local StorageClass..."
kubectl apply -f - <<EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: test-local
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: WaitForFirstConsumer
reclaimPolicy: Delete
EOF

# Create PersistentVolumes
for i in $(seq 1 "$PV_COUNT"); do
  PV_NAME="test-pv-${i}"
  HOST_PATH="/tmp/test-pvs/${PV_NAME}"

  echo "Creating PersistentVolume: $PV_NAME ($PV_SIZE)"
  kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolume
metadata:
  name: ${PV_NAME}
  labels:
    type: test-local
spec:
  capacity:
    storage: ${PV_SIZE}
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Delete
  storageClassName: test-local
  hostPath:
    path: ${HOST_PATH}
    type: DirectoryOrCreate
EOF
done

echo ""
echo "Created $PV_COUNT PersistentVolumes:"
kubectl get pv -l type=test-local
echo ""
echo "StorageClass:"
kubectl get storageclass test-local
echo ""
echo "PersistentVolumes created successfully!"
