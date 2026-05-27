#!/bin/bash
set -e

# Build a Docker image using buildx.
# Expects these environment variables:
#   IMAGE      - Full image reference (registry/project/name:tag)
#   DOCKERFILE - Path to Dockerfile
#   CONTEXT    - Docker build context
#   TARGET     - (optional) Docker build stage target
#   PLATFORM   - (optional) Target platform (default: linux/amd64)
#   BUILD_ARGS - (optional) Newline-separated build arguments
#   PUSH       - (optional) Push after build ("true" to push, default: "false")

: "${IMAGE:?IMAGE is required}"
: "${DOCKERFILE:?DOCKERFILE is required}"
: "${CONTEXT:?CONTEXT is required}"

PLATFORM="${PLATFORM:-linux/amd64}"

BUILD_CMD="docker buildx build --platform ${PLATFORM} --provenance=false --sbom=false -t ${IMAGE} -f ${DOCKERFILE}"

if [ -n "${TARGET}" ]; then
  BUILD_CMD="${BUILD_CMD} --target ${TARGET}"
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
