#!/usr/bin/env bash
set -euo pipefail

# docker-utils.sh - Docker helper functions for platform-workflows
# Sourced by composite actions for common docker operations.

# Check if an image exists in the remote registry
# Usage: image_exists "us-docker.pkg.dev/project/repo/image:tag"
image_exists() {
  local image_ref="$1"
  docker manifest inspect "${image_ref}" > /dev/null 2>&1
}

# Retag an image in Artifact Registry without pulling
# Usage: retag_image "us-docker.pkg.dev/project/repo/image" "source-tag" "target-tag"
retag_image() {
  local image_base="$1"
  local source_tag="$2"
  local target_tag="$3"

  gcloud artifacts docker tags add \
    "${image_base}:${source_tag}" \
    "${image_base}:${target_tag}"
}

# Build a docker image with standard labels
# Usage: build_image "image:tag" "Dockerfile" "context" ["target"] ["build-args"]
build_image() {
  local image_ref="$1"
  local dockerfile="$2"
  local context="$3"
  local target="${4:-}"
  local build_args="${5:-}"

  local cmd="docker build -t ${image_ref} -f ${dockerfile}"

  # Standard labels
  cmd="${cmd} --label org.opencontainers.image.source=${GITHUB_SERVER_URL:-}/${GITHUB_REPOSITORY:-}"
  cmd="${cmd} --label org.opencontainers.image.revision=${GITHUB_SHA:-}"
  cmd="${cmd} --label org.opencontainers.image.created=$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  if [ -n "${target}" ]; then
    cmd="${cmd} --target ${target}"
  fi

  if [ -n "${build_args}" ]; then
    while IFS= read -r arg; do
      [ -n "$arg" ] && cmd="${cmd} --build-arg ${arg}"
    done <<< "${build_args}"
  fi

  cmd="${cmd} ${context}"
  eval "${cmd}"
}

# Push image and capture digest
# Usage: push_image "image:tag"
# Sets PUSHED_DIGEST variable
push_image() {
  local image_ref="$1"

  docker push "${image_ref}"
  PUSHED_DIGEST=$(docker inspect --format='{{index .RepoDigests 0}}' "${image_ref}" | cut -d'@' -f2)
  export PUSHED_DIGEST
}
