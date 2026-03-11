#!/usr/bin/env bash
set -euo pipefail

# semver.sh - Semantic version tag incrementor
# Usage: semver.sh --prefix v --suffix stg --bump patch
#
# Finds the latest matching tag and increments the specified component.
# Outputs to GITHUB_OUTPUT: tag, previous-tag

PREFIX="v"
SUFFIX=""
BUMP="patch"

while [[ $# -gt 0 ]]; do
  case $1 in
    --prefix) PREFIX="$2"; shift 2 ;;
    --suffix) SUFFIX="$2"; shift 2 ;;
    --bump) BUMP="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# Build tag pattern for matching
if [ -n "${SUFFIX}" ]; then
  PATTERN="${PREFIX}[0-9]*.[0-9]*.[0-9]*-${SUFFIX}"
else
  PATTERN="${PREFIX}[0-9]*.[0-9]*.[0-9]*"
fi

# Find latest matching tag
LATEST_TAG=$(git tag -l "${PATTERN}" --sort=-v:refname | head -n 1)

if [ -z "${LATEST_TAG}" ]; then
  # No existing tags - start at 0.1.0
  MAJOR=0
  MINOR=1
  PATCH=0
  PREVIOUS_TAG=""
else
  PREVIOUS_TAG="${LATEST_TAG}"

  # Strip prefix and suffix to get version numbers
  VERSION="${LATEST_TAG#"${PREFIX}"}"
  if [ -n "${SUFFIX}" ]; then
    VERSION="${VERSION%-"${SUFFIX}"}"
  fi

  IFS='.' read -r MAJOR MINOR PATCH <<< "${VERSION}"
fi

# Increment
case "${BUMP}" in
  major)
    MAJOR=$((MAJOR + 1))
    MINOR=0
    PATCH=0
    ;;
  minor)
    MINOR=$((MINOR + 1))
    PATCH=0
    ;;
  patch)
    PATCH=$((PATCH + 1))
    ;;
  *)
    echo "Unknown bump type: ${BUMP}"
    exit 1
    ;;
esac

# Build new tag
if [ -n "${SUFFIX}" ]; then
  NEW_TAG="${PREFIX}${MAJOR}.${MINOR}.${PATCH}-${SUFFIX}"
else
  NEW_TAG="${PREFIX}${MAJOR}.${MINOR}.${PATCH}"
fi

echo "Previous tag: ${PREVIOUS_TAG:-none}"
echo "New tag: ${NEW_TAG}"

# Output for GitHub Actions
if [ -n "${GITHUB_OUTPUT:-}" ]; then
  echo "tag=${NEW_TAG}" >> "${GITHUB_OUTPUT}"
  echo "previous-tag=${PREVIOUS_TAG}" >> "${GITHUB_OUTPUT}"
fi
