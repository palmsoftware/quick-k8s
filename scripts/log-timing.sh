#!/usr/bin/env bash
# log-timing.sh - Structured timing metrics for quick-k8s action steps
#
# Usage: source this file, then call start_timer/end_timer around operations.
#
#   source "$(dirname "$0")/log-timing.sh"
#   start_timer "Calico CNI"
#   # ... do work ...
#   end_timer "Calico CNI"
#
# At the end, call print_timing_summary to display all recorded timings.

QUICK_K8S_TIMING_FILE="${QUICK_K8S_TIMING_FILE:-/tmp/quick-k8s-timing.log}"

# Initialize the timing system. Call once at the start of the action.
init_timing() {
  : > "$QUICK_K8S_TIMING_FILE"
  date +%s > /tmp/quick-k8s-start-time
}

# Record the start of a timed step.
# Arguments:
#   $1 - Step name (e.g., "Calico CNI")
start_timer() {
  local step_name="$1"
  local start_time
  start_time=$(date +%s)
  echo "STARTED|${step_name}|${start_time}" >> "$QUICK_K8S_TIMING_FILE"
}

# Record the end of a timed step and print the elapsed time.
# Arguments:
#   $1 - Step name (must match the name passed to start_timer)
end_timer() {
  local step_name="$1"
  local end_time
  end_time=$(date +%s)

  # Find the matching start entry
  local start_time
  start_time=$(grep "^STARTED|${step_name}|" "$QUICK_K8S_TIMING_FILE" | tail -1 | cut -d'|' -f3)

  if [ -z "$start_time" ]; then
    echo "[??s] ${step_name} completed (no start time recorded)"
    return
  fi

  local duration=$((end_time - start_time))
  local formatted
  formatted=$(format_duration "$duration")

  # Record the completed timing
  echo "COMPLETED|${step_name}|${start_time}|${end_time}|${duration}" >> "$QUICK_K8S_TIMING_FILE"

  echo "[${formatted}] ${step_name} completed"
}

# Format a duration in seconds to a human-readable string.
# Arguments:
#   $1 - Duration in seconds
format_duration() {
  local total_seconds="$1"

  if [ "$total_seconds" -ge 60 ]; then
    local minutes=$((total_seconds / 60))
    local seconds=$((total_seconds % 60))
    echo "${minutes}m ${seconds}s"
  else
    echo "${total_seconds}s"
  fi
}

# Print a summary table of all recorded timings.
print_timing_summary() {
  if [ ! -f "$QUICK_K8S_TIMING_FILE" ]; then
    return
  fi

  local completed_lines
  completed_lines=$(grep "^COMPLETED|" "$QUICK_K8S_TIMING_FILE" 2>/dev/null || true)

  if [ -z "$completed_lines" ]; then
    return
  fi

  # Calculate total action time
  local total_duration=""
  if [ -f /tmp/quick-k8s-start-time ]; then
    local action_start
    action_start=$(cat /tmp/quick-k8s-start-time)
    local action_end
    action_end=$(date +%s)
    total_duration=$((action_end - action_start))
  fi

  echo ""
  echo "======================================"
  echo "  Quick-K8s Timing Summary"
  echo "======================================"
  echo ""

  # Find the longest step name for alignment
  local max_len=0
  while IFS='|' read -r _ step_name _ _ _; do
    local len=${#step_name}
    if [ "$len" -gt "$max_len" ]; then
      max_len=$len
    fi
  done <<< "$completed_lines"

  # Print each step timing
  while IFS='|' read -r _ step_name _ _ duration; do
    local formatted
    formatted=$(format_duration "$duration")
    printf "  %-${max_len}s  %s\n" "$step_name" "$formatted"
  done <<< "$completed_lines"

  # Print total action time
  if [ -n "$total_duration" ]; then
    local total_formatted
    total_formatted=$(format_duration "$total_duration")
    echo ""
    printf "  %-${max_len}s  %s\n" "Total action time" "$total_formatted"
  fi

  echo ""
  echo "======================================"

  # Write to GitHub Step Summary if available
  if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
    {
      echo ""
      echo "## Timing Summary"
      echo ""
      echo "| Step | Duration |"
      echo "|------|----------|"
      while IFS='|' read -r _ step_name _ _ duration; do
        local formatted
        formatted=$(format_duration "$duration")
        echo "| ${step_name} | ${formatted} |"
      done <<< "$completed_lines"
      if [ -n "$total_duration" ]; then
        local total_formatted
        total_formatted=$(format_duration "$total_duration")
        echo "| **Total action time** | **${total_formatted}** |"
      fi
    } >> "$GITHUB_STEP_SUMMARY"
  fi

  # Clean up timing files
  rm -f "$QUICK_K8S_TIMING_FILE" /tmp/quick-k8s-start-time
}
