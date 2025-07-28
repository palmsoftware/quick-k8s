# quick-k8s
Github Action that will automatically create a Kubernetes cluster that lives and runs on Github Actions to allow for deployment and testing of code.

## Requirements:

Linux (ARM and x86) Runners and MacOS-13 runners are supported.  See [this](https://github.com/marketplace/actions/setup-docker-on-macos#arm64-processors-m1-m2-m3-series-used-on-macos-14-images-are-unsupported) for more information about when other Mac runners will be available.

## Usage:

Basic Usage:
```
steps:
  - name: Set up Quick-K8s
    uses: palmsoftware/quick-k8s@v0.0.35
```

This will create you a default 1 worker and 1 control-plane cluster with calico CNI installed.  For additional feature enablement, please refer to the flags below:

With Flags (default values shown):

```
steps:
  - name: Set up Quick-K8s
    uses: palmsoftware/quick-k8s@v0.0.35
    with:
      apiServerPort: 6443
      apiServerAddress: 0.0.0.0
      disableDefaultCni: true
      ipFamily: dual
      defaultNodeImage: 'kindest/node:v1.33.1@sha256:050072256b9a903bd914c0b2866828150cb229cea0efe5892e2b644d5dd3b34f'
      numControlPlaneNodes: 1
      numWorkerNodes: 1
      installOLM: false
      removeDefaultStorageClass: false
      removeControlPlaneTaint: false
```

## History

The proof-of-concept is built upon [KinD](https://github.com/kubernetes-sigs/kind) and was tuned as part of [certsuite-sample-workload](https://github.com/redhat-best-practices-for-k8s/certsuite-sample-workload).

This action is essentially a wrapper around some tried and true best practices for deploying a Kubernetes environment that runs well on Github Actions free-tier Ubuntu runner.

## References

- [install-oc-tools.sh](./scripts/install-oc-tools.sh) was a script copied from [install-oc-tools](https://github.com/cptmorgan-rh/install-oc-tools) and slightly modified for `aarch64`.
- [douglascamata/setup-docker-macos-action@v1-alpha](https://github.com/marketplace/actions/setup-docker-on-macos) is brought to help install Docker on MacOS.
