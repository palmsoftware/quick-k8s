#!/usr/bin/env bash
set -euo pipefail

TLS_COMPLIANCE_OPERATOR="${INSTALL_TLS_COMPLIANCE_OPERATOR:-false}"
IMAGE_CERT_INFO_OPERATOR="${INSTALL_IMAGE_CERT_INFO_OPERATOR:-false}"

if [[ "$TLS_COMPLIANCE_OPERATOR" != "true" && "$IMAGE_CERT_INFO_OPERATOR" != "true" ]]; then
  echo "Skipping TLS Compliance and Image Cert Info Operators"
  exit 0
fi

if ! command -v kubectl >/dev/null 2>&1; then
  echo "::error::kubectl is not installed." >&2
  exit 1
fi

if [[ "$TLS_COMPLIANCE_OPERATOR" == "true" ]]; then
  echo "Applying the latest TLS Compliance Operator release"
  kubectl apply -f "https://github.com/sebrandon1/tls-compliance-operator/releases/latest/download/install.yaml"
fi

if [[ "$IMAGE_CERT_INFO_OPERATOR" == "true" ]]; then
  echo "Applying the latest Image Cert Info Operator release"
  kubectl apply -f "https://github.com/sebrandon1/imagecertinfo-operator/releases/latest/download/install.yaml"
fi
