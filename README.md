# quick-k8s
Github Action that will automatically create a Kubernetes cluster that lives and runs on Github Actions

## Usage:

Basic Usage:
```
steps:
  - name: Set up Quick-K8s
    uses: palmsoftware/quick-k8s@v0.0.11
```

With Flags (default values shown):

```
steps:
  - name: Set up Quick-K8s
    uses: palmsoftware/quick-k8s@v0
    with:
      apiServerPort: 6443
      apiServerAddress: 0.0.0.0
      disableDefaultCni: true
      ipFamily: dual
      defaultNodeImage: 'kindest/node:v1.31.2@sha256:18fbefc20a7113353c7b75b5c869d7145a6abd6269154825872dc59c1329912e'
      numControlPlaneNodes: 1
      numWorkerNodes: 1
      installOLM: false
```

## History

The proof-of-concept is built upon [KinD](https://github.com/kubernetes-sigs/kind) and was tuned as part of [certsuite-sample-workload](https://github.com/redhat-best-practices-for-k8s/certsuite-sample-workload).

This action is essentially a wrapper around some tried and true best practices for deploying a Kubernetes environment that runs well on Github Actions free-tier Ubuntu runner.
