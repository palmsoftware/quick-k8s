#!/bin/bash

# Check Docker is running
if ! docker info >/dev/null 2>&1; then
  echo "::error::Docker daemon is not running. Start Docker and try again."
  exit 1
fi

# Check minimum disk space before cleanup
available=$(df -BG /home 2>/dev/null | tail -1 | awk '{print $4}' | sed 's/G//' || df -BG . | tail -1 | awk '{print $4}' | sed 's/G//')
if [ "$available" -lt 5 ] 2>/dev/null; then
  echo "::error::Insufficient disk space (${available}GB available, need at least 5GB even after cleanup)"
  exit 1
fi

# Check API server port availability
API_PORT="${API_SERVER_PORT:-6443}"
if command -v ss >/dev/null 2>&1; then
  if ss -ltn | grep -q ":${API_PORT} "; then
    echo "::error::Port ${API_PORT} already in use. Stop existing cluster or choose different apiServerPort."
    exit 1
  fi
fi

echo "Pre-flight checks passed"
