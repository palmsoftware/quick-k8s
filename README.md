# quick-k8s

[![Test Changes](https://github.com/palmsoftware/quick-k8s/actions/workflows/pre-main.yml/badge.svg)](https://github.com/palmsoftware/quick-k8s/actions/workflows/pre-main.yml)
[![Update Calico Version Nightly](https://github.com/palmsoftware/quick-k8s/actions/workflows/calico-update.yml/badge.svg)](https://github.com/palmsoftware/quick-k8s/actions/workflows/calico-update.yml)
[![Update Istio Version Nightly](https://github.com/palmsoftware/quick-k8s/actions/workflows/istio-update.yml/badge.svg)](https://github.com/palmsoftware/quick-k8s/actions/workflows/istio-update.yml)
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
      kindVersion: v0.31.0
      calicoVersion: v3.30.3

      numControlPlaneNodes: 1
      numWorkerNodes: 1
      installOLM: false
      installIstio: false
      istioVersion: 1.28.1
      istioProfile: minimal
      removeDefaultStorageClass: false
      removeControlPlaneTaint: false

      # New advanced options
      installCalico: true           # Set to false to bring your own CNI
      kindConfigPath: ''            # Path to custom KinD config file
      installLocalRegistry: false   # Enable local Docker registry
      localRegistryPort: 5001       # Port for local registry
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
      installIstio: false
      istioVersion: 1.28.1
      istioProfile: minimal
      removeDefaultStorageClass: false
      removeControlPlaneTaint: false
```

## Optional Features

### Installing Istio Service Mesh

Enable Istio installation to test service mesh functionality:

```yaml
steps:
  - name: Set up Quick-K8s with Istio
    uses: palmsoftware/quick-k8s@v0.0.39
    with:
      installIstio: true
      istioVersion: 1.28.1
      istioProfile: minimal
```

**Available Istio Profiles**:
- `minimal` (default) - Essential components only, lowest resource usage (~300MB)
- `demo` - For demos and exploration (~500MB) 
- `default` - Production-ready baseline (~400MB)
- `preview` - Preview profile with experimental features
- `ambient` - Ambient mesh mode (sidecar-less)
- `empty` - Deploys nothing, for custom configurations

**⚠️ Resource Considerations**:
- Istio adds significant overhead to cluster startup time (2-5 minutes)
- The `minimal` profile is recommended for CI/CD to reduce resource consumption
- Consider reducing worker nodes or using runners with more resources when enabling Istio
- Istio control plane requires ~300-500MB additional memory depending on profile

### Bring Your Own CNI (Skip Calico)

For projects that need to install their own CNI (e.g., Multus, OVN-Kubernetes, Cilium), you can skip the default Calico installation:

```yaml
steps:
  - name: Set up Quick-K8s without Calico
    uses: palmsoftware/quick-k8s@v0.0.39
    with:
      disableDefaultCni: true
      installCalico: false  # Skip Calico installation
      waitForPodsReady: false  # Don't wait - no CNI means pods won't be ready

  - name: Install your own CNI
    run: |
      # Example: Install Multus
      kubectl apply -f https://raw.githubusercontent.com/k8snetworkplumbingwg/multus-cni/master/deployments/multus-daemonset.yml
```

**⚠️ Important Notes**:
- When `installCalico: false`, the cluster will not have a functional CNI
- Pods will remain in `Pending` state until you install a CNI
- Set `waitForPodsReady: false` to avoid timeouts waiting for pods
- This is ideal for projects testing their own CNI implementations

### Custom KinD Configuration

For advanced use cases, you can provide your own KinD configuration file:

```yaml
steps:
  - name: Create custom KinD config
    run: |
      cat > /tmp/my-kind-config.yaml << 'EOF'
      kind: Cluster
      apiVersion: kind.x-k8s.io/v1alpha4
      networking:
        apiServerAddress: "127.0.0.1"
        apiServerPort: 6443
        ipFamily: ipv4
        disableDefaultCNI: true
      nodes:
        - role: control-plane
          extraPortMappings:
            - containerPort: 30000
              hostPort: 30000
              protocol: TCP
        - role: worker
        - role: worker
      EOF

  - name: Set up Quick-K8s with custom config
    uses: palmsoftware/quick-k8s@v0.0.39
    with:
      kindConfigPath: /tmp/my-kind-config.yaml
```

**Use cases for custom configuration**:
- Extra port mappings for NodePort services
- Custom node labels and taints
- Specific container runtime settings
- Advanced networking configurations
- Testing multi-zone setups

### Local Docker Registry

Enable a local Docker registry for faster image pulls and testing:

```yaml
steps:
  - name: Set up Quick-K8s with local registry
    uses: palmsoftware/quick-k8s@v0.0.39
    with:
      installLocalRegistry: true
      localRegistryPort: 5001  # Default port

  - name: Build and push to local registry
    run: |
      docker build -t localhost:5001/my-app:latest .
      docker push localhost:5001/my-app:latest

  - name: Deploy using local registry image
    run: |
      kubectl create deployment my-app --image=localhost:5001/my-app:latest
```

**Benefits**:
- Faster image pulls within the cluster
- No need for external registry authentication
- Ideal for testing container builds in CI/CD
- Images persist for the duration of the workflow

**Registry Details**:
- Accessible at `localhost:<port>` from both the host and cluster
- Uses the standard Docker registry:2 image
- Automatically connected to the KinD network
- ConfigMap created in `kube-public` namespace for discoverability

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

## Network Configuration

### IP Family Support

The action supports multiple IP family configurations for Kubernetes clusters:

```yaml
steps:
  - name: Set up Quick-K8s with IP family
    uses: palmsoftware/quick-k8s@v0.0.39
    with:
      ipFamily: dual  # Options: dual, ipv4, ipv6
```

**Available Options**:
- `dual` (default) - Dual-stack IPv4/IPv6 configuration
- `ipv4` - IPv4-only configuration
- `ipv6` - IPv6-only configuration

**⚠️ IPv6-Only Considerations**:
- IPv6-only mode (`ipFamily: ipv6`) is supported but may be unstable in certain CI environments
- GitHub Actions runners have limited IPv6 support, which can cause timeouts and networking issues
- **Recommended**: Use `dual` (dual-stack) for IPv6 functionality in CI/CD pipelines
- IPv6-only clusters are rare in production; dual-stack is the standard IPv6 deployment pattern
- If you need IPv6-only for testing, ensure your environment has proper IPv6 networking configured

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
