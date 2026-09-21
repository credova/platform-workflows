#!/bin/bash
set -euo pipefail

# Upload goreleaser's .deb output to an Artifact Registry APT repository.
#
# goreleaser already builds these via its nfpms block and attaches them to the
# GitHub release. Publishing to APT as well is what lets a VM install the
# package with apt: pulling a release asset from a private GitHub repo would
# mean a long-lived GitHub credential on the host, which an Artifact Registry
# repository avoids by using the instance's own service account.
#
# Expects GCP credentials to be already configured (the caller authenticates
# via Workload Identity before this runs).
#
# Environment:
#   APT_REPOSITORY - repository name, e.g. psq-utils
#   APT_PROJECT    - project holding it
#   APT_LOCATION   - Artifact Registry location, e.g. us
#   DIST_PATH      - directory holding the built packages (default: dist)

: "${APT_REPOSITORY:?APT_REPOSITORY is required}"
: "${APT_PROJECT:?APT_PROJECT is required}"
: "${APT_LOCATION:?APT_LOCATION is required}"
DIST_PATH="${DIST_PATH:-dist}"

echo "::group::Publish .deb to ${APT_REPOSITORY}"

shopt -s nullglob
packages=("${DIST_PATH}"/*.deb)
shopt -u nullglob

if [ ${#packages[@]} -eq 0 ]; then
  # A release with no .deb means the nfpms block was removed or the build
  # changed shape. Failing is right: silently publishing nothing would leave
  # hosts pinned to an old version with no indication why.
  echo "::error::No .deb packages found in ${DIST_PATH}"
  exit 1
fi

echo "Found ${#packages[@]} package(s):"
printf '  %s\n' "${packages[@]}"

for pkg in "${packages[@]}"; do
  echo "Uploading $(basename "${pkg}")..."
  # --source takes one file per call; there is no batch upload for apt.
  gcloud artifacts apt upload "${APT_REPOSITORY}" \
    --project="${APT_PROJECT}" \
    --location="${APT_LOCATION}" \
    --source="${pkg}"
done

echo "Published ${#packages[@]} package(s) to ${APT_LOCATION}/${APT_PROJECT}/${APT_REPOSITORY}"
echo "::endgroup::"
