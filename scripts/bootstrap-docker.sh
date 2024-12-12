#!/usr/bin/env bash

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

df -h
lsblk
if [ ! -d /mnt/docker-storage ]; then
  sudo mkdir /mnt/docker-storage
fi
sudo jq '.  +={"data-root" : "/mnt/docker-storage"}' < /etc/docker/daemon.json > /tmp/docker-daemon.json
sudo cp /tmp/docker-daemon.json /etc/docker/daemon.json
cat /etc/docker/daemon.json
sudo systemctl restart docker
sudo ls -la /mnt/docker-storage
