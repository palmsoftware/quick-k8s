#!/usr/bin/env bash
# Configure Docker for Kubernetes (IPv6 support and file system limits)
# Note: Docker storage relocation is handled by quick-cleanup action

for cmd in curl tar jq; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Error: $cmd is not installed." >&2
    exit 1
  fi
done

echo "=== Configuring Docker for Kubernetes ==="

# create the docker daemon json file if it does not exist
if [ ! -f /etc/docker/daemon.json ]; then
  echo '{}' | sudo tee /etc/docker/daemon.json
fi

# update docker config to include ipv6 support
jq '. +={"ipv6": true, "fixed-cidr-v6": "2001:db8:1::/64"}' /etc/docker/daemon.json > /tmp/new-docker-daemon.json
sudo cp /tmp/new-docker-daemon.json /etc/docker/daemon.json
rm /tmp/new-docker-daemon.json

echo "=== Docker daemon configuration ==="
cat /etc/docker/daemon.json

# restart docker
sudo systemctl restart docker

# increase file system limits for Kubernetes
sudo sysctl fs.inotify.max_user_watches=524288
sudo sysctl fs.inotify.max_user_instances=512

echo "✓ Docker configured for Kubernetes (IPv6 enabled, sysctl limits set)"
