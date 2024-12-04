#!/bin/bash

# Generate a KinD configuration file from parameters
# Usage: generate-kind-config.sh <api-server-port> <api-server-address> <disable-default-cni> <ip-family> <default-node-image> <control-plane-nodes> <num-worker-nodes>

# Set the default values
API_SERVER_PORT=$1
API_SERVER_ADDRESS=$2
DISABLE_DEFAULT_CNI=$3
IP_FAMILY=$4
DEFAULT_NODE_IMAGE=$5
CONTROL_PLANE_NODES=$6
NUM_WORKER_NODES=$7

FILE_NAME="kind-config.yaml"

# Check if the file exists and delete it
if [ -f ${FILE_NAME} ]; then
  rm ${FILE_NAME}
fi

# Generate the KinD configuration file
cat > ${FILE_NAME} <<EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
networking:
  apiServerAddress: "${API_SERVER_ADDRESS}"
  apiServerPort: ${API_SERVER_PORT}
  ipFamily: ${IP_FAMILY}
  disableDefaultCNI: ${DISABLE_DEFAULT_CNI}
EOF

# Generate the nodes section of the file
cat >> ${FILE_NAME} <<EOF
nodes:
EOF

# Generate node section of the file
for i in $(seq 1 ${CONTROL_PLANE_NODES}); do
cat >> ${FILE_NAME} <<EOF
  - role: control-plane
    image: "${DEFAULT_NODE_IMAGE}"
EOF
done

for i in $(seq 1 ${NUM_WORKER_NODES}); do
cat >> ${FILE_NAME} <<EOF
  - role: worker
    image: "${DEFAULT_NODE_IMAGE}"
EOF
done
