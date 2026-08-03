# quick-k8s

[![Test Changes](https://github.com/palmsoftware/quick-k8s/actions/workflows/pre-main.yml/badge.svg)](https://github.com/palmsoftware/quick-k8s/actions/workflows/pre-main.yml)
[![Version Updates Nightly](https://github.com/palmsoftware/quick-k8s/actions/workflows/version-updates.yml/badge.svg)](https://github.com/palmsoftware/quick-k8s/actions/workflows/version-updates.yml)
[![Update OLM Version Nightly](https://github.com/palmsoftware/quick-k8s/actions/workflows/olm-update.yml/badge.svg)](https://github.com/palmsoftware/quick-k8s/actions/workflows/olm-update.yml)
[![Update Major Version Tag](https://github.com/palmsoftware/quick-k8s/actions/workflows/update-major-tag.yml/badge.svg)](https://github.com/palmsoftware/quick-k8s/actions/workflows/update-major-tag.yml)

GitHub Action that deploys Kubernetes clusters on GitHub Actions runners for testing and development. Supports **KinD** (default) and **Minikube** as cluster providers.

## Requirements

| Runner | Architecture | Status |
|--------|--------------|--------|
| `ubuntu-22.04` | x86_64 | Fully supported |
| `ubuntu-22.04-arm` | ARM64 | Fully supported |
| `ubuntu-24.04` | x86_64 | Fully supported |
| `ubuntu-24.04-arm` | ARM64 | Fully supported |
| `ubuntu-26.04` | x86_64 | Fully supported |

## Quick Start

```yaml
steps:
  - name: Set up Quick-K8s
    uses: palmsoftware/quick-k8s@v0
```

This creates a 1 control-plane + 1 worker cluster with Calico CNI. To use Minikube instead:

```yaml
steps:
  - name: Set up Quick-K8s with Minikube
    uses: palmsoftware/quick-k8s@v0
    with:
      clusterProvider: minikube
      minikubeVersion: v1.38.1
      minikubeDriver: docker
```

All inputs have sensible defaults. See the [Configuration Reference](docs/configuration.md) for the complete list.

## Features

| Feature | Enable | Details |
|---------|--------|---------|
| **Istio** service mesh | `installIstio: true` | [Guide](docs/optional-features.md#istio-service-mesh) |
| **cert-manager** TLS | `installCertManager: true` | [Guide](docs/optional-features.md#cert-manager) |
| **ingress-nginx** controller | `installIngressNginx: true` | [Guide](docs/optional-features.md#ingress-nginx) |
| **metrics-server** (HPA) | `installMetricsServer: true` | [Guide](docs/optional-features.md#metrics-server) |
| **operator-sdk** CLI | `installOperatorSdk: true` | [Guide](docs/optional-features.md#operator-sdk) |
| **MetalLB** load balancer | `installMetalLB: true` | [Guide](docs/optional-features.md#metallb) |
| **Monitoring** (Prometheus/Thanos/Grafana) | `enableClusterMonitoring: true` | [Guide](docs/optional-features.md#cluster-monitoring-kube-prometheus--thanos) |
| **CNI selection** (Calico/Cilium/none) | `cniPlugin: cilium` | [Guide](docs/optional-features.md#choosing-a-cni-plugin) |
| **Custom KinD config** | `kindConfigPath: path` | [Guide](docs/optional-features.md#custom-kind-configuration) |
| **Local Docker registry** | `installLocalRegistry: true` | [Guide](docs/optional-features.md#local-docker-registry) |

## Using the Cluster

The action configures `kubectl` (and `oc` on Linux) automatically. No extra setup needed:

```yaml
- name: Verify cluster
  run: |
    kubectl get nodes
    kubectl cluster-info
```

See the [Downstream Usage Guide](docs/downstream-usage.md) for kubeconfig details, context names, and storage classes.

## Guides

| Guide | Description |
|-------|-------------|
| [Configuration Reference](docs/configuration.md) | All inputs with defaults for KinD and Minikube |
| [Optional Features](docs/optional-features.md) | Istio, cert-manager, ingress-nginx, monitoring, and more |
| [Cluster Providers](docs/cluster-providers.md) | KinD vs Minikube comparison and recommendations |
| [Networking](docs/networking.md) | IP family configuration (dual-stack, IPv4, IPv6) |
| [Resource Management](docs/resource-management.md) | Adaptive disk and memory optimization |
| [Downstream Usage](docs/downstream-usage.md) | Using kubectl/oc, kubeconfig, storage classes |
| [Resource Requirements](docs/resource-requirements.md) | RAM, disk, and timing for each component |
| [Troubleshooting](docs/troubleshooting.md) | Common issues and solutions |
| [Version Compatibility](COMPATIBILITY.md) | Component version matrix and known issues |

## Examples

The [`examples/`](./examples/) directory contains copy-paste-ready workflow recipes:

| Example | Description |
|---------|-------------|
| [basic-cluster.yml](./examples/basic-cluster.yml) | Minimal cluster for CI testing |
| [istio-service-mesh.yml](./examples/istio-service-mesh.yml) | Cluster with Istio and sidecar injection |
| [monitoring-stack.yml](./examples/monitoring-stack.yml) | Full Prometheus/Thanos/Grafana stack |
| [multi-node-cluster.yml](./examples/multi-node-cluster.yml) | Multi-node with labels and topology spread |
| [custom-cni.yml](./examples/custom-cni.yml) | Cilium CNI example |
| [local-registry.yml](./examples/local-registry.yml) | Local Docker registry for image builds |
| [operator-development.yml](./examples/operator-development.yml) | OLM + operator-sdk + cert-manager |
| [full-stack.yml](./examples/full-stack.yml) | All components combined |

## History

Originally built upon [KinD](https://github.com/kubernetes-sigs/kind) and tuned as part of [certsuite-sample-workload](https://github.com/redhat-best-practices-for-k8s/certsuite-sample-workload), the project now supports KinD and [Minikube](https://github.com/kubernetes/minikube) as cluster providers.

This action is essentially a wrapper around best practices for deploying Kubernetes environments that run well on GitHub Actions free-tier Ubuntu runners, with intelligent resource management and optimizations for CI/CD workflows.

## References

- [install-oc-tools.sh](./scripts/install-oc-tools.sh) was a script copied from [install-oc-tools](https://github.com/cptmorgan-rh/install-oc-tools) and slightly modified for `aarch64`.
