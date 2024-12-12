#!/usr/bin/env bash
OLM_VERSION="v0.28.0"
echo "Installing OLM version $OLM_VERSION"

curl -L https://github.com/operator-framework/operator-lifecycle-manager/releases/download/$OLM_VERSION/install.sh -o install.sh
chmod +x install.sh
./install.sh $OLM_VERSION
rm install.sh

# Wait for all OLM pods to be ready
kubectl wait --for=condition=ready pod --all=true -n olm --timeout="300s"
