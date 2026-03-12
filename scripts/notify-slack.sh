#!/bin/bash
set -e

# Send a Slack notification via pctl.
# Required env vars: CHANNEL, STATUS, SERVICE
# Optional env vars: HOST, PROJECT, AUTHOR, APPROVER, REVISION, MESSAGE,
#   THREAD_TS, RUN_URL, STORY_URL, GCP_LOGS_URL, DASHBOARD_URL,
#   ROLLBACK_URL, ROLLBACK_REVISION
# Token: SLACK_BOT_TOKEN (passed through to pctl)

: "${CHANNEL:?CHANNEL is required}"
: "${STATUS:?STATUS is required}"
: "${SERVICE:?SERVICE is required}"

CMD_ARGS=("pctl" "slack" "notify")
CMD_ARGS+=("--channel" "${CHANNEL}")
CMD_ARGS+=("--status" "${STATUS}")
CMD_ARGS+=("--service" "${SERVICE}")

[ -n "${HOST}" ] && CMD_ARGS+=("--host" "${HOST}")
[ -n "${PROJECT}" ] && CMD_ARGS+=("--project" "${PROJECT}")
[ -n "${AUTHOR}" ] && CMD_ARGS+=("--author" "${AUTHOR}")
[ -n "${APPROVER}" ] && CMD_ARGS+=("--approver" "${APPROVER}")
[ -n "${REVISION}" ] && CMD_ARGS+=("--revision" "${REVISION}")
[ -n "${MESSAGE}" ] && CMD_ARGS+=("--message" "${MESSAGE}")
[ -n "${THREAD_TS}" ] && CMD_ARGS+=("--thread-ts" "${THREAD_TS}")
[ -n "${RUN_URL}" ] && CMD_ARGS+=("--run-url" "${RUN_URL}")
[ -n "${STORY_URL}" ] && CMD_ARGS+=("--story-url" "${STORY_URL}")
[ -n "${GCP_LOGS_URL}" ] && CMD_ARGS+=("--gcp-logs-url" "${GCP_LOGS_URL}")
[ -n "${DASHBOARD_URL}" ] && CMD_ARGS+=("--dashboard-url" "${DASHBOARD_URL}")
[ -n "${ROLLBACK_URL}" ] && CMD_ARGS+=("--rollback-url" "${ROLLBACK_URL}")
[ -n "${ROLLBACK_REVISION}" ] && CMD_ARGS+=("--rollback-revision" "${ROLLBACK_REVISION}")

CMD_ARGS+=("--output-json")

echo "Running: ${CMD_ARGS[*]}"
OUTPUT=$("${CMD_ARGS[@]}" 2>&1) || { echo "${OUTPUT}"; exit 1; }

# Parse JSON output for message-ts and channel-id
MESSAGE_TS=$(echo "${OUTPUT}" | jq -r '.message_ts // empty')
CHANNEL_ID=$(echo "${OUTPUT}" | jq -r '.channel_id // empty')

echo "message-ts=${MESSAGE_TS}" >> "$GITHUB_OUTPUT"
echo "channel-id=${CHANNEL_ID}" >> "$GITHUB_OUTPUT"
