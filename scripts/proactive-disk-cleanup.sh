#!/usr/bin/env bash

# Proactive Disk Space Cleanup for GitHub Actions Runners
# This script intelligently manages disk space by performing adaptive cleanup
# based on available space and removing unnecessary packages/directories.

set -e

echo "=============================================="
echo "🧹 PROACTIVE DISK SPACE MANAGEMENT"
echo "=============================================="
echo "=== Initial disk usage ==="
df -h
echo ""
echo "=== Initial system info ==="
echo "OS: $(lsb_release -d | cut -f2)"
echo "Architecture: $(uname -m)"
echo "Memory: $(free -h | grep '^Mem:' | awk '{print $2}')"
echo "CPU: $(nproc) cores"

# Check if we already have plenty of space
INITIAL_AVAILABLE_KB=$(df / | tail -1 | awk '{print $4}')
INITIAL_AVAILABLE_GB=$((INITIAL_AVAILABLE_KB / 1024 / 1024))
echo ""
echo "🔍 Initial available space: ${INITIAL_AVAILABLE_GB}GB"

if [ $INITIAL_AVAILABLE_GB -gt 20 ]; then
  echo "✨ Plenty of space available! Will perform light cleanup only."
  LIGHT_CLEANUP=1
else
  echo "⚠️  Limited space detected. Will perform aggressive cleanup."
  LIGHT_CLEANUP=0
fi

echo "=== Cleaning package caches ==="
sudo apt-get clean
sudo apt-get autoremove -y --purge

echo "=== Checking installed packages that consume significant space ==="
LARGE_PACKAGES="mysql-server-core-8.0 mysql-client-core-8.0 postgresql-14 postgresql-client-14 firefox google-chrome-stable microsoft-edge-stable thunderbird mono-complete azure-cli powershell kubectl helm"

# Safely get .NET packages
DOTNET_PACKAGES=""
if dpkg -l 2>/dev/null | grep -E "(dotnet-sdk|dotnet-runtime|aspnetcore-runtime)" >/dev/null 2>&1; then
  DOTNET_PACKAGES=$(dpkg -l 2>/dev/null | grep -E "(dotnet-sdk|dotnet-runtime|aspnetcore-runtime)" | awk '{print $2}' | tr '\n' ' ' || true)
fi

# Safely get Google Cloud packages  
GOOGLE_PACKAGES=""
if dpkg -l 2>/dev/null | grep google-cloud-sdk >/dev/null 2>&1; then
  GOOGLE_PACKAGES=$(dpkg -l 2>/dev/null | grep google-cloud-sdk | awk '{print $2}' | tr '\n' ' ' || true)
fi

PACKAGES_TO_REMOVE=""
for pkg in $LARGE_PACKAGES $DOTNET_PACKAGES $GOOGLE_PACKAGES; do
  # Skip empty package names
  if [ -z "$pkg" ]; then
    continue
  fi
  
  # Check if package is installed
  if dpkg -l "$pkg" 2>/dev/null | grep -q "^ii.*$pkg" 2>/dev/null; then
    PACKAGES_TO_REMOVE="$PACKAGES_TO_REMOVE $pkg"
    echo "📦 Found: $pkg"
  fi
done

if [ -n "$PACKAGES_TO_REMOVE" ]; then
  echo "=== Removing large unnecessary packages ==="
  echo "Removing:$PACKAGES_TO_REMOVE"
  sudo apt-get remove -y --purge "$PACKAGES_TO_REMOVE" || true
  REMOVED_COUNT=$(echo "$PACKAGES_TO_REMOVE" | wc -w)
  echo "✓ Attempted to remove $REMOVED_COUNT large packages"
else
  echo "✓ No large packages found to remove"
fi

echo "=== Cleaning snap packages ==="
sudo snap list --all | awk '/disabled/{print $1, $3}' | while read -r snapname revision; do
  sudo snap remove "$snapname" --revision="$revision" || true
done

echo "=== Checking for Android SDK ==="
ANDROID_DIRS="/usr/local/lib/android /opt/android ${ANDROID_HOME:-} ${ANDROID_SDK_ROOT:-}"
ANDROID_FOUND=0
for dir in $ANDROID_DIRS; do
  if [ -d "$dir" ] && [ "$dir" != "" ]; then
    echo "📱 Found Android SDK: $dir ($(du -sh "$dir" 2>/dev/null | cut -f1))"
    sudo rm -rf "$dir" || true
    ANDROID_FOUND=1
  fi
done
if [ $ANDROID_FOUND -eq 0 ]; then
  echo "✓ No Android SDK found to remove"
fi

if [ $LIGHT_CLEANUP -eq 0 ]; then
  echo "=== Removing other large directories ==="
  LARGE_DIRS="/usr/share/dotnet /usr/local/share/powershell /usr/local/share/chromium /usr/local/lib/node_modules /opt/ghc /usr/local/.ghcup"
  for dir in $LARGE_DIRS; do
    if [ -d "$dir" ]; then
      SIZE=$(du -sh "$dir" 2>/dev/null | cut -f1)
      echo "🗂️  Removing: $dir ($SIZE)"
      sudo rm -rf "$dir" || true
    fi
  done
else
  echo "=== Skipping large directory cleanup (sufficient space available) ==="
fi

echo "=== Cleaning logs and caches ==="
sudo journalctl --vacuum-time=1d || true
sudo rm -rf /var/log/*.log || true
sudo rm -rf /var/cache/apt/archives/* || true
sudo rm -rf /tmp/* || true
sudo rm -rf /var/tmp/* || true

echo "=== Docker cleanup ==="
docker system prune -af --volumes || true

echo "=== Final cleanup ==="
sudo apt-get autoremove -y --purge
sudo apt-get autoclean

echo "=== Cleanup Summary ==="
df -h

# Calculate space freed
FINAL_AVAILABLE_KB=$(df / | tail -1 | awk '{print $4}')
FINAL_AVAILABLE_GB=$((FINAL_AVAILABLE_KB / 1024 / 1024))

echo ""
echo "📊 DISK SPACE ANALYSIS"
echo "├─ Available space: ${FINAL_AVAILABLE_GB}GB"
echo "├─ Root partition: $(df -h / | tail -1 | awk '{print $4}') free"
echo "└─ /tmp partition: $(df -h /tmp | tail -1 | awk '{print $4}') free"

echo ""
echo "=== Validating minimum space requirement ==="
if [ $FINAL_AVAILABLE_GB -lt 8 ]; then
  echo "❌ ERROR: Insufficient disk space (${FINAL_AVAILABLE_GB}GB). Need at least 8GB for kind cluster."
  echo "Available space breakdown:"
  df -h
  exit 1
fi
echo "✅ Sufficient disk space available (${FINAL_AVAILABLE_GB}GB)"
echo ""
echo "=============================================="
echo "🎯 DISK CLEANUP COMPLETED SUCCESSFULLY"
echo "=============================================="
