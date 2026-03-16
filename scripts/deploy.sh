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
# Token: PCTL_SLACK_BOT_TOKEN (passed through to pctl for notifications)

: "${TARGET:?TARGET is required}"
: "${ACTION:?ACTION is required}"
: "${CONFIG_PATH:?CONFIG_PATH is required}"
if [ "${ACTION}" = "deploy" ]; then
  : "${TAG:?TAG is required for deploy action}"
fi

CMD_ARGS=("pctl" "deploy")

case "${ACTION}" in
  deploy)
    CMD_ARGS+=("execute" "${TARGET}" "--tag" "${TAG}" "--config" "${CONFIG_PATH}")
    if [ "${CANARY}" != "0" ] && [ -n "${CANARY}" ]; then
      CMD_ARGS+=("--canary" "${CANARY}")
    fi
    ;;
  promote)
    CMD_ARGS+=("promote" "${TARGET}" "--revision" "${REVISION}")
    ;;
  rollback)
    CMD_ARGS+=("rollback" "${TARGET}")
    ;;
  abort)
    CMD_ARGS+=("abort" "${TARGET}")
    ;;
  *)
    echo "::error::Unknown action: ${ACTION}"
    exit 1
    ;;
esac

echo "Running: ${CMD_ARGS[*]}"
OUTPUT=$("${CMD_ARGS[@]}" 2>&1) || { echo "${OUTPUT}"; exit 1; }
echo "${OUTPUT}"

# Parse outputs from pctl
REVISION_NAME=$(echo "${OUTPUT}" | grep -oP 'revision:\s*\K\S+' || true)
TRAFFIC_JSON=$(echo "${OUTPUT}" | grep -oP 'traffic:\s*\K.*' || true)

echo "revision=${REVISION_NAME}" >> "$GITHUB_OUTPUT"
echo "traffic=${TRAFFIC_JSON}" >> "$GITHUB_OUTPUT"
