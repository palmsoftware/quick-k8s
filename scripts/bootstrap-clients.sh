#!/bin/bash
# shellcheck disable=SC2207

# download the latest openshift client at a certain release level
RELEASE_LEVEL=$1
ARCH=$2
VERSIONS=($(sudo curl -sH 'Accept: application/json' "https://api.openshift.com/api/upgrades_info/v1/graph?channel=stable-${RELEASE_LEVEL}&arch=${ARCH}" | jq -r '.nodes[].version' | sort))
IFS=$'\n' SORTED_VERSIONS=($(sort -V <<<"${VERSIONS[*]}")); unset IFS
OPENSHIFT_VERSION=${SORTED_VERSIONS[${#SORTED_VERSIONS[@]} - 1]}

OC_BIN_TAR="openshift-client-linux.tar.gz"
OC_DL_URL="https://mirror.openshift.com/pub/openshift-v4/clients/ocp"/${OPENSHIFT_VERSION}/${OC_BIN_TAR}

curl -Lo oc.tar.gz "${OC_DL_URL}"
tar -xvf oc.tar.gz
chmod +x oc kubectl
sudo cp oc kubectl /usr/bin/.
