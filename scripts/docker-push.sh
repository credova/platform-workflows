#!/bin/bash
set -e

# Push a Docker image and apply extra tags.
# Expects these environment variables:
#   IMAGE        - Full image reference (registry/project/name:tag)
#   EXTRA_TAGS   - (optional) Space-separated additional tags
#   REGISTRY     - Artifact Registry hostname
#   PROJECT_ID   - GCP project ID
#   IMAGE_NAME   - Image name (without registry/project prefix)
#   BUILDX_PUSH  - (optional) "true" if buildx already pushed during build

: "${IMAGE:?IMAGE is required}"

if [ "${BUILDX_PUSH}" = "true" ]; then
  echo "Image already pushed by buildx during build."
  # Get digest from registry manifest
  DIGEST=$(docker buildx imagetools inspect "${IMAGE}" --format '{{json .Manifest}}' 2>/dev/null | jq -r '.digest // empty' || true)
  echo "digest=${DIGEST}" >> "$GITHUB_OUTPUT"
else
  echo "Pushing ${IMAGE}"
  docker push "${IMAGE}"
  DIGEST=$(docker inspect --format='{{index .RepoDigests 0}}' "${IMAGE}" | cut -d'@' -f2)
  echo "digest=${DIGEST}" >> "$GITHUB_OUTPUT"
fi

# Apply extra tags
if [ -n "${EXTRA_TAGS}" ]; then
  for extra_tag in ${EXTRA_TAGS}; do
    EXTRA_IMAGE="${REGISTRY}/${PROJECT_ID}/${IMAGE_NAME}:${extra_tag}"
    if [ "${BUILDX_PUSH}" = "true" ]; then
      gcloud artifacts docker tags add "${IMAGE}" "${EXTRA_IMAGE}"
    else
      docker tag "${IMAGE}" "${EXTRA_IMAGE}"
      docker push "${EXTRA_IMAGE}"
    fi
    echo "Pushed extra tag: ${EXTRA_IMAGE}"
  done
fi
