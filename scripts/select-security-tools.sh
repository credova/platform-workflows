#!/bin/bash
set -euo pipefail

# Pick the scanner tools this scan needs and hand them to setup-mise.
# Expects these environment variables:
#   ACTION_PATH - actions/security, holding mise.toml and mise.lock
#   TARGET      - syft scan target ("dir:." or "docker:<ref>")
#   PACKAGES    - "true" to run grype
#   LICENSES    - "true" to run grant
#   CODE        - "true" to run opengrep

: "${ACTION_PATH:?ACTION_PATH is required}"

tools=""
add() { tools="${tools:+${tools} }$1"; }

# syft builds the SBOM that grype and grant both read.
if [ "${PACKAGES:-}" = true ] || [ "${LICENSES:-}" = true ]; then
  add "aqua:anchore/syft"
fi
if [ "${PACKAGES:-}" = true ]; then
  add "aqua:anchore/grype"
fi
# grant and opengrep only ever scan a source tree.
if [ "${LICENSES:-}" = true ] && [ "${TARGET:-}" = "dir:." ]; then
  add "http:grant"
fi
if [ "${CODE:-}" = true ] && [ "${TARGET:-}" = "dir:." ]; then
  add "aqua:opengrep/opengrep"
fi

# setup-mise keys its cache on the caller's mise config, not ours. Without the
# lockfile hash a version bump would never re-save the cache.
if command -v sha256sum >/dev/null 2>&1; then
  lock_hash="$(sha256sum "${ACTION_PATH}/mise.lock" | cut -c1-16)"
else
  lock_hash="$(shasum -a 256 "${ACTION_PATH}/mise.lock" | cut -c1-16)"
fi

{
  echo "install_args=${tools}"
  echo "cache_key_prefix=security-${lock_hash}"
} | tee -a "${GITHUB_OUTPUT}"
