#!/usr/bin/env bash
set -euo pipefail

# Usage: start-k3s.sh <disable_cni> <api_port> <num_control_plane> <num_workers> <cluster_name> [registry_port]

DISABLE_CNI="${1:-false}"
API_PORT="${2:-6443}"
# $3 (num_control_plane) is validated in action.yml; must be 1
NUM_WORKERS="${4:-0}"
CLUSTER_NAME="${5:-k3s}"
REGISTRY_PORT="${6:-}"

sudo mkdir -p /etc/rancher/k3s

if [ -n "$REGISTRY_PORT" ]; then
  echo "Configuring k3s registry mirror for localhost:${REGISTRY_PORT}..."
  sudo tee /etc/rancher/k3s/registries.yaml > /dev/null <<EOF
mirrors:
  "localhost:${REGISTRY_PORT}":
    endpoint:
      - "http://localhost:${REGISTRY_PORT}"
EOF
fi

K3S_ARGS=(
  server
  "--write-kubeconfig-mode=644"
  "--disable=traefik,servicelb"
  "--node-name=${CLUSTER_NAME}-control-plane"
  "--https-listen-port=${API_PORT}"
  "--tls-san=127.0.0.1"
  "--tls-san=0.0.0.0"
)

if [ "$DISABLE_CNI" = "true" ]; then
  echo "⚠️  k3s: Disabling built-in Flannel CNI"
  K3S_ARGS+=("--flannel-backend=none" "--disable-network-policy")

  # k3s skips CNI plugin binaries when Flannel is disabled, but the base
  # plugins (bridge, loopback, etc.) are still needed by any replacement CNI
  if [ ! -f /opt/cni/bin/bridge ]; then
    echo "Installing CNI plugins (required for replacement CNI)..."
    CNI_VERSION="v1.6.2"
    ARCH=$(uname -m)
    if [ "$ARCH" = "x86_64" ]; then ARCH="amd64"; elif [ "$ARCH" = "aarch64" ]; then ARCH="arm64"; fi
    sudo mkdir -p /opt/cni/bin
    curl -fsSL "https://github.com/containernetworking/plugins/releases/download/${CNI_VERSION}/cni-plugins-linux-${ARCH}-${CNI_VERSION}.tgz" | sudo tar -xz -C /opt/cni/bin
    echo "✅ CNI plugins installed"
  fi

  # Remove any default CNI configs that conflict with the replacement CNI
  sudo rm -f /etc/cni/net.d/*.conflist /etc/cni/net.d/*.conf 2>/dev/null || true
fi

echo "Starting k3s server with command: sudo k3s ${K3S_ARGS[*]}"
sudo k3s "${K3S_ARGS[@]}" &
K3S_PID=$!

echo "Waiting for k3s to be ready..."
max_attempts=60
attempt=1
while [ $attempt -le $max_attempts ]; do
  if [ -f /etc/rancher/k3s/k3s.yaml ] && sudo k3s kubectl get nodes >/dev/null 2>&1; then
    echo "✅ k3s server is ready"
    break
  fi
  if [ $attempt -eq $max_attempts ]; then
    echo "❌ k3s failed to start after ${max_attempts} attempts"
    echo "Checking k3s process status..."
    if ! kill -0 "$K3S_PID" 2>/dev/null; then
      echo "k3s process has exited unexpectedly"
    fi
    exit 1
  fi
  sleep 2
  attempt=$((attempt + 1))
done

mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown "$(id -u):$(id -g)" ~/.kube/config

if [ "$API_PORT" != "6443" ]; then
  sed -i "s|https://127.0.0.1:6443|https://127.0.0.1:${API_PORT}|g" ~/.kube/config
fi

echo "✅ Kubeconfig configured at ~/.kube/config"

echo "Waiting for control plane node to register..."
register_attempts=60
register_attempt=1
while [ $register_attempt -le $register_attempts ]; do
  if sudo k3s kubectl get node "${CLUSTER_NAME}-control-plane" >/dev/null 2>&1; then
    break
  fi
  if [ $register_attempt -eq $register_attempts ]; then
    echo "❌ Control plane node failed to register after ${register_attempts} attempts"
    exit 1
  fi
  sleep 2
  register_attempt=$((register_attempt + 1))
done

# Without CNI, nodes stay NotReady until one is installed (e.g. Calico).
# Remove the not-ready taint so Calico DaemonSet pods can schedule.
if [ "$DISABLE_CNI" = "true" ]; then
  echo "⚠️  CNI disabled — removing not-ready taint so CNI pods can schedule"
  sudo k3s kubectl taint nodes "${CLUSTER_NAME}-control-plane" node.kubernetes.io/not-ready:NoSchedule- 2>/dev/null || true
  sudo k3s kubectl taint nodes "${CLUSTER_NAME}-control-plane" node.kubernetes.io/not-ready:NoExecute- 2>/dev/null || true
  sudo k3s kubectl get nodes
else
  echo "Waiting for control plane node to be Ready..."
  sudo k3s kubectl wait --for=condition=Ready node/"${CLUSTER_NAME}-control-plane" --timeout=120s
fi

if [ "$NUM_WORKERS" -gt 0 ]; then
  echo "Starting ${NUM_WORKERS} worker node(s)..."

  token_attempts=90
  token_attempt=1
  while [ $token_attempt -le $token_attempts ]; do
    if sudo test -f /var/lib/rancher/k3s/server/token; then
      break
    fi
    if [ $token_attempt -eq $token_attempts ]; then
      echo "❌ Node token not available after ${token_attempts} attempts"
      exit 1
    fi
    sleep 1
    token_attempt=$((token_attempt + 1))
  done

  NODE_TOKEN=$(sudo cat /var/lib/rancher/k3s/server/token)

  # Start all agents in parallel
  for i in $(seq 1 "$NUM_WORKERS"); do
    WORKER_NAME="${CLUSTER_NAME}-worker-${i}"
    WORKER_DATA_DIR="/var/lib/rancher/k3s-agent-${i}"

    # Each agent on the same machine needs unique ports to avoid conflicts
    LB_PORT=$((6444 + i))
    KUBELET_PORT=$((10250 + i))

    echo "Starting worker node: ${WORKER_NAME}..."
    sudo k3s agent \
      --server="https://127.0.0.1:${API_PORT}" \
      --token="$NODE_TOKEN" \
      --node-name="$WORKER_NAME" \
      --data-dir="$WORKER_DATA_DIR" \
      --lb-server-port="$LB_PORT" \
      --kubelet-arg="--port=${KUBELET_PORT}" &
  done

  # Wait for all workers to register
  for i in $(seq 1 "$NUM_WORKERS"); do
    WORKER_NAME="${CLUSTER_NAME}-worker-${i}"
    echo "Waiting for ${WORKER_NAME} to register..."
    register_attempts=60
    register_attempt=1
    while [ $register_attempt -le $register_attempts ]; do
      if sudo k3s kubectl get node "$WORKER_NAME" >/dev/null 2>&1; then
        if [ "$DISABLE_CNI" = "true" ]; then
          sudo k3s kubectl taint nodes "$WORKER_NAME" node.kubernetes.io/not-ready:NoSchedule- 2>/dev/null || true
          sudo k3s kubectl taint nodes "$WORKER_NAME" node.kubernetes.io/not-ready:NoExecute- 2>/dev/null || true
        else
          sudo k3s kubectl wait --for=condition=Ready "node/$WORKER_NAME" --timeout=120s
        fi
        break
      fi
      if [ $register_attempt -eq $register_attempts ]; then
        echo "❌ Worker ${WORKER_NAME} failed to register after ${register_attempts} attempts"
        exit 1
      fi
      sleep 2
      register_attempt=$((register_attempt + 1))
    done
    echo "✅ Worker node ${WORKER_NAME} registered"
  done
fi

echo ""
echo "✅ k3s cluster started successfully"
sudo k3s kubectl get nodes
