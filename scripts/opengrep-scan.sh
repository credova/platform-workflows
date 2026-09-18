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

# Emit SARIF and JSON in one pass. SARIF drives the PR comment and the
# fail-on-findings check below; the JSON copy is what `pctl wazuh scan push`
# sends to the SIEM, because the receiver parses OpenGrep's native shape
# ({"results": [...]}) and SARIF loses the metadata it decodes (cwe, owasp,
# the raw severity string). --*-output flags are repeatable and independent,
# so this costs one extra file, not a second scan.
ARGS="scan --sarif-output=opengrep-results.sarif --json-output=opengrep-results.json"

# Map severity to opengrep --severity flag
case "${SEVERITY}" in
  CRITICAL) ARGS="${ARGS} --severity ERROR" ;;
  HIGH)     ARGS="${ARGS} --severity WARNING" ;;
  *)        ARGS="${ARGS} --severity INFO" ;;
esac

# Use auto-detected rules (opengrep default rulesets)
ARGS="${ARGS} --config auto"

OPENGREP_EXIT=0
opengrep ${ARGS} . || OPENGREP_EXIT=$?

echo "::endgroup::"

if [ -f opengrep-results.json ]; then
  echo "JSON results written to opengrep-results.json"
fi

if [ -f opengrep-results.sarif ]; then
  echo "SARIF results written to opengrep-results.sarif"

  # Print summary to logs
  echo "::group::OpenGrep results summary"
  jq -r '.runs[0].results[] | "\(.locations[0].physicalLocation.artifactLocation.uri)\t\(.ruleId)"' opengrep-results.sarif 2>/dev/null | sort | uniq -c | sort -rn || true
  echo "::endgroup::"

  # Fail if findings exist (opengrep itself exits 0 even with findings)
  count=$(jq '[.runs[].results[]] | length' opengrep-results.sarif 2>/dev/null || echo 0)
  if [ "$count" -gt 0 ]; then
    echo "OpenGrep found ${count} finding(s)"
    exit 1
  fi
fi

# Propagate opengrep errors (non-finding failures)
exit "${OPENGREP_EXIT}"
