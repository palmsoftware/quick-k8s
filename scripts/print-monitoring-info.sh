#!/usr/bin/env bash
set -euo pipefail

# Print access instructions for installed monitoring components.
# Arguments:
#   $1 - "true" if metrics-server is installed
#   $2 - "true" if cluster monitoring (kube-prometheus + Thanos) is installed

METRICS_SERVER="${1:-false}"
CLUSTER_MONITORING="${2:-false}"

if [ "$METRICS_SERVER" != "true" ] && [ "$CLUSTER_MONITORING" != "true" ]; then
  exit 0
fi

echo ""
echo "======================================"
echo "  Monitoring Access Instructions"
echo "======================================"

if [ "$METRICS_SERVER" = "true" ]; then
  echo ""
  echo "--- metrics-server ---"
  echo ""
  echo "  metrics-server provides resource usage data (no web UI)."
  echo ""
  echo "  Query resource usage:"
  echo "    kubectl top nodes"
  echo "    kubectl top pods -A"
  echo "    kubectl top pods -n <namespace>"
  echo ""
  echo "  Raw metrics API:"
  echo "    kubectl get --raw /apis/metrics.k8s.io/v1beta1/nodes"
  echo "    kubectl get --raw /apis/metrics.k8s.io/v1beta1/pods"
fi

if [ "$CLUSTER_MONITORING" = "true" ]; then
  echo ""
  echo "--- Prometheus ---"
  echo ""
  echo "  Namespace: monitoring"
  echo "  Service:   prometheus-k8s"
  echo "  Port:      9090"
  echo ""
  echo "  Port-forward:"
  echo "    kubectl port-forward -n monitoring svc/prometheus-k8s 9090:9090"
  echo "  Then open: http://localhost:9090"
  echo ""
  echo "--- Alertmanager ---"
  echo ""
  echo "  Namespace: monitoring"
  echo "  Service:   alertmanager-main"
  echo "  Port:      9093"
  echo ""
  echo "  Port-forward:"
  echo "    kubectl port-forward -n monitoring svc/alertmanager-main 9093:9093"
  echo "  Then open: http://localhost:9093"
  echo ""
  echo "--- Grafana ---"
  echo ""
  echo "  Namespace: monitoring"
  echo "  Service:   grafana"
  echo "  Port:      3000"
  echo ""
  echo "  Port-forward:"
  echo "    kubectl port-forward -n monitoring svc/grafana 3000:3000"
  echo "  Then open: http://localhost:3000"
  echo "  Default credentials: admin / admin"
  echo ""
  echo "--- Thanos Query ---"
  echo ""
  echo "  Namespace: monitoring"
  echo "  Service:   thanos-query"
  echo "  Port:      9090"
  echo ""
  echo "  Port-forward:"
  echo "    kubectl port-forward -n monitoring svc/thanos-query 10902:9090"
  echo "  Then open: http://localhost:10902"
  echo ""
  echo "--- List all monitoring services ---"
  echo ""
  echo "  kubectl get svc -n monitoring"
fi

echo ""
echo "======================================"
