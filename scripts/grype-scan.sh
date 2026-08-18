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

GRYPE_ARGS=(sbom.spdx.json --output json --file "${RESULTS_FILE}" --fail-on "${SEVERITY_LOWER}" --only-fixed)

# Resolve the effective grype config. We ship org-wide defaults next to this script
# (grype-defaults.yaml, e.g. narrowly-scoped false-positive suppressions that every repo
# should inherit) and still honor a repo-local .grype.yaml. When both exist, merge them so
# a repo can add its own rules without losing the org defaults; grype only accepts a single
# --config, so we deep-merge into a temp file (repo scalars win, ignore lists concatenate).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_CONFIG="${SCRIPT_DIR}/grype-defaults.yaml"
EFFECTIVE_CONFIG=""

if [ -f .grype.yaml ] && [ -f "${DEFAULT_CONFIG}" ]; then
  if command -v yq &>/dev/null; then
    # Must end in .yaml -- grype infers the config format from the extension and
    # rejects the extensionless paths bare mktemp produces. (--suffix is GNU-only,
    # so append instead; the redirect below creates the file.)
    EFFECTIVE_CONFIG="$(mktemp).yaml"
    # `*+` = deep-merge with array concatenation; ireduce folds the two docs into one.
    yq eval-all '. as $item ireduce ({}; . *+ $item)' "${DEFAULT_CONFIG}" .grype.yaml >"${EFFECTIVE_CONFIG}"
    echo "Merged org grype defaults with repo-local .grype.yaml"
  else
    echo "::warning::yq not found; using repo-local .grype.yaml only (org grype defaults not applied)"
    EFFECTIVE_CONFIG=".grype.yaml"
  fi
elif [ -f .grype.yaml ]; then
  EFFECTIVE_CONFIG=".grype.yaml"
  echo "Using repo-local .grype.yaml config"
elif [ -f "${DEFAULT_CONFIG}" ]; then
  EFFECTIVE_CONFIG="${DEFAULT_CONFIG}"
  echo "Using org grype defaults (${DEFAULT_CONFIG})"
fi

if [ -n "${EFFECTIVE_CONFIG}" ]; then
  GRYPE_ARGS+=(--config "${EFFECTIVE_CONFIG}")
fi

echo "::group::Grype vulnerability scan (fail-on: ${SEVERITY})"

# Force fresh DB on every run -- prevents stale CVE state from cached runners.
GRYPE_DB_AUTO_UPDATE=true grype db update || true

GRYPE_EXIT=0
grype "${GRYPE_ARGS[@]}" || GRYPE_EXIT=$?

echo "::endgroup::"
echo "Results written to ${RESULTS_FILE}"

# Print summary to logs so output is visible
if [ -f "${RESULTS_FILE}" ]; then
  echo "::group::Grype results summary"
  jq -r '.matches[] | "\(.vulnerability.severity)\t\(.vulnerability.id)\t\(.artifact.name)@\(.artifact.version)"' "${RESULTS_FILE}" 2>/dev/null | sort | uniq || true
  echo "::endgroup::"
fi

exit "${GRYPE_EXIT}"
