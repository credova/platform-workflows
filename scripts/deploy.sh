#!/bin/bash
set -e

# Execute a pctl deployment action.
#
# pctl's tag-based rollout model tracks revision roles with Cloud Run revision
# tags ('stable' / 'canary') instead of heuristics, and consolidates traffic
# operations under the 'pctl deploy rollout' command group. This script maps the
# action's high-level ACTION input onto that CLI surface.
#
# Expects these environment variables:
#   TARGET      - Target name from CUE config
#   TAG         - Image tag to deploy (required for the deploy action)
#   ACTION      - deploy | promote | abort | rollback | set-weight | status
#   CANARY      - deploy: canary traffic percent — empty/unset = full deploy,
#                 0 = dark canary (no traffic), 1-99 = canary rollout;
#                 set-weight: canary weight to shift to (0-100)
#   CONFIG_PATH - Path to CUE config directory (--deploy-config)
#   REVISION    - Explicit revision to roll back to (rollback action only)
# Token: PCTL_SLACK_BOT_TOKEN (passed through to pctl for notifications)

: "${TARGET:?TARGET is required}"
: "${ACTION:?ACTION is required}"
: "${CONFIG_PATH:?CONFIG_PATH is required}"

CMD_ARGS=("pctl" "deploy")

case "${ACTION}" in
  deploy)
    : "${TAG:?TAG is required for deploy action}"
    CMD_ARGS+=("execute" "${TARGET}" "--tag" "${TAG}" "--deploy-config" "${CONFIG_PATH}" "--no-tui")
    # Match pctl's --canary semantics: omit the flag entirely for a full deploy;
    # pass it through when set, including 0 (dark canary: created, served no
    # traffic, smoke-test via its tagged URL) and 1-99 (canary rollout).
    if [ -n "${CANARY}" ]; then
      CMD_ARGS+=("--canary" "${CANARY}")
    fi
    ;;
  promote)
    # Tag-based rollout: promotes whichever revision holds the 'canary' tag.
    # The old top-level 'promote --revision' was replaced by this subcommand.
    CMD_ARGS+=("rollout" "promote" "${TARGET}" "--deploy-config" "${CONFIG_PATH}" "--no-tui")
    ;;
  abort)
    # Restore 100% traffic to the stable revision and drop the canary tag.
    CMD_ARGS+=("rollout" "abort" "${TARGET}" "--deploy-config" "${CONFIG_PATH}" "--no-tui")
    ;;
  set-weight)
    # Shift the in-progress rollout's canary to CANARY% (0 pauses, 100 bakes).
    : "${CANARY:?CANARY (target weight) is required for set-weight action}"
    CMD_ARGS+=("rollout" "set-weight" "${TARGET}" "${CANARY}" "--deploy-config" "${CONFIG_PATH}" "--no-tui")
    ;;
  status)
    # Read-only: revision roles, traffic split, and tagged URLs.
    CMD_ARGS+=("rollout" "status" "${TARGET}" "--deploy-config" "${CONFIG_PATH}")
    ;;
  rollback)
    # Stays top-level; moves the stable tag to a healthy prior revision.
    CMD_ARGS+=("rollback" "${TARGET}" "--deploy-config" "${CONFIG_PATH}")
    if [ -n "${REVISION}" ]; then
      CMD_ARGS+=("--revision" "${REVISION}")
    fi
    ;;
  *)
    echo "::error::Unknown action: ${ACTION}"
    exit 1
    ;;
esac

echo "Running: ${CMD_ARGS[*]}"
# execute and the rollout subcommands honour --no-tui and print plain,
# parseable output. `rollback` has no --no-tui flag and always launches a
# bubbletea TUI, which needs a controlling terminal. `script` allocates a PTY
# so that command runs without aborting on CI runners.
# -q quiet, -e propagate exit code, -c command, /dev/null discards typescript.
OUTPUT=$(script -q -e -c "${CMD_ARGS[*]}" /dev/null 2>&1) || { echo "${OUTPUT}"; exit 1; }
echo "${OUTPUT}"

# Parse outputs from pctl. execute reports the new revision via its progress
# stream ("revision: <name>"); rollout promote/abort and rollback echo the
# revision they settled traffic on.
REVISION_NAME=$(echo "${OUTPUT}" | grep -oP 'revision:\s*\K\S+' || true)
TRAFFIC_JSON=$(echo "${OUTPUT}" | grep -oP 'traffic:\s*\K.*' || true)

echo "revision=${REVISION_NAME}" >> "$GITHUB_OUTPUT"
echo "traffic=${TRAFFIC_JSON}" >> "$GITHUB_OUTPUT"
