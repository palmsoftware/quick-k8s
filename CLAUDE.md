# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**quick-k8s** is a GitHub Action for deploying Kubernetes clusters on GitHub Actions runners. It's a composite action using shell scripts that supports KinD (Kubernetes in Docker) and Minikube as cluster providers, with optional CNI (Calico or Cilium), Istio service mesh, OLM (Operator Lifecycle Manager), and local Docker registry.

**Target Environment**: Linux (Ubuntu 22.04/24.04/26.04, x86 and ARM64).

## Commands

```bash
# Lint all shell scripts with shellcheck
make lint

# Check shellcheck installation
make tool-precheck

# Clean temporary files
make clean
```

## Architecture

### Composite Action Flow

The action executes in sequence via `action.yml`:
1. **Input validation** - Validates all inputs (versions, providers, ports, node counts)
2. **GitHub status check** - Verifies GitHub services are operational
3. **Disk optimization** - Uses `palmsoftware/quick-cleanup` for adaptive disk management
4. **Binary installation** - Installs KinD or Minikube (with caching)
5. **Cluster creation** - Creates cluster using generated or custom config
6. **CNI installation** - Installs Calico or Cilium (optional, can be skipped for bring-your-own-CNI)
7. **Optional features** - OLM, Istio, local registry
8. **Cleanup** - Removes temporary files

### Script Organization (`/scripts/`)

Each script handles a single responsibility:
- `install-kind.sh`, `install-minikube.sh` - Binary installation with fallback URLs
- `generate-kind-config.sh` - Creates KinD YAML config from action inputs
- `start-minikube.sh` - Starts Minikube with appropriate flags
- `install-calico.sh`, `install-cilium.sh`, `install-istio.sh`, `install-olm.sh`, `install-metallb.sh` - Component installers
- `setup-local-registry.sh` - Docker registry setup with cluster connectivity
- `pre-cluster-optimization.sh` - Disk space management
- `check-github-status.sh` - GitHub API availability check

### Version Management

Nightly workflows auto-update dependency versions in `action.yml`:
- `version-updates.yml` - Calico, Istio, Minikube, cert-manager, ingress-nginx, metrics-server
- `olm-update.yml` - Operator Lifecycle Manager
- `kind-node-image-update.yml` - KinD default node image

Updates fetch latest versions from GitHub API, validate semver format, and create PRs via `peter-evans/create-pull-request`.

## Key Patterns

### Shell Script Standards

- **Linting**: All scripts in `scripts/` must pass shellcheck
- **Retry logic**: GitHub API calls use 3-attempt retry with exponential backoff
- **Architecture mapping**: Converts GitHub Actions arch (`x64`, `arm64`) to tool-specific names (`amd64`, `arm64`)
- **Fallback URLs**: Primary download + fallback for reliability
- **Binary caching**: Binaries cached in `/tmp/` for reuse across workflow runs

### Minikube CNI Constraint

When `disableDefaultCni: true`, Minikube **must** use Docker runtime (not containerd). This is enforced in `start-minikube.sh`:
```bash
if [ "$DISABLE_CNI" = "true" ]; then
  MINIKUBE_CMD="$MINIKUBE_CMD --container-runtime=docker"
fi
```

### Kubernetes Version Extraction

Minikube extracts K8s version from the node image tag:
```bash
K8S_VERSION=$(echo "$NODE_IMAGE" | sed -E 's/.*:([^@]+)@.*/\1/')
```

## CI Workflows

### `pre-main.yml` - Primary CI
- Triggers: Push to main, PRs, manual dispatch
- **Lint job blocks all other jobs** - Must pass before tests run
- Matrix: 4 OS (ubuntu-{22,24}.04 × {x86,arm}) × 2 providers (KinD, Minikube)
- Tests: Basic cluster, OLM, Istio, local registry, custom config, CNI skip

### `nightly.yml` - Extended Testing
- Triggers: Daily at midnight UTC
- Multi-node cluster tests
- Resource optimization verification

## Important Implementation Details

### Disk Space Management

GitHub Actions free-tier runners have limited disk. The action:
1. Uses `palmsoftware/quick-cleanup@v0` for intelligent adaptive cleanup
2. Relocates Docker/containerd storage to larger `/mnt` partition
3. Validates minimum 8GB free before cluster creation
4. Runs `pre-cluster-optimization.sh` for final cleanup before cluster start

### Local Registry Setup

When `installLocalRegistry: true`:
- Starts `registry:2` container on specified port
- Connects to KinD network (for KinD provider)
- Creates ConfigMap in `kube-public` for discoverability
- Accessible at `localhost:<port>` from host and cluster

### Input Validation

All version inputs are validated:
- Semver format check via regex
- GitHub API validation to confirm release exists
- Retry logic for flaky API calls

## Release Process

- Semantic versioning (v0.0.x)
- `update-major-tag.yml` maintains major version tags (v0)
- Pre-main tests must pass before release
