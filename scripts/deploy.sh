#!/bin/bash
set -e

# Execute a pctl deployment action.
# Expects these environment variables:
#   TARGET      - Target name from CUE config
#   TAG         - Image tag to deploy
#   ACTION      - Action to perform: deploy, promote, rollback, abort
#   CANARY      - Canary traffic percentage (0 = full deploy)
#   CONFIG_PATH - Path to CUE config directory
#   REVISION    - Revision name (required for promote/rollback)

: "${TARGET:?TARGET is required}"
: "${ACTION:?ACTION is required}"
: "${CONFIG_PATH:?CONFIG_PATH is required}"
if [ "${ACTION}" = "deploy" ]; then
  : "${TAG:?TAG is required for deploy action}"
fi

case "${ACTION}" in
  deploy)
    CMD="pctl deploy execute ${TARGET} --tag ${TAG} --config ${CONFIG_PATH}"
    if [ "${CANARY}" != "0" ]; then
      CMD="${CMD} --canary ${CANARY}"
    fi
    ;;
  promote)
    CMD="pctl deploy promote ${TARGET} --revision ${REVISION}"
    ;;
  rollback)
    CMD="pctl deploy rollback ${TARGET}"
    ;;
  abort)
    CMD="pctl deploy abort ${TARGET}"
    ;;
  *)
    echo "::error::Unknown action: ${ACTION}"
    exit 1
    ;;
esac

echo "Running: ${CMD}"
OUTPUT=$(eval "${CMD}" 2>&1) || { echo "${OUTPUT}"; exit 1; }
echo "${OUTPUT}"

# Parse outputs from pctl
REVISION_NAME=$(echo "${OUTPUT}" | grep -oP 'revision:\s*\K\S+' || true)
TRAFFIC_JSON=$(echo "${OUTPUT}" | grep -oP 'traffic:\s*\K.*' || true)

echo "revision=${REVISION_NAME}" >> "$GITHUB_OUTPUT"
echo "traffic=${TRAFFIC_JSON}" >> "$GITHUB_OUTPUT"
