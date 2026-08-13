#!/bin/bash
set -euo pipefail

# Install Anchore OSS tools (syft, grype, grant) at pinned versions.
# Versions are pinned here intentionally - bump them deliberately.
#
# Which tools get installed is caller-driven via INSTALL_<TOOL>. The image-scan
# phase (target docker:<ref>) never runs grant, so a transient failure fetching
# it must not fail the job.
#
# get.anchore.io's installer exits 0 even when the release download fails - it
# logs "[error] failed to install <tool>" and returns success - so a bare
# `curl | sh` leaves a missing binary that only surfaces later as a bare
# "command not found" (exit 127). Retry each install and assert the binary
# landed on PATH so a real failure reports an actionable error.

SYFT_VERSION="v1.42.3"
GRYPE_VERSION="v0.110.0"
GRANT_VERSION="v0.6.4"

INSTALL_SYFT="${INSTALL_SYFT:-true}"
INSTALL_GRYPE="${INSTALL_GRYPE:-true}"
INSTALL_GRANT="${INSTALL_GRANT:-true}"

ATTEMPTS=3

install_tool() {
  local tool="$1" version="$2" attempt

  for ((attempt = 1; attempt <= ATTEMPTS; attempt++)); do
    if curl -sSfL "https://get.anchore.io/${tool}" |
      sudo sh -s -- -b /usr/local/bin "$version"; then
      # The installer's exit status is not trustworthy - check for the binary.
      hash -r
      if command -v "$tool" >/dev/null 2>&1; then
        return 0
      fi
    fi

    if ((attempt < ATTEMPTS)); then
      echo "::warning::${tool} ${version} install attempt ${attempt}/${ATTEMPTS} failed, retrying"
      sleep $((attempt * 5))
    fi
  done

  echo "::error::failed to install ${tool} ${version} after ${ATTEMPTS} attempts" >&2
  return 1
}

echo "Installing: syft=${INSTALL_SYFT} grype=${INSTALL_GRYPE} grant=${INSTALL_GRANT}"

if [ "$INSTALL_SYFT" = "true" ]; then
  install_tool syft "$SYFT_VERSION"
fi
if [ "$INSTALL_GRYPE" = "true" ]; then
  install_tool grype "$GRYPE_VERSION"
fi
if [ "$INSTALL_GRANT" = "true" ]; then
  install_tool grant "$GRANT_VERSION"
fi

echo "Installed:"
if [ "$INSTALL_SYFT" = "true" ]; then
  syft version
fi
if [ "$INSTALL_GRYPE" = "true" ]; then
  grype version
fi
if [ "$INSTALL_GRANT" = "true" ]; then
  grant version
fi
