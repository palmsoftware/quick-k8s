#!/usr/bin/env bash
# Sourceable cert-manager helpers.
#
# cert-manager ships its ValidatingWebhookConfiguration and
# MutatingWebhookConfiguration with an empty caBundle and the annotation
# cert-manager.io/inject-ca-from-secret. cainjector populates that caBundle
# asynchronously once the webhook has generated its serving certificate.
#
# Waiting for the cert-manager pods to be Ready is therefore not enough: until
# the caBundle is injected the apiserver verifies the webhook's TLS certificate
# against an empty CA and rejects any cert-manager resource with
#
#   Internal error occurred: failed calling webhook "webhook.cert-manager.io":
#   tls: failed to verify certificate: x509: certificate signed by unknown authority
#
# Usage:
#   source "$(dirname "$0")/lib/cert-manager.sh"
#   wait_for_cert_manager_webhook_ca 120

CERT_MANAGER_WEBHOOK_CONFIGS=(
  validatingwebhookconfiguration/cert-manager-webhook
  mutatingwebhookconfiguration/cert-manager-webhook
)

# Returns 0 when every cert-manager webhook configuration has a caBundle.
_cert_manager_webhook_ca_injected() {
  local resource ca_bundle
  for resource in "${CERT_MANAGER_WEBHOOK_CONFIGS[@]}"; do
    ca_bundle=$(kubectl get "$resource" \
      -o jsonpath='{.webhooks[0].clientConfig.caBundle}' 2>/dev/null) || return 1
    [ -n "$ca_bundle" ] || return 1
  done
  return 0
}

# Usage: wait_for_cert_manager_webhook_ca [timeout_seconds] [poll_interval_seconds]
# Returns 0 once the caBundle is injected, 1 on timeout.
wait_for_cert_manager_webhook_ca() {
  local timeout="${1:-120}"
  local interval="${2:-2}"
  [ "$interval" -ge 1 ] || interval=1
  local attempts=$((timeout / interval))
  [ "$attempts" -ge 1 ] || attempts=1

  local attempt=1
  while [ "$attempt" -le "$attempts" ]; do
    if _cert_manager_webhook_ca_injected; then
      echo "cert-manager webhook caBundle injected."
      return 0
    fi
    [ "$attempt" -eq "$attempts" ] && break
    sleep "$interval"
    attempt=$((attempt + 1))
  done

  echo "Timed out after ${timeout}s waiting for cert-manager to inject the webhook caBundle." >&2
  return 1
}
