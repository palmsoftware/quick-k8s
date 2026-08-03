[Back to README](../README.md)

# Using the Cluster in Downstream Steps

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

## Kubeconfig and Context

- **Kubeconfig**: `~/.kube/config` (no need to set `KUBECONFIG`)
- **kubectl and oc**: Already in `PATH`, ready to use

**Context names by provider**:

| Provider | Context Name |
|----------|-------------|
| KinD | `kind-<clusterName>` (e.g., `kind-kind`) |
| Minikube | `minikube` |

## Storage Class

| Provider | Default Storage Class |
|----------|----------------------|
| KinD | `standard` |
| Minikube | `standard` |
