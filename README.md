# quick-k8s

[![Test Changes](https://github.com/palmsoftware/quick-k8s/actions/workflows/pre-main.yml/badge.svg)](https://github.com/palmsoftware/quick-k8s/actions/workflows/pre-main.yml)
[![Update Calico Version Nightly](https://github.com/palmsoftware/quick-k8s/actions/workflows/calico-update.yml/badge.svg)](https://github.com/palmsoftware/quick-k8s/actions/workflows/calico-update.yml)
[![Update Istio Version Nightly](https://github.com/palmsoftware/quick-k8s/actions/workflows/istio-update.yml/badge.svg)](https://github.com/palmsoftware/quick-k8s/actions/workflows/istio-update.yml)
[![Update OLM Version Nightly](https://github.com/palmsoftware/quick-k8s/actions/workflows/olm-update.yml/badge.svg)](https://github.com/palmsoftware/quick-k8s/actions/workflows/olm-update.yml)
[![Update Minikube Version Nightly](https://github.com/palmsoftware/quick-k8s/actions/workflows/minikube-update.yml/badge.svg)](https://github.com/palmsoftware/quick-k8s/actions/workflows/minikube-update.yml)
[![Update cert-manager Version Nightly](https://github.com/palmsoftware/quick-k8s/actions/workflows/cert-manager-update.yml/badge.svg)](https://github.com/palmsoftware/quick-k8s/actions/workflows/cert-manager-update.yml)
[![Update ingress-nginx Version Nightly](https://github.com/palmsoftware/quick-k8s/actions/workflows/ingress-nginx-update.yml/badge.svg)](https://github.com/palmsoftware/quick-k8s/actions/workflows/ingress-nginx-update.yml)
[![Update metrics-server Version Nightly](https://github.com/palmsoftware/quick-k8s/actions/workflows/metrics-server-update.yml/badge.svg)](https://github.com/palmsoftware/quick-k8s/actions/workflows/metrics-server-update.yml)
[![Update operator-sdk Version Nightly](https://github.com/palmsoftware/quick-k8s/actions/workflows/operator-sdk-update.yml/badge.svg)](https://github.com/palmsoftware/quick-k8s/actions/workflows/operator-sdk-update.yml)
[![Update k3s Version Nightly](https://github.com/palmsoftware/quick-k8s/actions/workflows/k3s-update.yml/badge.svg)](https://github.com/palmsoftware/quick-k8s/actions/workflows/k3s-update.yml)
[![Update Major Version Tag](https://github.com/palmsoftware/quick-k8s/actions/workflows/update-major-tag.yml/badge.svg)](https://github.com/palmsoftware/quick-k8s/actions/workflows/update-major-tag.yml)

Github Action that will automatically create a Kubernetes cluster that lives and runs on Github Actions to allow for deployment and testing of code.

Supports **KinD** (default), **Minikube**, and **k3s** as cluster providers.

## Requirements:

**Tested Runners:**

| Runner | Architecture | Status |
|--------|--------------|--------|
| `ubuntu-22.04` | x86_64 | ✅ Fully supported |
| `ubuntu-22.04-arm` | ARM64 | ✅ Fully supported |
| `ubuntu-24.04` | x86_64 | ✅ Fully supported |
| `ubuntu-24.04-arm` | ARM64 | ✅ Fully supported |
| `macos-15-intel` | x86_64 | ✅ Supported (see notes) |
| `macos-14`, `macos-15` | ARM64 (M1) | ❌ Not supported |

**macOS Notes:**
- Docker is set up automatically via Colima using `douglascamata/setup-docker-macos-action`
- OLM and Istio installation are not supported on macOS due to Colima networking limitations
- Apple Silicon runners (`macos-14`, `macos-15`) lack nested virtualization required for Docker

## Usage:

Basic Usage:
```
steps:
  - name: Set up Quick-K8s
    uses: palmsoftware/quick-k8s@v0.0.61
```

This will create you a default 1 worker and 1 control-plane cluster with calico CNI installed.  For additional feature enablement, please refer to the flags below:

### Using Minikube as the Cluster Provider

To use Minikube instead of KinD:

```yaml
steps:
  - name: Set up Quick-K8s with Minikube
    uses: palmsoftware/quick-k8s@v0.0.61
    with:
      clusterProvider: minikube
      minikubeVersion: v1.38.1
      minikubeDriver: docker
```

### Using k3s as the Cluster Provider

To use k3s for a lightweight, fast-starting cluster:

```yaml
steps:
  - name: Set up Quick-K8s with k3s
    uses: palmsoftware/quick-k8s@v0.0.39
    with:
      clusterProvider: k3s
      k3sVersion: v1.35.3+k3s1
      numWorkerNodes: 1
      waitForPodsReady: true
```

**k3s Notes:**
- Linux-only (not supported on macOS runners)
- Single control plane node only (multi-CP not yet supported)
- Built-in Traefik and ServiceLB are disabled by default to avoid conflicts with the action's own ingress support
- `defaultNodeImage` and `ipFamily` inputs are ignored for k3s
- Includes built-in local-path storage provisioner and CoreDNS

### Complete Configuration (default values shown)

With KinD (default):

```yaml
steps:
  - name: Set up Quick-K8s
    uses: palmsoftware/quick-k8s@v0.0.61
    with:
      clusterProvider: kind
      clusterName: kind
      apiServerPort: 6443
      apiServerAddress: 0.0.0.0
      disableDefaultCni: true
      ipFamily: dual
      defaultNodeImage: 'kindest/node:v1.35.0@sha256:452d707d4862f52530247495d180205e029056831160e22870e37e3f6c1ac31f'
      kindVersion: v0.31.0
      calicoVersion: v3.31.4

      numControlPlaneNodes: 1
      numWorkerNodes: 1
      workerNodeLabels: ''          # Comma-separated key=value labels for worker nodes
      installOLM: false
      installIstio: false
      istioVersion: 1.29.1
      istioProfile: minimal
      installCertManager: false
      certManagerVersion: v1.20.2
      installIngressNginx: false
      ingressNginxVersion: v1.15.1
      installMetricsServer: false
      metricsServerVersion: v0.8.1
      installOperatorSdk: false
      operatorSdkVersion: v1.42.2
      removeDefaultStorageClass: false
      removeControlPlaneTaint: false

      # Advanced options
      installCalico: true           # Set to false to bring your own CNI
      kindConfigPath: ''            # Path to custom KinD config file
      installLocalRegistry: false   # Enable local Docker registry
      localRegistryPort: 5001       # Port for local registry
```

With Minikube:

```yaml
steps:
  - name: Set up Quick-K8s with Minikube
    uses: palmsoftware/quick-k8s@v0.0.61
    with:
      clusterProvider: minikube
      clusterName: kind
      minikubeVersion: v1.38.1
      minikubeDriver: docker
      apiServerPort: 6443
      disableDefaultCni: true
      defaultNodeImage: 'kindest/node:v1.35.0@sha256:452d707d4862f52530247495d180205e029056831160e22870e37e3f6c1ac31f'
      calicoVersion: v3.31.4

      numControlPlaneNodes: 1
      numWorkerNodes: 1
      workerNodeLabels: ''          # Comma-separated key=value labels for worker nodes
      installOLM: false
      installIstio: false
      istioVersion: 1.29.1
      istioProfile: minimal
      installCertManager: false
      certManagerVersion: v1.20.2
      installIngressNginx: false
      ingressNginxVersion: v1.15.1
      installMetricsServer: false
      metricsServerVersion: v0.8.1
      installOperatorSdk: false
      operatorSdkVersion: v1.42.2
      removeDefaultStorageClass: false
      removeControlPlaneTaint: false
```

With k3s:

```yaml
steps:
  - name: Set up Quick-K8s with k3s
    uses: palmsoftware/quick-k8s@v0.0.39
    with:
      clusterProvider: k3s
      k3sVersion: v1.35.3+k3s1
      apiServerPort: 6443
      disableDefaultCni: true
      calicoVersion: v3.30.3

      numControlPlaneNodes: 1
      numWorkerNodes: 1
      installOLM: false
      installIstio: false
      istioVersion: 1.28.1
      istioProfile: minimal
      installCertManager: false
      certManagerVersion: v1.19.3
      installIngressNginx: false
      ingressNginxVersion: v1.14.3
      installMetricsServer: false
      metricsServerVersion: v0.8.1
      installOperatorSdk: false
      operatorSdkVersion: v1.42.2
      removeDefaultStorageClass: false
      removeControlPlaneTaint: false
```

## Optional Features

### Installing Istio Service Mesh

Enable Istio installation to test service mesh functionality:

```yaml
steps:
  - name: Set up Quick-K8s with Istio
    uses: palmsoftware/quick-k8s@v0.0.61
    with:
      installIstio: true
      istioVersion: 1.29.1
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

### Installing cert-manager

Enable cert-manager for automatic TLS certificate management:

```yaml
steps:
  - name: Set up Quick-K8s with cert-manager
    uses: palmsoftware/quick-k8s@v0.0.61
    with:
      installCertManager: true
      certManagerVersion: v1.20.2
```

**Features**:
- Automatic TLS certificate provisioning for Kubernetes
- Supports Let's Encrypt, self-signed, and CA issuers
- Integrates with Ingress controllers for automatic certificate management
- CRDs installed automatically with cert-manager

**Example: Create a self-signed issuer for testing**:
```yaml
- name: Create self-signed issuer
  run: |
    cat <<EOF | kubectl apply -f -
    apiVersion: cert-manager.io/v1
    kind: ClusterIssuer
    metadata:
      name: selfsigned-issuer
    spec:
      selfSigned: {}
    EOF
    kubectl wait --for=condition=ready clusterissuer/selfsigned-issuer --timeout=60s
```

**⚠️ Resource Considerations**:
- cert-manager adds 3 pods to the cluster (controller, webhook, cainjector)
- Requires approximately 200-300MB additional memory
- Webhook startup may take 30-60 seconds
- Not supported on macOS due to Colima networking limitations

### Installing ingress-nginx

Enable NGINX Ingress controller for HTTP/HTTPS routing to your services:

```yaml
steps:
  - name: Set up Quick-K8s with ingress-nginx
    uses: palmsoftware/quick-k8s@v0.0.61
    with:
      installIngressNginx: true
      ingressNginxVersion: v1.15.1
```

**Features**:
- NGINX-based ingress controller for Kubernetes
- HTTP/HTTPS load balancing and routing
- TLS termination support
- Works seamlessly with cert-manager for automatic TLS certificates
- Provider-specific manifests for KinD (with host port bindings)

**Example: Create an Ingress resource**:
```yaml
- name: Create sample ingress
  run: |
    cat <<EOF | kubectl apply -f -
    apiVersion: networking.k8s.io/v1
    kind: Ingress
    metadata:
      name: example-ingress
    spec:
      ingressClassName: nginx
      rules:
        - host: example.local
          http:
            paths:
              - path: /
                pathType: Prefix
                backend:
                  service:
                    name: my-service
                    port:
                      number: 80
    EOF
```

**⚠️ Resource Considerations**:
- ingress-nginx adds 1-2 pods to the cluster (controller + optional admission webhook)
- Requires approximately 100-200MB additional memory
- For KinD, uses special manifest with host port mappings (ports 80 and 443)
- Controller startup may take 1-2 minutes

### Installing metrics-server

Enable metrics-server for resource monitoring and HPA (Horizontal Pod Autoscaler) support:

```yaml
steps:
  - name: Set up Quick-K8s with metrics-server
    uses: palmsoftware/quick-k8s@v0.0.61
    with:
      installMetricsServer: true
      metricsServerVersion: v0.8.1
```

**Features**:
- Enables `kubectl top nodes` and `kubectl top pods` commands
- Required for Horizontal Pod Autoscaler (HPA) based on CPU/memory
- Required for Vertical Pod Autoscaler (VPA)
- Lightweight cluster resource monitoring

**Example: Use kubectl top commands**:
```yaml
- name: View resource usage
  run: |
    # Wait for metrics to be available (takes ~30 seconds after startup)
    sleep 30
    kubectl top nodes
    kubectl top pods --all-namespaces
```

**Example: Create an HPA**:
```yaml
- name: Create HPA for deployment
  run: |
    # Requires metrics-server to be running
    kubectl autoscale deployment my-app --cpu-percent=50 --min=1 --max=10
    kubectl get hpa
```

**⚠️ Resource Considerations**:
- metrics-server adds 1 pod to the kube-system namespace
- Requires approximately 50-100MB additional memory
- Metrics API takes ~30 seconds after startup to populate
- Automatically patched with `--kubelet-insecure-tls` for local clusters (KinD/Minikube)

### Installing operator-sdk

Enable operator-sdk CLI installation for building and testing Kubernetes operators:

```yaml
steps:
  - name: Set up Quick-K8s with operator-sdk
    uses: palmsoftware/quick-k8s@v0.0.61
    with:
      installOperatorSdk: true
      operatorSdkVersion: v1.42.2
```

**Features**:
- CLI tool for scaffolding, building, and testing Kubernetes operators
- Supports Go, Ansible, and Helm-based operators
- Includes scorecard testing for operator validation
- Works with OLM for operator packaging and deployment

**Example: Scaffold and test an operator**:
```yaml
- name: Initialize operator project
  run: |
    mkdir my-operator && cd my-operator
    operator-sdk init --domain example.com --repo github.com/example/my-operator
    operator-sdk create api --group cache --version v1alpha1 --kind Memcached --resource --controller
```

**⚠️ Resource Considerations**:
- operator-sdk is a CLI tool only — it does not deploy any pods to the cluster
- Requires approximately 100MB disk space for the binary
- For full operator development workflows, consider also enabling OLM (`installOLM: true`)

### Bring Your Own CNI (Skip Calico)

For projects that need to install their own CNI (e.g., Multus, OVN-Kubernetes, Cilium), you can skip the default Calico installation:

```yaml
steps:
  - name: Set up Quick-K8s without Calico
    uses: palmsoftware/quick-k8s@v0.0.61
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
      cat > ${{ github.workspace }}/my-kind-config.yaml << 'EOF'
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
    uses: palmsoftware/quick-k8s@v0.0.61
    with:
      kindConfigPath: ${{ github.workspace }}/my-kind-config.yaml
```

**⚠️ Important**: Place the config file in `${{ github.workspace }}` or another persistent location. Files in `/tmp` may be cleaned up during the action's disk optimization step.

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
    uses: palmsoftware/quick-k8s@v0.0.61
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

All three cluster providers are fully supported and tested. Choose the one that best fits your needs:

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

#### k3s
- ✅ **Best for**: Resource-constrained runners, fastest startup
- ✅ **Advantages**:
  - Extremely lightweight (~60MB single binary, ~512MB RAM)
  - Fastest cluster startup (under 30 seconds)
  - CNCF certified Kubernetes distribution
  - Built-in local-path storage provisioner and CoreDNS
  - Runs natively on the host (no Docker dependency for the cluster itself)
- ⚠️ **Considerations**:
  - Linux-only (no macOS support)
  - Single control plane node only (multi-CP not yet supported)
  - `defaultNodeImage` and `ipFamily` inputs are not applicable
  - K8s version is determined by the k3s release version

**Recommendation**: Use **KinD** (default) for most CI/CD scenarios. Use **k3s** for the fastest, lightest clusters on Linux runners. Use **Minikube** if you need specific features or driver compatibility.

## Network Configuration

### IP Family Support

The action supports multiple IP family configurations for Kubernetes clusters:

```yaml
steps:
  - name: Set up Quick-K8s with IP family
    uses: palmsoftware/quick-k8s@v0.0.61
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

Originally built upon [KinD](https://github.com/kubernetes-sigs/kind) and tuned as part of [certsuite-sample-workload](https://github.com/redhat-best-practices-for-k8s/certsuite-sample-workload), the project now supports KinD, [Minikube](https://github.com/kubernetes/minikube), and [k3s](https://github.com/k3s-io/k3s) as cluster providers.

This action is essentially a wrapper around best practices for deploying Kubernetes environments that run well on GitHub Actions free-tier Ubuntu runners, with intelligent resource management and optimizations for CI/CD workflows.

## References

- [install-oc-tools.sh](./scripts/install-oc-tools.sh) was a script copied from [install-oc-tools](https://github.com/cptmorgan-rh/install-oc-tools) and slightly modified for `aarch64`.
- [douglascamata/setup-docker-macos-action@v1-alpha](https://github.com/marketplace/actions/setup-docker-on-macos) is brought to help install Docker on MacOS.
