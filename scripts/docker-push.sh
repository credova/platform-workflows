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

# Digest a tag currently points at, empty when the tag does not exist.
tag_digest() {
  gcloud artifacts docker images describe "$1" --format='value(image_summary.digest)' 2>/dev/null || true
}

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
      # buildx already pushed, so the image is only in the registry and the extra
      # tag has to be applied there. `tags add` over a tag that already exists is
      # a move, and a move deletes the old tag first: it needs
      # artifactregistry.tags.delete, which CI does not have
      # (roles/artifactregistry.writer stops at tags.create/update). A moving tag
      # such as pr-<number> hits that on every run after the first, so overwrite
      # it with imagetools instead, which is an upload rather than a delete.
      SOURCE_DIGEST="${DIGEST}"
      if [ -z "${SOURCE_DIGEST}" ]; then
        SOURCE_DIGEST="$(tag_digest "${IMAGE}")"
      fi
      EXTRA_DIGEST="$(tag_digest "${EXTRA_IMAGE}")"

      if [ -n "${SOURCE_DIGEST}" ] && [ "${EXTRA_DIGEST}" = "${SOURCE_DIGEST}" ]; then
        echo "Extra tag already current: ${EXTRA_IMAGE}"
        continue
      elif [ -n "${EXTRA_DIGEST}" ]; then
        if [ -z "${SOURCE_DIGEST}" ]; then
          echo "Could not resolve a digest for ${IMAGE}; refusing to overwrite ${EXTRA_IMAGE}." >&2
          exit 1
        fi
        # Copy the resolved digest, not the tag, so a tag that moves underneath
        # this loop cannot swap the artifact. --prefer-index=false (buildx 0.15+)
        # keeps a single-platform manifest as one instead of wrapping it in a new
        # index, which would land on a digest the check above never matches again.
        docker buildx imagetools create --prefer-index=false --tag "${EXTRA_IMAGE}" \
          "${REGISTRY}/${PROJECT_ID}/${IMAGE_NAME}@${SOURCE_DIGEST}"
      else
        gcloud artifacts docker tags add "${IMAGE}" "${EXTRA_IMAGE}"
      fi
    else
      docker tag "${IMAGE}" "${EXTRA_IMAGE}"
      docker push "${EXTRA_IMAGE}"
    fi
    echo "Pushed extra tag: ${EXTRA_IMAGE}"
  done
fi
