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

BUILD_CMD="docker buildx build --platform ${PLATFORM} -t ${IMAGE} -f ${DOCKERFILE}"

if [ -n "${TARGET}" ]; then
  BUILD_CMD="${BUILD_CMD} --target ${TARGET}"
fi

if [ -n "${BUILD_ARGS}" ]; then
  while IFS= read -r arg; do
    [ -n "$arg" ] && BUILD_CMD="${BUILD_CMD} --build-arg ${arg}"
  done <<< "${BUILD_ARGS}"
fi

# When pushing cross-platform images, buildx needs --push (can't docker push after)
if [ "${PUSH}" = "true" ]; then
  BUILD_CMD="${BUILD_CMD} --push"
else
  BUILD_CMD="${BUILD_CMD} --load"
fi

BUILD_CMD="${BUILD_CMD} ${CONTEXT}"
echo "Running: ${BUILD_CMD}"
eval "${BUILD_CMD}"
