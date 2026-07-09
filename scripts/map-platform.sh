#!/usr/bin/env bash
# Sourceable utility that defines map_os() and map_arch() functions.
# Maps platform names to Go-style conventions (linux/darwin, amd64/arm64).
#
# Usage:
#   source "$(dirname "$0")/map-platform.sh"
#   OS=$(map_os "$OS")        # macos → darwin, Linux → linux
#   ARCH=$(map_arch "$ARCH")  # x64/x86_64 → amd64, aarch64 → arm64

map_os() {
  local os="${1:-$(uname -s)}"
  os=$(echo "$os" | tr '[:upper:]' '[:lower:]')
  case "$os" in macos) os="darwin" ;; esac
  echo "$os"
}

map_arch() {
  local arch="${1:-$(uname -m)}"
  arch=$(echo "$arch" | tr '[:upper:]' '[:lower:]')
  case "$arch" in x86_64|x64) arch="amd64" ;; aarch64) arch="arm64" ;; esac
  echo "$arch"
}
