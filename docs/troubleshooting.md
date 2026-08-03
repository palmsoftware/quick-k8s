[Back to README](../README.md)

# Troubleshooting

## Disk Space

**"No space left on device"**
- GitHub Actions free-tier runners have ~14GB available disk
- Reduce cluster footprint: fewer worker nodes, skip OLM/Istio/monitoring
- The action runs adaptive cleanup automatically, but very large add-on combinations can still exhaust disk

## KinD

**"Failed to pre-pull image" or image pull timeout**
- Docker Hub rate limiting (100 pulls/6 hours unauthenticated). Re-run the workflow or configure Docker Hub credentials.

**Cluster creation hangs**
- Check available disk with `df -h`. Minimum 8GB free is required.

## Minikube

**"execution phase cni-install failed"**
- When `disableDefaultCni: true`, Minikube requires Docker runtime (not containerd). The action handles this automatically. If you see this error with a custom configuration, ensure `--container-runtime=docker` is set.

**Multi-node topology**
- Minikube's `--nodes=N` creates N identical nodes. There is no control-plane vs worker distinction — all nodes have the same role. If you need explicit topology, use KinD.
- The action passes `numControlPlaneNodes + numWorkerNodes` as the total node count to Minikube, but all nodes are functionally equivalent.

**"Specified Kubernetes version X is newer than the newest supported version"**
- The action automatically falls back to Minikube's latest supported Kubernetes version when this happens. A `::warning::` annotation will appear in the logs.

## Add-on Issues

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
