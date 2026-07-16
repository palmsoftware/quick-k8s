# Version Compatibility Matrix

This document lists tested and known-compatible version combinations for quick-k8s components.

## Component Compatibility

| Kubernetes | Calico | Cilium | Istio | cert-manager | OLM | MetalLB | Notes |
|------------|--------|--------|-------|--------------|-----|---------|-------|
| 1.36.x | v3.32+ | v1.17+ | 1.30+ | v1.20+ | v0.31+ | v0.15+ | Current default |
| 1.35.x | v3.31+ | v1.16+ | 1.29+ | v1.19+ | v0.30+ | v0.14+ | Fully tested |
| 1.34.x | v3.30+ | v1.15+ | 1.28+ | v1.18+ | v0.29+ | v0.14+ | Fully tested |
| 1.33.x | v3.29+ | v1.14+ | 1.27+ | v1.17+ | v0.28+ | v0.13+ | Compatible |
| <1.31 | v3.28.x | v1.14+ | 1.26+ | v1.16+ | v0.27+ | v0.13+ | See notes below |

## Known Issues and Workarounds

### Calico v3.32+ with Kubernetes <1.31

Calico v3.32 and later include CRDs that use CEL validation functions (e.g., `isCIDR`) not available in Kubernetes versions prior to 1.31. The action automatically handles this: if CRD validation errors occur but the core `calico-node` daemonset is running, the installation is treated as successful.

**Workaround**: Built into the action — no user action needed. To avoid the warning entirely, pin `calicoVersion` to `v3.28.x` when using older Kubernetes versions.

### Minikube Kubernetes Version Support

Minikube may not support the very latest Kubernetes version. When the `defaultNodeImage` references a Kubernetes version newer than what the installed Minikube binary supports, the action automatically falls back to Minikube's latest supported version and emits a warning.

### OLM on Kubernetes 1.36+

OLM v0.31+ is recommended for Kubernetes 1.36+. Older OLM versions may encounter API compatibility issues with newer Kubernetes releases.

### Istio Profile Resource Usage

| Profile | Memory | CPU | Best For |
|---------|--------|-----|----------|
| `minimal` | ~300MB | ~200m | CI/CD (recommended) |
| `default` | ~400MB | ~300m | Production-like testing |
| `demo` | ~500MB | ~400m | Exploring features |
| `ambient` | ~400MB | ~300m | Sidecar-less mesh |
| `preview` | ~500MB | ~400m | Experimental features |

## CI Test Matrix

The following combinations are tested nightly:

| Runner | Provider | Configuration |
|--------|----------|--------------|
| ubuntu-22.04 | KinD | Basic + Calico + OLM + Istio + cert-manager |
| ubuntu-22.04-arm | KinD | Basic + Calico |
| ubuntu-24.04 | KinD | Basic + Calico + OLM + Istio + cert-manager |
| ubuntu-24.04-arm | KinD | Basic + Calico |
| ubuntu-26.04 | KinD | Basic + Calico + OLM + Istio + cert-manager |
| ubuntu-22.04 | Minikube | Basic + Calico + OLM + Istio + cert-manager |
| ubuntu-22.04-arm | Minikube | Basic + Calico |
| ubuntu-24.04 | Minikube | Basic + Calico + OLM + Istio + cert-manager |
| ubuntu-24.04-arm | Minikube | Basic + Calico |
| ubuntu-26.04 | Minikube | Basic + Calico + OLM + Istio + cert-manager |

## Upstream Compatibility References

- [Calico requirements](https://docs.tigera.io/calico/latest/getting-started/kubernetes/requirements)
- [Cilium requirements](https://docs.cilium.io/en/stable/operations/system_requirements/)
- [Istio supported releases](https://istio.io/latest/docs/releases/supported-releases/)
- [cert-manager supported releases](https://cert-manager.io/docs/releases/)
- [OLM releases](https://github.com/operator-framework/operator-lifecycle-manager/releases)
- [MetalLB releases](https://github.com/metallb/metallb/releases)
