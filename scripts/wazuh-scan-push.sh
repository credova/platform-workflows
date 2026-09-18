#!/bin/bash
set -euo pipefail

# Push scanner results to the Wazuh SIEM via the pctl server.
#
# pctl accepts the payload, forwards it to a receiver on the Wazuh agent, and
# the agent's logcollector ships each finding to the Wazuh Cloud manager where
# detection rules run. See `pctl wazuh scan push --help`.
#
# Expects these environment variables:
#   PIPELINE_WEBHOOK_TOKEN - bearer token for the ingestion endpoint
#   PCTL_WAZUH_SCAN_URL    - ingestion endpoint
#   NO_FAIL                - "true" to warn instead of failing the job
#
# Run context (repository, ref, commit, run id, run url) is read from the
# standard GITHUB_* variables by pctl itself, so nothing is passed here.

: "${PCTL_WAZUH_SCAN_URL:?PCTL_WAZUH_SCAN_URL is required}"
: "${PIPELINE_WEBHOOK_TOKEN:?PIPELINE_WEBHOOK_TOKEN is required}"

echo "::group::Push scan results to Wazuh"

ARGS=()
for f in grype-source-results.json grype-image-results.json opengrep-results.json; do
  if [ -s "$f" ]; then
    ARGS+=(--results "$f")
  fi
done

if [ ${#ARGS[@]} -eq 0 ]; then
  # Not an error: a workflow may run only the licence scan, or a scanner may
  # have failed before writing anything. Nothing to push is a no-op.
  echo "No scanner result files found; nothing to push."
  echo "::endgroup::"
  exit 0
fi

if [ "${NO_FAIL:-false}" = "true" ]; then
  ARGS+=(--no-fail)
fi

# pctl exits non-zero when a push fails, which surfaces a dead ingestion path
# instead of letting it rot unnoticed. NO_FAIL=true downgrades that to a
# warning for repos that do not want SIEM availability gating their CI.
pctl wazuh scan push "${ARGS[@]}"

echo "::endgroup::"
