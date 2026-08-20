#!/bin/bash
set -e

# Make sure that the image is in the local Docker daemon so syft and grype can
# scan it. This script pulls the image only when it is absent, so a build that
# loaded the image needs no pull.
# Expects these environment variables:
#   IMAGE    - Full image reference (registry/project/name:tag)
#   PLATFORM - (optional) Target platform, e.g. linux/amd64

: "${IMAGE:?IMAGE is required}"

if docker image inspect "${IMAGE}" > /dev/null 2>&1; then
  echo "Image is in the local daemon, no pull needed: ${IMAGE}"
  exit 0
fi

PULL_ARGS=()
# `docker pull --platform` accepts one platform. A multi-arch manifest resolves to
# the runner's own platform, so leave the flag off for a comma-separated value.
if [ -n "${PLATFORM}" ] && [[ "${PLATFORM}" != *,* ]]; then
  PULL_ARGS+=(--platform "${PLATFORM}")
fi

echo "Pulling ${IMAGE} for scan."
docker pull "${PULL_ARGS[@]}" "${IMAGE}"
