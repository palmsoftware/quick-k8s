#!/usr/bin/env bash

CPU_ARCH="$(uname -m)"
export CPU_ARCH
echo "CPU_ARCH=$CPU_ARCH"

MULTUS_GIT_URL="https://github.com/k8snetworkplumbingwg/multus-cni.git"
WHEREABOUTS_GIT_URL="https://github.com/k8snetworkplumbingwg/whereabouts"
MULTUS_VERSION="v4.1.4"
WHEREABOUTS_VERSION="v0.8.0"
echo "Deploying Multus"

# Wait for all calico and multus daemonset pods to be running
oc rollout status daemonset calico-node -n kube-system --timeout="300s"

rm -rf ./temp
git clone --depth 1 $MULTUS_GIT_URL -b $MULTUS_VERSION ./temp/multus-cni
oc apply --filename ./temp/multus-cni/deployments/multus-daemonset.yml

# Wait for all multus daemonset pods to be running
oc rollout status daemonset kube-multus-ds -n kube-system --timeout="300s"

#!/bin/bash
sudo apt-get update -y
sudo apt-get install -y python3 python3-pip
sudo pip3 install --upgrade pip

# Install the j2cli package for use with the multus-cni repo
sudo pip3 install j2cli

# Install macvlan and other default plugins
echo "## install CNIs"
pushd temp/multus-cni/e2e || exit
if [ "$CPU_ARCH" != arm64 ]; then
  ./get_tools.sh
fi
./generate_yamls.sh
popd || exit

if [ "$CPU_ARCH" == arm64 ]; then
  sed -i 's/amd64/arm64/g' temp/multus-cni/e2e/yamls/cni-install.yml
fi

# Temporarily commenting this out as we are currently not running this in a non-allowlisted environment
# sed 's/alpine/quay.io\/jitesoft\/alpine:latest/g' temp/multus-cni/e2e/yamls/cni-install.yml -i
kubectl apply -f temp/multus-cni/e2e/yamls/cni-install.yml
kubectl -n kube-system wait --for=condition=ready -l name="cni-plugins" pod --timeout="300s"

# If the whereabouts folder exists, remove it
rm -rf whereabouts

# Install whereabouts at specific released version
git clone $WHEREABOUTS_GIT_URL --depth 1 -b $WHEREABOUTS_VERSION
sed 's/whereabouts:latest/whereabouts:$WHEREABOUTS_VERSION/g' whereabouts/doc/crds/daemonset-install.yaml -i

oc apply \
  -f whereabouts/doc/crds/daemonset-install.yaml \
  -f whereabouts/doc/crds/whereabouts.cni.cncf.io_ippools.yaml \
  -f whereabouts/doc/crds/whereabouts.cni.cncf.io_overlappingrangeipreservations.yaml

rm -rf whereabouts

# Whereabout does not support dual stack so creating 2 sets of single stack multus interfaces
create_nets() {
  for ((NUM = 0; NUM < MULTUS_IF_NUM; NUM++)); do
    # Creates the network attachment with ptp plugin on partner namespace
    mkdir -p ./temp

    # shellcheck disable=SC2001 # Useless echo.
    IP_NUM=$(echo "$2" | sed 's/NUM/'"${NUM}"'/g') NET_NAME_NUM="$NET_NAME-$1-$NUM" "$SCRIPT_DIR"/mo ./config/k8s-cluster/multus.yaml >./temp/rendered-multus.yaml
    oc apply --filename ./temp/rendered-multus.yaml
    rm ./temp/rendered-multus.yaml
  done
}

# IPv4
create_nets "ipv4" "192.168.NUM.0/24"

# IPv6
create_nets "ipv6" "3ffe:ffff:0:NUM::/64"
sleep 3

