#!/bin/bash
set -e

# Install pctl from GitHub releases.
# Expects these environment variables:
#   PCTL_VERSION - Version to install (or "latest")
#   GH_TOKEN     - GitHub token with read access to credova/pctl releases

: "${GH_TOKEN:?GH_TOKEN is required}"

echo "::group::Install pctl"

# Resolve version
if [ "${PCTL_VERSION}" = "latest" ]; then
  PCTL_VERSION=$(gh release view --repo credova/pctl --json tagName -q '.tagName' | sed 's/^v//')
fi

if [ -z "${PCTL_VERSION}" ]; then
  echo "::error::Failed to resolve pctl version"
  exit 1
fi

# Detect OS and architecture
OS=$(uname -s)   # Linux or Darwin
ARCH=$(uname -m) # x86_64 or aarch64/arm64
case "${ARCH}" in
  aarch64|arm64) ARCH="arm64" ;;
  x86_64)        ARCH="x86_64" ;;
  *) echo "::error::Unsupported architecture: ${ARCH}"; exit 1 ;;
esac

ARCHIVE="pctl_${OS}_${ARCH}.tar.gz"

echo "Downloading pctl v${PCTL_VERSION} (${ARCHIVE}) from credova/pctl"
# gh handles auth for private-repo release assets via GH_TOKEN; plain curl
# 404s because the redirect target requires an Authorization header.
gh release download "v${PCTL_VERSION}" \
  --repo credova/pctl \
  --pattern "${ARCHIVE}" \
  --pattern "checksums.txt" \
  --dir /tmp \
  --clobber

# Verify checksum
EXPECTED=$(grep "${ARCHIVE}" /tmp/checksums.txt | awk '{print $1}')
ACTUAL=$(sha256sum "/tmp/${ARCHIVE}" | awk '{print $1}')
if [ "${EXPECTED}" != "${ACTUAL}" ]; then
  echo "::error::Checksum mismatch for ${ARCHIVE}: expected ${EXPECTED}, got ${ACTUAL}"
  exit 1
fi
echo "Checksum verified."

# Extract and install
tar -xzf "/tmp/${ARCHIVE}" -C /tmp
install -m 755 /tmp/pctl /usr/local/bin/pctl
rm -f "/tmp/${ARCHIVE}" /tmp/checksums.txt /tmp/pctl

echo "Installed: $(pctl version)"
echo "::endgroup::"
