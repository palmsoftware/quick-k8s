#!/bin/bash

# Generate a KinD configuration file from parameters
# Usage: generate-kind-config.sh <api-server-port> <api-server-address> <disable-default-cni> <ip-family> <default-node-image> <control-plane-nodes> <num-worker-nodes> <output-file> [cluster-name]

if ! command -v envsubst >/dev/null 2>&1; then
  echo "Error: envsubst is not installed." >&2
  exit 1
fi

# Set the default values
API_SERVER_PORT=$1
API_SERVER_ADDRESS=$2
DISABLE_DEFAULT_CNI=$3
IP_FAMILY=$4
DEFAULT_NODE_IMAGE=$5
CONTROL_PLANE_NODES=$6
NUM_WORKER_NODES=$7
FILE_NAME=$8
CLUSTER_NAME=${9:-}

# Check if the file exists and delete it
if [ -f "${FILE_NAME}" ]; then
  rm "${FILE_NAME}"
fi

# Generate the KinD configuration file
cat > "${FILE_NAME}" <<EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
EOF

# Add cluster name if provided and not the default
if [ -n "${CLUSTER_NAME}" ] && [ "${CLUSTER_NAME}" != "kind" ]; then
cat >> "${FILE_NAME}" <<EOF
name: ${CLUSTER_NAME}
EOF
fi

cat >> "${FILE_NAME}" <<EOF
networking:
  apiServerAddress: "${API_SERVER_ADDRESS}"
  apiServerPort: ${API_SERVER_PORT}
  ipFamily: ${IP_FAMILY}
  disableDefaultCNI: ${DISABLE_DEFAULT_CNI}
EOF

# Generate the nodes section of the file
cat >> "${FILE_NAME}" <<EOF
nodes:
EOF

# Generate node section of the file
for ((i=1; i<="${CONTROL_PLANE_NODES}"; i++)); do
cat >> "${FILE_NAME}" <<EOF
  - role: control-plane
    image: "${DEFAULT_NODE_IMAGE}"
EOF
done

for ((i=1; i<="${NUM_WORKER_NODES}"; i++)); do
cat >> "${FILE_NAME}" <<EOF
  - role: worker
    image: "${DEFAULT_NODE_IMAGE}"
EOF
done
