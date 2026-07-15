#!/usr/bin/env bash
set -euo pipefail

CERT_MANAGER_VERSION="${1:-v1.19.3}"
TIMEOUT="${COMPONENT_TIMEOUT:-300}"

echo "Installing cert-manager version $CERT_MANAGER_VERSION"

# Verify required tools are available
for cmd in curl kubectl; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Error: $cmd is not installed." >&2
    exit 1
  fi
done

MANIFEST_URL="https://github.com/cert-manager/cert-manager/releases/download/${CERT_MANAGER_VERSION}/cert-manager.yaml"
echo "Downloading cert-manager manifest from: $MANIFEST_URL"

if ! kubectl apply --timeout=5m -f "$MANIFEST_URL"; then
  echo "Error: Failed to apply cert-manager manifest" >&2
  exit 1
fi

echo "Waiting for cert-manager pods to be ready..."
kubectl wait --for=condition=ready pod --all --namespace=cert-manager --timeout="${TIMEOUT}s" || {
  echo "Warning: Some cert-manager pods may not be ready yet. Continuing..."
}

kubectl get pods -n cert-manager
echo "cert-manager $CERT_MANAGER_VERSION installed successfully!"

echo "Creating self-signed ClusterIssuer for TLS testing..."
kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: selfsigned-issuer
spec:
  selfSigned: {}
EOF

echo "Waiting for ClusterIssuer to be ready..."
kubectl wait --for=condition=Ready clusterissuer/selfsigned-issuer --timeout=60s || {
  echo "Warning: ClusterIssuer may not be ready yet. Current status:"
  kubectl get clusterissuer selfsigned-issuer -o wide 2>/dev/null || true
}

echo "Self-signed ClusterIssuer configured successfully!"
