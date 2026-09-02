#!/bin/bash
set -e

# Build a Docker image using buildx.
# Expects these environment variables:
#   IMAGE            - Full image reference (registry/project/name:tag)
#   DOCKERFILE       - Path to Dockerfile
#   CONTEXT          - Docker build context
#   TARGET           - (optional) Docker build stage target
#   PLATFORM         - (optional) Target platform (default: linux/amd64)
#   BUILD_ARGS       - (optional) Newline-separated build arguments
#   NO_CACHE_FILTERS - (optional) Dockerfile stage names to build without the
#                      layer cache, comma- or newline-separated
#   PULL             - (optional) Re-resolve base images ("true" to pull,
#                      default: "false")
#   PUSH             - (optional) Push after build ("true" to push, default: "false")

: "${IMAGE:?IMAGE is required}"
: "${DOCKERFILE:?DOCKERFILE is required}"
: "${CONTEXT:?CONTEXT is required}"

PLATFORM="${PLATFORM:-linux/amd64}"

BUILD_CMD="docker buildx build --platform ${PLATFORM} --provenance=false --sbom=false -t ${IMAGE} -f ${DOCKERFILE}"

if [ -n "${TARGET}" ]; then
  BUILD_CMD="${BUILD_CMD} --target ${TARGET}"
fi

if [ "${PULL}" = "true" ]; then
  BUILD_CMD="${BUILD_CMD} --pull"
fi

# Only a Dockerfile stage name gets through, because BUILD_CMD is eval'd below.
# Fail rather than drop: buildx ignores an unknown stage name without warning,
# so a dropped entry would look like a busted cache and not be one.
if [ -n "${NO_CACHE_FILTERS}" ]; then
  FILTER_COUNT=0
  while IFS= read -r entry; do
    [[ "${entry}" =~ [^[:space:]] ]] || continue
    if [[ "${entry}" =~ ^[[:space:]]*([A-Za-z][A-Za-z0-9._-]*)[[:space:]]*$ ]]; then
      BUILD_CMD="${BUILD_CMD} --no-cache-filter ${BASH_REMATCH[1]}"
      FILTER_COUNT=$((FILTER_COUNT + 1))
    else
      echo "::error::no-cache-filters entry is not a valid Dockerfile stage name: '${entry}'"
      exit 1
    fi
  done <<< "${NO_CACHE_FILTERS//,/$'\n'}"
  if [ "${FILTER_COUNT}" -eq 0 ]; then
    echo "::error::no-cache-filters was set but named no stage: '${NO_CACHE_FILTERS}'"
    exit 1
  fi
fi

if [ -n "${BUILD_ARGS}" ]; then
  while IFS= read -r arg; do
    [ -n "$arg" ] && BUILD_CMD="${BUILD_CMD} --build-arg ${arg}"
  done <<< "${BUILD_ARGS}"
fi

# For single-arch linux/amd64 we --load into the local Docker daemon and let
# docker-push.sh push via plain `docker push`. Buildx's own --push path uses an
# upload protocol that Artifact Registry rejects with HTTP 400 on the blob PUT,
# while `docker push` from a loaded image works against the same registry.
# Multi-arch builds must use --push because --load cannot load multi-arch images.
if [ "${PUSH}" = "true" ] && [ "${PLATFORM}" != "linux/amd64" ]; then
  BUILD_CMD="${BUILD_CMD} --push"
else
  BUILD_CMD="${BUILD_CMD} --load"
fi

BUILD_CMD="${BUILD_CMD} ${CONTEXT}"
echo "Running: ${BUILD_CMD}"
eval "${BUILD_CMD}"
