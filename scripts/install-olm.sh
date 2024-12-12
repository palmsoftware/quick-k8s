#!/usr/bin/env bash
OLM_VERSION="v0.28.0"
echo "Installing OLM version $OLM_VERSION"

#check if operator-sdk is installed and install it if needed
if [[ -z "$(which operator-sdk 2>/dev/null)" ]]; then
	echo "operator-sdk executable cannot be found in the path. Will try to install it."
	"$SCRIPT_DIR"/install-operator-sdk.sh
else
	echo "operator-sdk was found in the path, no need to install it"
fi
curl -L https://github.com/operator-framework/operator-lifecycle-manager/releases/download/$OLM_VERSION/install.sh -o install.sh
chmod +x install.sh
./install.sh $OLM_VERSION
rm install.sh

# Wait for all OLM pods to be ready
kubectl wait --for=condition=ready pod --all=true -n olm --timeout="300s"
