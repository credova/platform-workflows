#!/bin/bash
set -euo pipefail

# Run grype vulnerability scan against sbom.spdx.json.
# Expects:
#   SEVERITY     - Minimum severity to fail on (CRITICAL, HIGH, MEDIUM, LOW)
#   RESULTS_FILE - Output file for JSON results

: "${SEVERITY:?SEVERITY is required}"
: "${RESULTS_FILE:?RESULTS_FILE is required}"

if ! command -v grype &>/dev/null; then
  echo "::error::grype is not installed"
  exit 1
fi

SEVERITY_LOWER=$(echo "${SEVERITY}" | tr '[:upper:]' '[:lower:]')

echo "::group::Grype vulnerability scan (fail-on: ${SEVERITY})"

grype sbom.spdx.json \
  --output json \
  --file "${RESULTS_FILE}" \
  --fail-on "${SEVERITY_LOWER}"

echo "::endgroup::"
echo "Results written to ${RESULTS_FILE}"
