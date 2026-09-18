[Back to README](../README.md)

# Configuration Reference

All inputs have sensible defaults. The basic usage requires no configuration at all.

## KinD (default)

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
      defaultNodeImage: 'kindest/node:v1.37.0@sha256:a1ed56cfb0e7b93589bdf97c8cd566405a265939e3620fc4f5de89adff580ae5'
      kindVersion: v0.33.0
      calicoVersion: v3.32.2
      ciliumVersion: v0.20.0        # Cilium CLI version (when cniPlugin: cilium)

      numControlPlaneNodes: 1
      numWorkerNodes: 1
      workerNodeLabels: ''          # Comma-separated key=value labels for worker nodes
      installOLM: false
      installIstio: false
      istioVersion: 1.31.0
      istioProfile: minimal
      installCertManager: false
      certManagerVersion: v1.21.2
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
      thanosVersion: v0.42.4

      # MetalLB
      installMetalLB: false
      metalLBVersion: v0.16.0

      # Advanced options
      cniPlugin: calico             # calico, cilium, or none
      kindConfigPath: ''            # Path to custom KinD config file
      installLocalRegistry: false   # Enable local Docker registry
      localRegistryPort: 5001       # Port for local registry
      olmVersion: v0.46.0           # OLM version (when installOLM: true)
      createPersistentVolumes: false # Create sample PVs for testing
      persistentVolumeCount: 5
      persistentVolumeSize: 10Gi
      installSampleNetworkPolicies: false
      waitForPodsReady: false       # Wait for all pods to be ready
      waitForPodsTimeout: 1200      # Pod readiness timeout in seconds
      waitForPodsNamespaces: ''     # Comma-separated list of namespaces to monitor
      waitForPodsExcludeNamespaces: '' # Comma-separated list of namespaces to exclude
      dryRun: false                 # Preview configuration without executing
      controlPlaneTaints: ''        # Comma-separated taints for control-plane nodes
      workerNodeTaints: ''          # Comma-separated taints for worker nodes
      extraPortMappings: ''         # Comma-separated host:container port mappings (KinD only)
      componentTimeout: 300         # Timeout in seconds for component installs
      enableCleanup: false          # Generate cleanup script at /tmp/quick-k8s-cleanup.sh
```

## Minikube

```yaml
steps:
  - name: Set up Quick-K8s with Minikube
    uses: palmsoftware/quick-k8s@v0
    with:
      clusterProvider: minikube
      clusterName: minikube
      minikubeVersion: v1.39.0
      minikubeDriver: docker
      apiServerPort: 6443
      disableDefaultCni: true
      calicoVersion: v3.32.2
      ciliumVersion: v0.20.0        # Cilium CLI version (when cniPlugin: cilium)
      clusterCPUs: 2                # CPUs to allocate (Minikube only)
      clusterMemory: ''             # Memory in MB (empty = provider default, Minikube only)

      numControlPlaneNodes: 1
      numWorkerNodes: 1
      workerNodeLabels: ''          # Comma-separated key=value labels for worker nodes
      installOLM: false
      installIstio: false
      istioVersion: 1.31.0
      istioProfile: minimal
      installCertManager: false
      certManagerVersion: v1.21.2
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
      thanosVersion: v0.42.4

      # MetalLB
      installMetalLB: false
      metalLBVersion: v0.16.0

      # Advanced options
      cniPlugin: calico             # calico, cilium, or none
      installSampleNetworkPolicies: false
      waitForPodsReady: false       # Wait for all pods to be ready
      waitForPodsTimeout: 1200      # Pod readiness timeout in seconds
      waitForPodsNamespaces: ''     # Comma-separated list of namespaces to monitor
      waitForPodsExcludeNamespaces: '' # Comma-separated list of namespaces to exclude
      createPersistentVolumes: false # Create sample PVs for testing
      persistentVolumeCount: 5
      persistentVolumeSize: 10Gi
      skipDiskCleanup: false        # Skip disk cleanup (useful for self-hosted runners)
      enableCleanup: false          # Generate cleanup script at /tmp/quick-k8s-cleanup.sh
      dryRun: false                 # Preview configuration without executing
      componentTimeout: 300         # Timeout in seconds for component installs
      controlPlaneTaints: ''        # Comma-separated taints for control-plane nodes
      workerNodeTaints: ''          # Comma-separated taints for worker nodes
```
