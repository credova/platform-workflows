#!/bin/bash
set -euo pipefail

# Install Anchore OSS tools (syft, grype, grant) at pinned versions.
# Versions are pinned here intentionally — bump them deliberately.

SYFT_VERSION="v1.19.0"
GRYPE_VERSION="v0.87.0"
GRANT_VERSION="v0.4.0"

curl -sSfL https://get.anchore.io/syft  | sudo sh -s -- -b /usr/local/bin "$SYFT_VERSION"
curl -sSfL https://get.anchore.io/grype | sudo sh -s -- -b /usr/local/bin "$GRYPE_VERSION"
curl -sSfL https://get.anchore.io/grant | sudo sh -s -- -b /usr/local/bin "$GRANT_VERSION"

echo "Installed:"
syft  version
grype version
grant version
