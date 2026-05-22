#!/bin/bash
set -e

# Parse image inputs into a JSON matrix for GitHub Actions.
# Handles both single-image (IMAGE) and multi-image (IMAGES) inputs.
#
# Expects these environment variables:
#   IMAGE     - Single image input (name or name:dockerfile)
#   IMAGES    - Multi-image YAML list
#   CONTAINER - Whether container builds are enabled
#   PLATFORM  - Target platform for single-image builds (default: linux/amd64)
#   REPO_NAME - Fallback image name (repository name)
#
# Outputs (to GITHUB_OUTPUT):
#   image-matrix - JSON array for strategy.matrix.include

PLATFORM="${PLATFORM:-linux/amd64}"

if [ "${CONTAINER}" != "true" ]; then
  echo "image-matrix=[]" >> "$GITHUB_OUTPUT"
  exit 0
fi

if [ -n "${IMAGES}" ]; then
  # Multi-image: parse YAML list into JSON array
  # Expected format:
  #   - name: api
  #     dockerfile: ./Dockerfile
  #     context: ./              (optional, defaults to ./)
  #     target: build            (optional)
  #     platform: linux/arm64    (optional, defaults to linux/amd64)
  MATRIX="[]"

  current_name=""
  current_dockerfile="./Dockerfile"
  current_context="./"
  current_target=""
  current_platform="linux/amd64"

  flush_entry() {
    if [ -n "$current_name" ]; then
      entry=$(jq -n \
        --arg name "$current_name" \
        --arg dockerfile "$current_dockerfile" \
        --arg context "$current_context" \
        --arg target "$current_target" \
        --arg platform "$current_platform" \
        '{name: $name, dockerfile: $dockerfile, context: $context, target: $target, platform: $platform}')
      MATRIX=$(echo "$MATRIX" | jq --argjson entry "$entry" '. + [$entry]')

      # Reset for next entry
      current_dockerfile="./Dockerfile"
      current_context="./"
      current_target=""
      current_platform="linux/amd64"
    fi
  }

  while IFS= read -r line; do
    # Skip empty lines
    [ -z "$(echo "$line" | tr -d '[:space:]')" ] && continue

    # New list item starts with "- "
    if echo "$line" | grep -qE '^\s*-\s'; then
      flush_entry
      # Extract key: value from the "- key: value" line
      kv=$(echo "$line" | sed 's/^\s*-\s*//')
      key=$(echo "$kv" | cut -d: -f1 | tr -d '[:space:]')
      val=$(echo "$kv" | cut -d: -f2- | sed 's/^\s*//')
      case "$key" in
        name) current_name="$val" ;;
        dockerfile) current_dockerfile="$val" ;;
        context) current_context="$val" ;;
        target) current_target="$val" ;;
        platform) current_platform="$val" ;;
      esac
    else
      # Continuation line "  key: value"
      key=$(echo "$line" | cut -d: -f1 | tr -d '[:space:]')
      val=$(echo "$line" | cut -d: -f2- | sed 's/^\s*//')
      case "$key" in
        name) current_name="$val" ;;
        dockerfile) current_dockerfile="$val" ;;
        context) current_context="$val" ;;
        target) current_target="$val" ;;
        platform) current_platform="$val" ;;
      esac
    fi
  done <<< "${IMAGES}"
  flush_entry

  count=$(echo "$MATRIX" | jq length)
  if [ "$count" -eq 0 ]; then
    echo "::error::images input provided but no valid entries parsed."
    exit 1
  fi

  echo "Parsed ${count} image(s) from images input."
  echo "$MATRIX" | jq .

elif [ -n "${IMAGE}" ]; then
  # Single image: parse name:dockerfile format
  if [[ "${IMAGE}" == *":"* ]]; then
    name="${IMAGE%%:*}"
    dockerfile="${IMAGE#*:}"
  else
    name="${IMAGE}"
    dockerfile="./Dockerfile"
  fi
  MATRIX=$(jq -n --arg name "$name" --arg dockerfile "$dockerfile" --arg platform "$PLATFORM" \
    '[{name: $name, dockerfile: $dockerfile, context: "./", target: "", platform: $platform}]')
  echo "Single image: ${name} (${dockerfile}) [${PLATFORM}]"

else
  # Default: repo name with ./Dockerfile
  MATRIX=$(jq -n --arg name "$REPO_NAME" --arg platform "$PLATFORM" \
    '[{name: $name, dockerfile: "./Dockerfile", context: "./", target: "", platform: $platform}]')
  echo "Default image: ${REPO_NAME} (./Dockerfile) [${PLATFORM}]"
fi

echo "image-matrix=$(echo "$MATRIX" | jq -c .)" >> "$GITHUB_OUTPUT"
