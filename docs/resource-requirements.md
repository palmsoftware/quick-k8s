[Back to README](../README.md)

# Resource Requirements

Approximate resource requirements for common configurations on GitHub Actions free-tier runners (~7GB RAM, ~14GB disk):

| Configuration | RAM | Disk | Startup Time | Notes |
|--------------|-----|------|-------------|-------|
| Basic cluster (1 CP + 1 worker) | ~2GB | ~4GB | ~1-2 min | Fits comfortably on free-tier |
| + Calico CNI | +200MB | +50MB | +30s | Default configuration |
| + OLM | +500MB | +200MB | +1-2 min | Adds operator catalog pod |
| + Istio (minimal) | +300MB | +500MB | +2-3 min | Use `minimal` profile for CI |
| + Istio (demo) | +500MB | +800MB | +3-5 min | Not recommended for free-tier |
| + cert-manager | +200MB | +100MB | +30-60s | 3 pods (controller, webhook, cainjector) |
| + ingress-nginx | +100MB | +50MB | +1-2 min | 1-2 pods |
| + metrics-server | +50MB | +20MB | +30s | Lightweight |
| + MetalLB | +100MB | +50MB | +30s | Controller + speaker |
| + Monitoring stack | +1.5GB | +500MB | +3-5 min | Prometheus, Grafana, Thanos, etc. |
| + operator-sdk | N/A | +100MB | N/A | CLI only, no cluster pods |

## Recommended Combinations for Free-Tier Runners

- Basic + Calico + OLM + cert-manager (~3GB RAM)
- Basic + Calico + Istio minimal (~2.5GB RAM)
- Basic + Calico + ingress-nginx + metrics-server (~2.5GB RAM)
- Basic + Calico + OLM + Istio (~3.5GB RAM, tight fit)
- Basic + monitoring stack + Istio (~4.5GB RAM, likely OOM)

## Tips

- Use `numWorkerNodes: 0` for single-node clusters to save ~1GB RAM
- Use `skipDiskCleanup: true` on self-hosted runners with ample disk
- The `dryRun: true` option previews the configuration without creating anything
