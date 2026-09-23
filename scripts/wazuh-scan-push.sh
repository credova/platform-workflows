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
# standard GITHUB_* variables by pctl itself, so a pull request scan passes
# nothing here.
#
# A scheduled scan is different: it runs in the workflow's own repository but
# scans a checked-out copy of another one, so GITHUB_REPOSITORY and GITHUB_REF
# describe the wrong thing. Setting these overrides what pctl reports, which
# matters because sc-89393 keys previous-scan state on repository and ref. Left
# unset they change nothing.
#   SCAN_REPO              - repository as owner/name
#   SCAN_REF               - git ref, e.g. refs/heads/master
#   SCAN_COMMIT            - commit SHA that was scanned

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

# Passed as flags rather than by overriding the GITHUB_* variables, which the
# runner also uses for checkout and API calls.
if [ -n "${SCAN_REPO:-}" ]; then
  ARGS+=(--repo "$SCAN_REPO")
fi
if [ -n "${SCAN_REF:-}" ]; then
  ARGS+=(--ref "$SCAN_REF")
fi
if [ -n "${SCAN_COMMIT:-}" ]; then
  ARGS+=(--commit "$SCAN_COMMIT")
fi

# pctl exits non-zero when a push fails, which surfaces a dead ingestion path
# instead of letting it rot unnoticed. NO_FAIL=true downgrades that to a
# warning for repos that do not want SIEM availability gating their CI.
pctl wazuh scan push "${ARGS[@]}"

echo "::endgroup::"
