#!/usr/bin/env bash
set -euo pipefail

check_suite() {
  local model="$1" suite="$2" expected_status="$3" expected_summary="$4"
  local output status=0
  output="$(moon run --target native cmd/main -- --suite "$model" "$suite")" || status=$?
  if [[ "$status" -ne "$expected_status" || "$output" != *"$expected_summary"* ]]; then
    printf 'Unexpected result for %s and %s (exit %s):\n%s\n' "$model" "$suite" "$status" "$output" >&2
    exit 1
  fi
}

check_suite examples/buggy.json examples/payment.suite 1 'suite: 1/3 passed'
check_suite examples/fixed.json examples/payment.suite 0 'suite: 3/3 passed'
check_suite examples/lock-buggy.json examples/lock.suite 1 'suite: 0/2 passed'
check_suite examples/lock-fixed.json examples/lock.suite 0 'suite: 2/2 passed'
check_suite examples/agent-buggy.json examples/agent.suite 1 'suite: 0/2 passed'
check_suite examples/agent-fixed.json examples/agent.suite 0 'suite: 2/2 passed'
printf 'All six scenario outcomes matched.\n'
