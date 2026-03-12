#!/bin/bash
set -e

# Run OpenGrep static analysis.
# Expects these environment variables:
#   SEVERITY - Minimum severity to fail on (CRITICAL, HIGH, etc.)

if ! command -v opengrep &> /dev/null; then
  echo "::error::opengrep is not installed"
  exit 1
fi

echo "::group::OpenGrep static analysis"

ARGS="scan --sarif-output=opengrep-results.sarif"

# Map severity to opengrep --severity flag
case "${SEVERITY}" in
  CRITICAL) ARGS="${ARGS} --severity ERROR" ;;
  HIGH)     ARGS="${ARGS} --severity WARNING" ;;
  *)        ARGS="${ARGS} --severity INFO" ;;
esac

# Use auto-detected rules (opengrep default rulesets)
ARGS="${ARGS} --config auto"

opengrep ${ARGS} . || EXIT_CODE=$?

echo "::endgroup::"

# Upload SARIF for GitHub code scanning integration
if [ -f opengrep-results.sarif ]; then
  echo "SARIF results written to opengrep-results.sarif"
fi

exit "${EXIT_CODE:-0}"
