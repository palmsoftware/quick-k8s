[Back to README](../README.md)

# Cluster Provider Comparison

Both cluster providers are fully supported and tested. Choose the one that best fits your needs:

## KinD (Kubernetes in Docker) - Default

- **Best for**: CI/CD pipelines, fast cluster creation
- **Advantages**: 
  - Faster startup time
  - Native multi-node support with simple configuration
  - Designed specifically for testing
  - Lower resource overhead
- **Considerations**: Limited to Docker as the runtime

## Minikube

- **Best for**: Development environments, feature parity with production
- **Advantages**:
  - More mature and feature-rich
  - Multiple driver options (docker, podman, none)
  - Better local development experience
  - Built-in addons system
  - Configurable CPU/memory limits (`clusterCPUs`, `clusterMemory`)
- **Considerations**: 
  - Slightly slower startup, more complex for multi-node setups
  - When disabling default CNI (`disableDefaultCni: true`), uses docker runtime instead of containerd (Minikube requirement)
  - **Multi-node limitation**: Minikube's `--nodes=N` creates N identical nodes with no control-plane vs worker distinction. All nodes have the same role regardless of `numControlPlaneNodes` and `numWorkerNodes` settings. If you need explicit control-plane/worker topology, use KinD.

**Recommendation**: Use **KinD** (default) for most CI/CD scenarios. Use **Minikube** if you need specific features or driver compatibility.
