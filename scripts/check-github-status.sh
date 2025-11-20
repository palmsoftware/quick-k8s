#!/usr/bin/env bash
set -euo pipefail

# Script to check GitHub status and warn users about potential issues
# Uses the GitHub Status API: https://www.githubstatus.com/

# Function to check which components are affected
check_affected_components() {
  if [ -n "$COMPONENTS_JSON" ] && [ "$COMPONENTS_JSON" != "{}" ]; then
    echo ""
    echo "   Affected services:"
    
    # Check for Actions-related issues
    if echo "$COMPONENTS_JSON" | grep -q '"name":"Actions".*"status":"[^o]'; then
      echo "   - GitHub Actions (may impact workflow execution)"
    fi
    
    # Check for API issues
    if echo "$COMPONENTS_JSON" | grep -q '"name":"API Requests".*"status":"[^o]'; then
      echo "   - API Requests (may impact binary downloads)"
    fi
    
    # Check for Git Operations
    if echo "$COMPONENTS_JSON" | grep -q '"name":"Git Operations".*"status":"[^o]'; then
      echo "   - Git Operations"
    fi
    
    # Check for Packages
    if echo "$COMPONENTS_JSON" | grep -q '"name":"Packages".*"status":"[^o]'; then
      echo "   - GitHub Packages"
    fi
  fi
}

echo "🔍 Checking GitHub service status..."

# Fetch overall status
STATUS_JSON=$(curl -s --max-time 5 https://www.githubstatus.com/api/v2/status.json || echo "{}")

if [ -z "$STATUS_JSON" ] || [ "$STATUS_JSON" = "{}" ]; then
  echo "⚠️  Unable to check GitHub status (API timeout or unavailable)"
  echo "   Proceeding with action, but be aware there may be service issues"
  exit 0
fi

# Parse overall status
OVERALL_STATUS=$(echo "$STATUS_JSON" | grep -o '"indicator":"[^"]*"' | cut -d'"' -f4 || echo "unknown")
STATUS_DESC=$(echo "$STATUS_JSON" | grep -o '"description":"[^"]*"' | cut -d'"' -f4 || echo "Unknown")

# Check if there are any incidents
COMPONENTS_JSON=$(curl -s --max-time 5 https://www.githubstatus.com/api/v2/components.json || echo "{}")

case "$OVERALL_STATUS" in
  "none")
    echo "✅ GitHub Status: All Systems Operational"
    ;;
  "minor")
    echo "⚠️  GitHub Status: Minor Service Outage Detected"
    echo "   Description: $STATUS_DESC"
    echo "   Some operations may be slower than usual"
    check_affected_components
    ;;
  "major")
    echo "🔴 GitHub Status: Major Service Outage Detected"
    echo "   Description: $STATUS_DESC"
    echo "   This may affect the ability to download binaries and access GitHub services"
    check_affected_components
    ;;
  "critical")
    echo "🔴 GitHub Status: Critical Service Outage"
    echo "   Description: $STATUS_DESC"
    echo "   GitHub services are experiencing significant issues"
    check_affected_components
    ;;
  *)
    echo "ℹ️  GitHub Status: $STATUS_DESC"
    ;;
esac

echo ""

# Exit successfully - this is just informational
exit 0

