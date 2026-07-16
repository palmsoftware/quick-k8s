# quick-k8s

[![Test Changes](https://github.com/palmsoftware/quick-k8s/actions/workflows/pre-main.yml/badge.svg)](https://github.com/palmsoftware/quick-k8s/actions/workflows/pre-main.yml)
[![Version Updates Nightly](https://github.com/palmsoftware/quick-k8s/actions/workflows/version-updates.yml/badge.svg)](https://github.com/palmsoftware/quick-k8s/actions/workflows/version-updates.yml)
[![Update OLM Version Nightly](https://github.com/palmsoftware/quick-k8s/actions/workflows/olm-update.yml/badge.svg)](https://github.com/palmsoftware/quick-k8s/actions/workflows/olm-update.yml)
[![Update Major Version Tag](https://github.com/palmsoftware/quick-k8s/actions/workflows/update-major-tag.yml/badge.svg)](https://github.com/palmsoftware/quick-k8s/actions/workflows/update-major-tag.yml)

Github Action that will automatically create a Kubernetes cluster that lives and runs on Github Actions to allow for deployment and testing of code.

Supports **KinD** (default) and **Minikube** as cluster providers.

## Requirements:

**Tested Runners:**

| Runner | Architecture | Status |
|--------|--------------|--------|
| `ubuntu-22.04` | x86_64 | ✅ Fully supported |
| `ubuntu-22.04-arm` | ARM64 | ✅ Fully supported |
| `ubuntu-24.04` | x86_64 | ✅ Fully supported |
| `ubuntu-24.04-arm` | ARM64 | ✅ Fully supported |
| `ubuntu-26.04` | x86_64 | ✅ Fully supported |

## Usage:

Basic Usage:
```
steps:
  - name: Set up Quick-K8s
    uses: palmsoftware/quick-k8s@v0
```

This will create you a default 1 worker and 1 control-plane cluster with calico CNI installed.  For additional feature enablement, please refer to the flags below:

### Using Minikube as the Cluster Provider

To use Minikube instead of KinD:

```yaml
steps:
  - name: Set up Quick-K8s with Minikube
    uses: palmsoftware/quick-k8s@v0
    with:
      clusterProvider: minikube
      minikubeVersion: v1.38.1
      minikubeDriver: docker
```

### Complete Configuration (default values shown)

With KinD (default):

```yaml
steps:
  - name: Set up Quick-K8s
    uses: palmsoftware/quick-k8s@v0
    with:
      clusterProvider: kind
      clusterName: kind
      apiServerPort: 6443
      apiServerAddress: 0.0.0.0
      disableDefaultCni: true
      ipFamily: dual
      defaultNodeImage: 'kindest/node:v1.36.1@sha256:3489c7674813ba5d8b1a9977baea8a6e553784dab7b84759d1014dbd78f7ebd5'
      kindVersion: v0.32.0
      calicoVersion: v3.32.1

      numControlPlaneNodes: 1
      numWorkerNodes: 1
      workerNodeLabels: ''          # Comma-separated key=value labels for worker nodes
      installOLM: false
      installIstio: false
      istioVersion: 1.30.2
      istioProfile: minimal
      installCertManager: false
      certManagerVersion: v1.21.0
      installIngressNginx: false
      ingressNginxVersion: v1.15.1
      installMetricsServer: false
      metricsServerVersion: v0.9.0
      installOperatorSdk: false
      operatorSdkVersion: v1.42.3
      removeDefaultStorageClass: false
      removeControlPlaneTaint: false

      # Monitoring
      enableClusterMonitoring: false
      kubePrometheusVersion: v0.18.0
      thanosVersion: v0.42.0

      # MetalLB
      installMetalLB: false
      metalLBVersion: v0.16.0

      # Advanced options
      cniPlugin: calico             # calico, cilium, flannel, or none
      kindConfigPath: ''            # Path to custom KinD config file
      installLocalRegistry: false   # Enable local Docker registry
      localRegistryPort: 5001       # Port for local registry
      olmVersion: v0.45.0           # OLM version (when installOLM: true)
      createPersistentVolumes: false # Create sample PVs for testing
      persistentVolumeCount: 5
      persistentVolumeSize: 10Gi
      installSampleNetworkPolicies: false
      waitForPodsTimeout: 1200      # Pod readiness timeout in seconds
      dryRun: false                 # Preview configuration without executing
```

With Minikube:

```yaml
steps:
  - name: Set up Quick-K8s with Minikube
    uses: palmsoftware/quick-k8s@v0
    with:
      clusterProvider: minikube
      clusterName: minikube
      minikubeVersion: v1.38.1
      minikubeDriver: docker
      apiServerPort: 6443
      disableDefaultCni: true
      calicoVersion: v3.32.1

      numControlPlaneNodes: 1
      numWorkerNodes: 1
      workerNodeLabels: ''          # Comma-separated key=value labels for worker nodes
      installOLM: false
      installIstio: false
      istioVersion: 1.30.2
      istioProfile: minimal
      installCertManager: false
      certManagerVersion: v1.21.0
      installIngressNginx: false
      ingressNginxVersion: v1.15.1
      installMetricsServer: false
      metricsServerVersion: v0.9.0
      installOperatorSdk: false
      operatorSdkVersion: v1.42.3
      removeDefaultStorageClass: false
      removeControlPlaneTaint: false
```

## Optional Features

### Installing Istio Service Mesh

Enable Istio installation to test service mesh functionality:

```yaml
steps:
  - name: Set up Quick-K8s with Istio
    uses: palmsoftware/quick-k8s@v0
    with:
      installIstio: true
      istioVersion: 1.30.2
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
    uses: palmsoftware/quick-k8s@v0
    with:
      installCertManager: true
      certManagerVersion: v1.21.0
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

### Installing ingress-nginx

Enable NGINX Ingress controller for HTTP/HTTPS routing to your services:

```yaml
steps:
  - name: Set up Quick-K8s with ingress-nginx
    uses: palmsoftware/quick-k8s@v0
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
    uses: palmsoftware/quick-k8s@v0
    with:
      installMetricsServer: true
      metricsServerVersion: v0.9.0
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
    uses: palmsoftware/quick-k8s@v0
    with:
      installOperatorSdk: true
      operatorSdkVersion: v1.42.3
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

### Installing MetalLB

Enable MetalLB for LoadBalancer service support on local clusters:

```yaml
steps:
  - name: Set up Quick-K8s with MetalLB
    uses: palmsoftware/quick-k8s@v0
    with:
      installMetalLB: true
      metalLBVersion: v0.16.0
```

**Features**:
- Provides LoadBalancer service support in local/CI Kubernetes clusters
- Automatically configures an IP address pool from the Docker bridge network
- L2 advertisement mode for simple, no-BGP-required operation
- Works with both KinD and Minikube providers

**Example: Create a LoadBalancer service**:
```yaml
- name: Deploy with LoadBalancer
  run: |
    kubectl create deployment nginx --image=nginx:latest
    kubectl expose deployment nginx --type=LoadBalancer --port=80
    kubectl wait --for=condition=ready pod -l app=nginx --timeout=60s
    # MetalLB will assign an external IP from the configured pool
    kubectl get svc nginx
```

**⚠️ Resource Considerations**:
- MetalLB adds 2 pods (controller + speaker daemonset) to the `metallb-system` namespace
- Requires approximately 100-200MB additional memory
- Address pool is automatically derived from the Docker bridge subnet

### Cluster Monitoring (kube-prometheus + Thanos)

Enable the full monitoring stack with Prometheus, Thanos, Alertmanager, and Grafana:

```yaml
steps:
  - name: Set up Quick-K8s with monitoring
    uses: palmsoftware/quick-k8s@v0
    with:
      enableClusterMonitoring: true
      kubePrometheusVersion: v0.18.0
      thanosVersion: v0.42.0
```

**Features**:
- Full kube-prometheus stack: Prometheus, Alertmanager, Grafana, node-exporter, kube-state-metrics
- Thanos sidecar for long-term storage and multi-cluster querying
- Pre-configured dashboards and alerting rules
- Resource requests automatically patched down to fit CI runners

**What gets deployed**:
| Component | Namespace | Purpose |
|-----------|-----------|---------|
| Prometheus | `monitoring` | Metrics collection and storage |
| Alertmanager | `monitoring` | Alert routing and deduplication |
| Grafana | `monitoring` | Dashboards and visualization |
| node-exporter | `monitoring` | Host-level metrics |
| kube-state-metrics | `monitoring` | Kubernetes object metrics |
| Thanos Sidecar | `monitoring` | Long-term storage interface |

**Example: Access monitoring data**:
```yaml
- name: Query Prometheus metrics
  run: |
    # Port-forward to Prometheus
    kubectl port-forward -n monitoring svc/prometheus-k8s 9090:9090 &
    sleep 5
    curl -s http://localhost:9090/api/v1/query?query=up | jq '.data.result | length'
```

**⚠️ Resource Considerations**:
- The monitoring stack is resource-intensive (~1-2GB RAM, 2+ CPU cores)
- Resource requests are automatically reduced for CI environments
- Consider using a runner with more resources or reducing other components
- Not recommended to combine with Istio on free-tier runners

### Choosing a CNI Plugin

The action supports multiple CNI plugins. Use the `cniPlugin` input to select one:

```yaml
steps:
  # Calico (default)
  - uses: palmsoftware/quick-k8s@v0
    with:
      cniPlugin: calico

  # Cilium
  - uses: palmsoftware/quick-k8s@v0
    with:
      cniPlugin: cilium

  # Flannel
  - uses: palmsoftware/quick-k8s@v0
    with:
      cniPlugin: flannel

  # No CNI (bring your own)
  - uses: palmsoftware/quick-k8s@v0
    with:
      cniPlugin: none
      waitForPodsReady: false
```

| CNI Plugin | Best For | Network Policies | Resource Usage |
|------------|----------|-----------------|----------------|
| **Calico** (default) | General purpose, policy enforcement | ✅ Full support | ~200MB |
| **Cilium** | eBPF-based networking, advanced observability | ✅ Full support | ~300-500MB |
| **Flannel** | Simple overlay networking, minimal overhead | ❌ Not supported | ~100MB |
| **none** | Bring your own CNI | Depends on CNI | N/A |

### Bring Your Own CNI (Skip Calico)

For projects that need to install their own CNI (e.g., Multus, OVN-Kubernetes, Cilium), you can skip the default Calico installation:

```yaml
steps:
  - name: Set up Quick-K8s without Calico
    uses: palmsoftware/quick-k8s@v0
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
    uses: palmsoftware/quick-k8s@v0
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
    uses: palmsoftware/quick-k8s@v0
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
  - Configurable CPU/memory limits (`clusterCPUs`, `clusterMemory`)
- ⚠️ **Considerations**: 
  - Slightly slower startup, more complex for multi-node setups
  - When disabling default CNI (`disableDefaultCni: true`), uses docker runtime instead of containerd (Minikube requirement)
  - **Multi-node limitation**: Minikube's `--nodes=N` creates N identical nodes with no control-plane vs worker distinction. All nodes have the same role regardless of `numControlPlaneNodes` and `numWorkerNodes` settings. If you need explicit control-plane/worker topology, use KinD.

**Recommendation**: Use **KinD** (default) for most CI/CD scenarios. Use **Minikube** if you need specific features or driver compatibility.

## Network Configuration

### IP Family Support

The action supports multiple IP family configurations for Kubernetes clusters:

```yaml
steps:
  - name: Set up Quick-K8s with IP family
    uses: palmsoftware/quick-k8s@v0
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

## Using the Cluster in Downstream Steps

The action installs `kubectl` (and `oc` on Linux) and configures kubeconfig automatically. No extra setup is needed in subsequent workflow steps.

```yaml
steps:
  - uses: palmsoftware/quick-k8s@v0

  - name: Verify cluster
    run: |
      kubectl get nodes
      kubectl cluster-info

  - name: Deploy a test application
    run: |
      kubectl create deployment nginx --image=nginx:latest
      kubectl wait --for=condition=ready pod -l app=nginx --timeout=60s
```

### Kubeconfig and Context

- **Kubeconfig**: `~/.kube/config` (no need to set `KUBECONFIG`)
- **kubectl and oc**: Already in `PATH`, ready to use

**Context names by provider**:

| Provider | Context Name |
|----------|-------------|
| KinD | `kind-<clusterName>` (e.g., `kind-kind`) |
| Minikube | `minikube` |

### Storage Class

| Provider | Default Storage Class |
|----------|----------------------|
| KinD | `standard` |
| Minikube | `standard` |

## Resource Requirements

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

**Recommended combinations for free-tier runners**:
- ✅ Basic + Calico + OLM + cert-manager (~3GB RAM)
- ✅ Basic + Calico + Istio minimal (~2.5GB RAM)
- ✅ Basic + Calico + ingress-nginx + metrics-server (~2.5GB RAM)
- ⚠️ Basic + Calico + OLM + Istio (~3.5GB RAM, tight fit)
- ❌ Basic + monitoring stack + Istio (~4.5GB RAM, likely OOM)

**Tips**:
- Use `numWorkerNodes: 0` for single-node clusters to save ~1GB RAM
- Use `skipDiskCleanup: true` on self-hosted runners with ample disk
- The `dryRun: true` option previews the configuration without creating anything

## Troubleshooting

### Disk Space

**"No space left on device"**
- GitHub Actions free-tier runners have ~14GB available disk
- Reduce cluster footprint: fewer worker nodes, skip OLM/Istio/monitoring
- The action runs adaptive cleanup automatically, but very large add-on combinations can still exhaust disk

### KinD

**"Failed to pre-pull image" or image pull timeout**
- Docker Hub rate limiting (100 pulls/6 hours unauthenticated). Re-run the workflow or configure Docker Hub credentials.

**Cluster creation hangs**
- Check available disk with `df -h`. Minimum 8GB free is required.

### Minikube

**"execution phase cni-install failed"**
- When `disableDefaultCni: true`, Minikube requires Docker runtime (not containerd). The action handles this automatically. If you see this error with a custom configuration, ensure `--container-runtime=docker` is set.

**Multi-node topology**
- Minikube's `--nodes=N` creates N identical nodes. There is no control-plane vs worker distinction — all nodes have the same role. If you need explicit topology, use KinD.
- The action passes `numControlPlaneNodes + numWorkerNodes` as the total node count to Minikube, but all nodes are functionally equivalent.

**"Specified Kubernetes version X is newer than the newest supported version"**
- The action automatically falls back to Minikube's latest supported Kubernetes version when this happens. A `::warning::` annotation will appear in the logs.

### Add-on Issues

**"cert-manager webhook not ready"**
- Webhook startup is slow on CI runners. Add a wait step:
  ```yaml
  - name: Wait for cert-manager webhook
    run: kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=webhook -n cert-manager --timeout=120s
  ```

**Istio installation timeout**
- Reduce worker nodes, use `istioProfile: minimal`, or increase pod readiness timeout

**"Local registry not accessible from cluster"**
- For KinD: registry is automatically connected to the Docker network
- For Minikube: local registry connectivity is limited (see [#74](https://github.com/palmsoftware/quick-k8s/issues/74))

## Examples

The [`examples/`](./examples/) directory contains copy-paste-ready workflow recipes:

| Example | Description |
|---------|-------------|
| [basic-cluster.yml](./examples/basic-cluster.yml) | Minimal cluster for CI testing |
| [istio-service-mesh.yml](./examples/istio-service-mesh.yml) | Cluster with Istio and sidecar injection |
| [monitoring-stack.yml](./examples/monitoring-stack.yml) | Full Prometheus/Thanos/Grafana stack |
| [multi-node-cluster.yml](./examples/multi-node-cluster.yml) | Multi-node with labels and topology spread |
| [custom-cni.yml](./examples/custom-cni.yml) | Cilium and Flannel CNI examples |
| [local-registry.yml](./examples/local-registry.yml) | Local Docker registry for image builds |
| [operator-development.yml](./examples/operator-development.yml) | OLM + operator-sdk + cert-manager |
| [full-stack.yml](./examples/full-stack.yml) | All components combined |

## Version Compatibility

See [COMPATIBILITY.md](./COMPATIBILITY.md) for the full component version compatibility matrix, including tested combinations and known issues.

## History

Originally built upon [KinD](https://github.com/kubernetes-sigs/kind) and tuned as part of [certsuite-sample-workload](https://github.com/redhat-best-practices-for-k8s/certsuite-sample-workload), the project now supports KinD and [Minikube](https://github.com/kubernetes/minikube) as cluster providers.

This action is essentially a wrapper around best practices for deploying Kubernetes environments that run well on GitHub Actions free-tier Ubuntu runners, with intelligent resource management and optimizations for CI/CD workflows.

## References

- [install-oc-tools.sh](./scripts/install-oc-tools.sh) was a script copied from [install-oc-tools](https://github.com/cptmorgan-rh/install-oc-tools) and slightly modified for `aarch64`.
