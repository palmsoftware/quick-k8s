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
      defaultNodeImage: 'kindest/node:v1.36.1@sha256:3489c7674813ba5d8b1a9977baea8a6e553784dab7b84759d1014dbd78f7ebd5'
      kindVersion: v0.32.0
      calicoVersion: v3.32.1

      numControlPlaneNodes: 1
      numWorkerNodes: 1
      workerNodeLabels: ''          # Comma-separated key=value labels for worker nodes
      installOLM: false
      installIstio: false
      istioVersion: 1.30.3
      istioProfile: minimal
      installCertManager: false
      certManagerVersion: v1.21.1
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
      thanosVersion: v0.42.2

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
      waitForPodsTimeout: 1200      # Pod readiness timeout in seconds
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
      istioVersion: 1.30.3
      istioProfile: minimal
      installCertManager: false
      certManagerVersion: v1.21.1
      installIngressNginx: false
      ingressNginxVersion: v1.15.1
      installMetricsServer: false
      metricsServerVersion: v0.9.0
      installOperatorSdk: false
      operatorSdkVersion: v1.42.3
      removeDefaultStorageClass: false
      removeControlPlaneTaint: false
```
