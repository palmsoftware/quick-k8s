#!/usr/bin/env bash
set -euo pipefail

echo "::group::Installing sample NetworkPolicy resources"
trap 'echo "::endgroup::"' EXIT

echo "Installing sample network policies in the default namespace..."

if ! command -v kubectl >/dev/null 2>&1; then
  echo "Error: kubectl is not installed." >&2
  exit 1
fi

# Policy 1: Default deny all ingress and egress traffic
kubectl apply -f - <<'EOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: default
spec:
  podSelector: {}
  policyTypes:
    - Ingress
    - Egress
EOF

echo "Applied default-deny-all policy"

# Policy 2: Allow DNS egress to kube-system so pods can still resolve DNS
kubectl apply -f - <<'EOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-dns
  namespace: default
spec:
  podSelector: {}
  policyTypes:
    - Egress
  egress:
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: kube-system
      ports:
        - protocol: UDP
          port: 53
        - protocol: TCP
          port: 53
EOF

echo "Applied allow-dns policy"

# Policy 3: Allow ingress and egress within the same namespace
kubectl apply -f - <<'EOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-same-namespace
  namespace: default
spec:
  podSelector: {}
  policyTypes:
    - Ingress
    - Egress
  ingress:
    - from:
        - podSelector: {}
  egress:
    - to:
        - podSelector: {}
EOF

echo "Applied allow-same-namespace policy"

echo ""
echo "Sample network policies installed successfully:"
kubectl get networkpolicies -n default
