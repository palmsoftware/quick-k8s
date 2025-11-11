# quick-k8s

[![Test Changes](https://github.com/palmsoftware/quick-k8s/actions/workflows/pre-main.yml/badge.svg)](https://github.com/palmsoftware/quick-k8s/actions/workflows/pre-main.yml)
[![Update Calico Version Nightly](https://github.com/palmsoftware/quick-k8s/actions/workflows/calico-update.yml/badge.svg)](https://github.com/palmsoftware/quick-k8s/actions/workflows/calico-update.yml)
[![Update OLM Version Nightly](https://github.com/palmsoftware/quick-k8s/actions/workflows/olm-update.yml/badge.svg)](https://github.com/palmsoftware/quick-k8s/actions/workflows/olm-update.yml)
[![Update Minikube Version Nightly](https://github.com/palmsoftware/quick-k8s/actions/workflows/minikube-update.yml/badge.svg)](https://github.com/palmsoftware/quick-k8s/actions/workflows/minikube-update.yml)
[![Update Major Version Tag](https://github.com/palmsoftware/quick-k8s/actions/workflows/update-major-tag.yml/badge.svg)](https://github.com/palmsoftware/quick-k8s/actions/workflows/update-major-tag.yml)

Github Action that will automatically create a Kubernetes cluster that lives and runs on Github Actions to allow for deployment and testing of code.

Supports both **KinD** (default) and **Minikube** as cluster providers.

## Requirements:

Linux (ARM and x86) runners are fully supported and tested.

**macOS Support Status**:
- ⚠️ **Not actively tested in CI** - macOS builds have been temporarily disabled due to runner limitations
- The action code supports macOS Intel runners (`macos-13`, `macos-14-large`, `macos-15-large`) but:
  - `macos-13` is deprecated by GitHub
  - `macos-14` and `macos-15` (Apple Silicon/ARM64) lack Docker nested virtualization support on free tier
  - `-large` Intel runners require a paid GitHub plan
- If you have access to Intel-based macOS runners, the action should work but use at your own risk

## Usage:

Basic Usage:
```
steps:
  - name: Set up Quick-K8s
    uses: palmsoftware/quick-k8s@v0.0.39
```

This will create you a default 1 worker and 1 control-plane cluster with calico CNI installed.  For additional feature enablement, please refer to the flags below:

### Using Minikube as the Cluster Provider

To use Minikube instead of KinD:

```yaml
steps:
  - name: Set up Quick-K8s with Minikube
    uses: palmsoftware/quick-k8s@v0.0.39
    with:
      clusterProvider: minikube
      minikubeVersion: v1.37.0
      minikubeDriver: docker
```

### Complete Configuration (default values shown)

With KinD (default):

```yaml
steps:
  - name: Set up Quick-K8s
    uses: palmsoftware/quick-k8s@v0.0.39
    with:
      clusterProvider: kind
      apiServerPort: 6443
      apiServerAddress: 0.0.0.0
      disableDefaultCni: true
      ipFamily: dual
      defaultNodeImage: 'kindest/node:v1.33.1@sha256:050072256b9a903bd914c0b2866828150cb229cea0efe5892e2b644d5dd3b34f'
      kindVersion: v0.30.0
      calicoVersion: v3.30.3

      numControlPlaneNodes: 1
      numWorkerNodes: 1
      installOLM: false
      removeDefaultStorageClass: false
      removeControlPlaneTaint: false
```

With Minikube:

```yaml
steps:
  - name: Set up Quick-K8s with Minikube
    uses: palmsoftware/quick-k8s@v0.0.39
    with:
      clusterProvider: minikube
      minikubeVersion: v1.37.0
      minikubeDriver: docker
      apiServerPort: 6443
      disableDefaultCni: true
      defaultNodeImage: 'kindest/node:v1.33.1@sha256:050072256b9a903bd914c0b2866828150cb229cea0efe5892e2b644d5dd3b34f'
      calicoVersion: v3.30.3

      numControlPlaneNodes: 1
      numWorkerNodes: 1
      installOLM: false
      removeDefaultStorageClass: false
      removeControlPlaneTaint: false
```

## Cluster Provider Comparison

### KinD vs Minikube

Both cluster providers are fully supported and tested. Choose the one that best fits your needs:

#### KinD (Kubernetes in Docker) - **Default**
- ✅ **Best for**: CI/CD pipelines, fast cluster creation
- ✅ **Advantages**: 
  - Faster startup time
  - Native multi-node support with simple configuration
  - Designed specifically for testing
  - Lower resource overhead
- ⚠️ **Considerations**: Limited to Docker as the runtime

#### Minikube
- ✅ **Best for**: Development environments, feature parity with production
- ✅ **Advantages**:
  - More mature and feature-rich
  - Multiple driver options (docker, podman, none)
  - Better local development experience
  - Built-in addons system
  - GPU support (with krunkit driver on macOS)
- ⚠️ **Considerations**: 
  - Slightly slower startup, more complex for multi-node setups
  - When disabling default CNI (`disableDefaultCni: true`), uses docker runtime instead of containerd (Minikube requirement)

**Recommendation**: Use **KinD** (default) for most CI/CD scenarios. Use **Minikube** if you need specific features or driver compatibility.

## Intelligent Resource Management

This action features intelligent, adaptive disk space management that optimizes performance while ensuring reliability:

### 🧠 **Smart Cleanup Strategy**
- **Adaptive Cleanup**: Automatically detects available space and adjusts cleanup intensity (light vs aggressive)
- **Targeted Package Removal**: Intelligently identifies and removes only installed large packages (browsers, databases, SDKs)
- **Efficient Directory Scanning**: Scans for and reports actual sizes before removing large directories
- **Performance Timing**: Tracks and reports cleanup duration for optimization insights

### 🔧 **Advanced Storage Management**
- **Smart Storage Relocation**: Configures Docker and containerd to use the larger `/mnt` partition
- **Deep Container Cleanup**: Thoroughly cleans all Docker/containerd artifacts, images, and storage layers
- **Early Validation**: Validates minimum disk space requirements (8GB) with clear error reporting
- **Real-time Monitoring**: Provides detailed disk usage, memory, and system state reporting

### 🎯 **Performance Features**
- **Skip Unnecessary Work**: Avoids aggressive cleanup when sufficient space is already available (>20GB)
- **Detailed Progress Reporting**: Shows exactly what's being cleaned and how much space is recovered
- **Cross-Architecture Support**: Optimized for both x86_64 and ARM64 GitHub Actions runners (Ubuntu 22.04/24.04)
- **Zero External Dependencies**: Uses only built-in bash arithmetic (no `bc` or other external tools)

## History

Originally built upon [KinD](https://github.com/kubernetes-sigs/kind) and tuned as part of [certsuite-sample-workload](https://github.com/redhat-best-practices-for-k8s/certsuite-sample-workload), the project now supports both KinD and [Minikube](https://github.com/kubernetes/minikube) as cluster providers.

This action is essentially a wrapper around best practices for deploying Kubernetes environments that run well on GitHub Actions free-tier Ubuntu runners, with intelligent resource management and optimizations for CI/CD workflows.

## References

- [install-oc-tools.sh](./scripts/install-oc-tools.sh) was a script copied from [install-oc-tools](https://github.com/cptmorgan-rh/install-oc-tools) and slightly modified for `aarch64`.
- [douglascamata/setup-docker-macos-action@v1-alpha](https://github.com/marketplace/actions/setup-docker-on-macos) is brought to help install Docker on MacOS.
