[Back to README](../README.md)

# Network Configuration

This guide covers networking configuration options for quick-k8s clusters.

## IP Family Support

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

**IPv6-Only Considerations**:
- IPv6-only mode (`ipFamily: ipv6`) is supported but may be unstable in certain CI environments
- GitHub Actions runners have limited IPv6 support, which can cause timeouts and networking issues
- **Recommended**: Use `dual` (dual-stack) for IPv6 functionality in CI/CD pipelines
- IPv6-only clusters are rare in production; dual-stack is the standard IPv6 deployment pattern
- If you need IPv6-only for testing, ensure your environment has proper IPv6 networking configured

## API Server Configuration

The API server can be configured to listen on specific addresses and ports:

```yaml
steps:
  - name: Configure API server
    uses: palmsoftware/quick-k8s@v0
    with:
      apiServerAddress: 0.0.0.0  # Listen on all interfaces (default)
      apiServerPort: 6443        # API server port (default)
```

**Use Cases**:
- **`0.0.0.0`** (default) - API server accessible from all network interfaces
- **`127.0.0.1`** - API server accessible only from localhost (more secure for local testing)
- Custom ports - Useful when port 6443 conflicts with other services

## Port Mappings (KinD Only)

KinD supports mapping container ports to host ports for NodePort services and testing:

```yaml
steps:
  - name: Set up with custom port mappings
    uses: palmsoftware/quick-k8s@v0
    with:
      extraPortMappings: '30000:30000,30001:30001,8080:8080'
```

This maps:
- Container port 30000 → Host port 30000
- Container port 30001 → Host port 30001
- Container port 8080 → Host port 8080

**Common Use Cases**:
- Exposing NodePort services for external testing
- Port forwarding for development
- Accessing services without `kubectl port-forward`

**Note**: Minikube does not support the `extraPortMappings` input. Use `minikube service` or `kubectl port-forward` instead.

## CNI Networking Differences

Different CNI plugins have different networking behaviors:

### Calico
- **Network Policy**: Full support for Kubernetes NetworkPolicy
- **IP Pools**: Uses BGP or VXLAN for pod networking
- **IPv6**: Full dual-stack and IPv6-only support
- **Resource Usage**: ~200MB RAM
- **Best For**: General-purpose networking with policy enforcement

### Cilium
- **Network Policy**: Full support plus extended CiliumNetworkPolicy CRDs
- **eBPF**: Kernel-level networking for better performance
- **Observability**: Built-in Hubble for network visibility
- **IPv6**: Full dual-stack and IPv6-only support
- **Resource Usage**: ~300-500MB RAM
- **Best For**: Advanced observability, performance, and security

### No CNI (Bring Your Own)
- Set `cniPlugin: none` to install your own CNI
- Cluster will not have pod networking until CNI is installed
- Pods remain in `Pending` state without a CNI
- Use `waitForPodsReady: false` to avoid timeouts

See [Optional Features - CNI Selection](optional-features.md#choosing-a-cni-plugin) for more details.

## Network Policies

Enable sample network policies for testing:

```yaml
steps:
  - name: Set up with network policies
    uses: palmsoftware/quick-k8s@v0
    with:
      installSampleNetworkPolicies: true
```

This creates example NetworkPolicy resources for common scenarios (allow/deny ingress/egress).

## Service Load Balancing

For LoadBalancer service support in local clusters, enable MetalLB:

```yaml
steps:
  - name: Set up with MetalLB
    uses: palmsoftware/quick-k8s@v0
    with:
      installMetalLB: true
```

See [Optional Features - MetalLB](optional-features.md#metallb) for details.
