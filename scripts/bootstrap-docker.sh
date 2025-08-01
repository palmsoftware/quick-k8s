#!/usr/bin/env bash

for cmd in curl tar; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Error: $cmd is not installed." >&2
    exit 1
  fi
done

# create the docker daemon json file if it does not exist
if [ ! -f /etc/docker/daemon.json ]; then
  echo '{}' | sudo tee /etc/docker/daemon.json
fi

# update docker config to include ipv6 support
jq '. +={"ipv6": true, "fixed-cidr-v6": "2001:db8:1::/64"}' /etc/docker/daemon.json > /tmp/new-docker-daemon.json
sudo cp /tmp/new-docker-daemon.json /etc/docker/daemon.json
rm /tmp/new-docker-daemon.json

# restart docker
sudo systemctl restart docker

# increase file system limits
sudo sysctl fs.inotify.max_user_watches=524288
sudo sysctl fs.inotify.max_user_instances=512

echo "=== Storage analysis before Docker bootstrap ==="
df -h
lsblk

echo "=== Checking /mnt partition availability ==="
MNT_AVAILABLE_KB=$(df /mnt | tail -1 | awk '{print $4}')
ROOT_AVAILABLE_KB=$(df / | tail -1 | awk '{print $4}')
MNT_AVAILABLE_GB=$((MNT_AVAILABLE_KB / 1024 / 1024))
ROOT_AVAILABLE_GB=$((ROOT_AVAILABLE_KB / 1024 / 1024))
echo "Root partition available: ${ROOT_AVAILABLE_GB}GB"
echo "Mnt partition available: ${MNT_AVAILABLE_GB}GB"

if [ $MNT_AVAILABLE_GB -lt 5 ]; then
  echo "WARNING: /mnt partition has limited space (${MNT_AVAILABLE_GB}GB). Docker storage may be constrained."
fi

# Create docker storage directory on /mnt (which has more space)
if [ ! -d /mnt/docker-storage ]; then
  sudo mkdir -p /mnt/docker-storage
  echo "✓ Created Docker storage directory: /mnt/docker-storage"
fi

# Configure Docker to use the new data root
sudo cat /etc/docker/daemon.json | sudo jq '.  +={"data-root" : "/mnt/docker-storage"}' | sudo tee /tmp/docker-daemon.json > /dev/null
sudo cp /tmp/docker-daemon.json /etc/docker/daemon.json

# Also configure containerd to use the same location
if [ -f /etc/containerd/config.toml ]; then
  sudo cp /etc/containerd/config.toml /etc/containerd/config.toml.backup
fi

sudo mkdir -p /etc/containerd
sudo tee /etc/containerd/config.toml > /dev/null <<EOF
version = 2
root = "/mnt/docker-storage/containerd"
state = "/mnt/docker-storage/containerd-state"

[grpc]
  address = "/run/containerd/containerd.sock"

[plugins."io.containerd.grpc.v1.cri"]
  sandbox_image = "registry.k8s.io/pause:3.9"

[plugins."io.containerd.grpc.v1.cri".containerd]
  snapshotter = "overlayfs"

[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]
  runtime_type = "io.containerd.runc.v2"

[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
  SystemdCgroup = true
EOF

# Create containerd storage directories
sudo mkdir -p /mnt/docker-storage/containerd
sudo mkdir -p /mnt/docker-storage/containerd-state

echo "=== Docker daemon configuration ==="
cat /etc/docker/daemon.json

echo "=== Containerd configuration ==="
cat /etc/containerd/config.toml

echo "=== Restarting container services ==="
sudo systemctl restart containerd
sudo systemctl restart docker

echo "=== Validating service status ==="
sudo systemctl is-active docker
sudo systemctl is-active containerd

echo "=== Storage directory validation ==="
sudo ls -la /mnt/docker-storage
if [ -d /mnt/docker-storage ]; then
  STORAGE_SIZE=$(sudo du -sh /mnt/docker-storage 2>/dev/null | cut -f1 || echo "unknown")
  echo "✓ Docker storage directory: ${STORAGE_SIZE}"
else
  echo "✗ Docker storage directory not found!"
  exit 1
fi

echo "=== Final storage state ==="
df -h
