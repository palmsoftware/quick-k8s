[Back to README](../README.md)

# Optional Features

- [Istio Service Mesh](#istio-service-mesh)
- [cert-manager](#cert-manager)
- [ingress-nginx](#ingress-nginx)
- [metrics-server](#metrics-server)
- [operator-sdk](#operator-sdk)
- [MetalLB](#metallb)
- [Cluster Monitoring (kube-prometheus + Thanos)](#cluster-monitoring-kube-prometheus--thanos)
- [Choosing a CNI Plugin](#choosing-a-cni-plugin)
- [Bring Your Own CNI](#bring-your-own-cni)
- [Custom KinD Configuration](#custom-kind-configuration)
- [Local Docker Registry](#local-docker-registry)

---

## Istio Service Mesh

Enable Istio installation to test service mesh functionality:

```yaml
steps:
  - name: Set up Quick-K8s with Istio
    uses: palmsoftware/quick-k8s@v0
    with:
      installIstio: true
      istioVersion: 1.30.3
      istioProfile: minimal
```

**Available Istio Profiles**:
- `minimal` (default) - Essential components only, lowest resource usage (~300MB)
- `demo` - For demos and exploration (~500MB) 
- `default` - Production-ready baseline (~400MB)
- `preview` - Preview profile with experimental features
- `ambient` - Ambient mesh mode (sidecar-less)
- `empty` - Deploys nothing, for custom configurations

**Resource Considerations**:
- Istio adds significant overhead to cluster startup time (2-5 minutes)
- The `minimal` profile is recommended for CI/CD to reduce resource consumption
- Consider reducing worker nodes or using runners with more resources when enabling Istio
- Istio control plane requires ~300-500MB additional memory depending on profile

## cert-manager

Enable cert-manager for automatic TLS certificate management:

```yaml
steps:
  - name: Set up Quick-K8s with cert-manager
    uses: palmsoftware/quick-k8s@v0
    with:
      installCertManager: true
      certManagerVersion: v1.21.1
```

**Features**:
- Automatic TLS certificate provisioning for Kubernetes
- Supports Let's Encrypt, self-signed, and CA issuers
- Integrates with Ingress controllers for automatic certificate management
- CRDs installed automatically with cert-manager

**Pre-configured ClusterIssuer**: A `selfsigned-issuer` ClusterIssuer is automatically created during installation — no manual setup needed.

**Example: Create a Certificate using the pre-configured issuer**:
```yaml
- name: Create a test certificate
  run: |
    cat <<EOF | kubectl apply -f -
    apiVersion: cert-manager.io/v1
    kind: Certificate
    metadata:
      name: my-app-tls
      namespace: default
    spec:
      secretName: my-app-tls-secret
      dnsNames:
        - my-app.example.com
      issuerRef:
        name: selfsigned-issuer
        kind: ClusterIssuer
    EOF
    kubectl wait --for=condition=ready certificate/my-app-tls --timeout=60s
```

**Resource Considerations**:
- cert-manager adds 3 pods to the cluster (controller, webhook, cainjector)
- Requires approximately 200-300MB additional memory
- Webhook startup may take 30-60 seconds

## ingress-nginx

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

**Resource Considerations**:
- ingress-nginx adds 1-2 pods to the cluster (controller + optional admission webhook)
- Requires approximately 100-200MB additional memory
- For KinD, uses special manifest with host port mappings (ports 80 and 443)
- Controller startup may take 1-2 minutes

## metrics-server

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

**Resource Considerations**:
- metrics-server adds 1 pod to the kube-system namespace
- Requires approximately 50-100MB additional memory
- Metrics API takes ~30 seconds after startup to populate
- Automatically patched with `--kubelet-insecure-tls` for local clusters (KinD/Minikube)

## operator-sdk

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

**Resource Considerations**:
- operator-sdk is a CLI tool only — it does not deploy any pods to the cluster
- Requires approximately 100MB disk space for the binary
- For full operator development workflows, consider also enabling OLM (`installOLM: true`)

## MetalLB

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

**Resource Considerations**:
- MetalLB adds 2 pods (controller + speaker daemonset) to the `metallb-system` namespace
- Requires approximately 100-200MB additional memory
- Address pool is automatically derived from the Docker bridge subnet

## Cluster Monitoring (kube-prometheus + Thanos)

Enable the full monitoring stack with Prometheus, Thanos, Alertmanager, and more:

```yaml
steps:
  - name: Set up Quick-K8s with monitoring
    uses: palmsoftware/quick-k8s@v0
    with:
      enableClusterMonitoring: true
      kubePrometheusVersion: v0.18.0
      thanosVersion: v0.42.4
```

**Features**:
- Full kube-prometheus stack: Prometheus, Alertmanager, node-exporter, kube-state-metrics
- Thanos sidecar for long-term storage and multi-cluster querying
- Resource requests automatically patched down to fit CI runners

**Components Deployed**:
| Component | Namespace | Purpose |
|-----------|-----------|---------|
| Prometheus | `monitoring` | Metrics collection and storage |
| Alertmanager | `monitoring` | Alert routing and deduplication |
| Grafana | `monitoring` | Dashboards and visualization (scaled to 0 by default — see note) |
| node-exporter | `monitoring` | Host-level metrics |
| kube-state-metrics | `monitoring` | Kubernetes object metrics |
| Thanos Sidecar | `monitoring` | Long-term storage interface |

> **Note:** Grafana is included in the kube-prometheus manifests but is **scaled to 0 replicas** by default because it is too resource-heavy for free-tier CI runners. To re-enable it, scale the deployment after cluster creation:
> ```bash
> kubectl scale deployment -n monitoring grafana --replicas=1
> ```

**Example: Access monitoring data**:
```yaml
- name: Query Prometheus metrics
  run: |
    # Port-forward to Prometheus
    kubectl port-forward -n monitoring svc/prometheus-k8s 9090:9090 &
    sleep 5
    curl -s http://localhost:9090/api/v1/query?query=up | jq '.data.result | length'
```

**Resource Considerations**:
- The monitoring stack is resource-intensive (~1-2GB RAM, 2+ CPU cores)
- Resource requests are automatically reduced for CI environments
- Consider using a runner with more resources or reducing other components
- Not recommended to combine with Istio on free-tier runners

## Choosing a CNI Plugin

The action supports multiple CNI plugins. Use the `cniPlugin` input to select one:

> **Note:** The deprecated `installCalico` input (boolean) will be removed in v2.0.0. Use `cniPlugin: calico` instead for future compatibility.

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

  # No CNI (bring your own)
  - uses: palmsoftware/quick-k8s@v0
    with:
      cniPlugin: none
      waitForPodsReady: false
```

| CNI Plugin | Best For | Network Policies | Resource Usage |
|------------|----------|-----------------|----------------|
| **Calico** (default) | General purpose, policy enforcement | Full support | ~200MB |
| **Cilium** | eBPF-based networking, advanced observability | Full support | ~300-500MB |
| **none** | Bring your own CNI | Depends on CNI | N/A |

## Bring Your Own CNI

For projects that need to install their own CNI (e.g., Multus, OVN-Kubernetes), you can skip the default CNI installation:

```yaml
steps:
  - name: Set up Quick-K8s without CNI
    uses: palmsoftware/quick-k8s@v0
    with:
      disableDefaultCni: true
      cniPlugin: none             # Skip CNI installation
      waitForPodsReady: false     # Don't wait - no CNI means pods won't be ready

  - name: Install your own CNI
    run: |
      # Example: Install Multus
      kubectl apply -f https://raw.githubusercontent.com/k8snetworkplumbingwg/multus-cni/master/deployments/multus-daemonset.yml
```

**Important Notes**:
- When `cniPlugin: none`, the cluster will not have a functional CNI
- Pods will remain in `Pending` state until you install a CNI
- Set `waitForPodsReady: false` to avoid timeouts waiting for pods
- This is ideal for projects testing their own CNI implementations

## Custom KinD Configuration

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

**Important**: Place the config file in `${{ github.workspace }}` or another persistent location. Files in `/tmp` may be cleaned up during the action's disk optimization step.

**Use cases for custom configuration**:
- Extra port mappings for NodePort services
- Custom node labels and taints
- Specific container runtime settings
- Advanced networking configurations
- Testing multi-zone setups

## Local Docker Registry

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
