#!/bin/bash
set -euo pipefail

# Post or update the compliance PR comment. Upserts a single marker comment:
# renders "Failed" with the captured reason on failure, "Passed" on success
# (flipping a prior failure comment green on a passing re-run).
#
# Expects:
#   GH_TOKEN     - GitHub token
#   JOB_OUTCOME  - "success" | "failure"
#   REASON_FILE  - path to captured failure reason (optional; used on failure)

MARKER="<!-- compliance-report -->"

PR_NUMBER=$(jq -r '.pull_request.number // empty' "$GITHUB_EVENT_PATH")
if [ -z "$PR_NUMBER" ]; then
  echo "Not a pull request - skipping comment"
  exit 0
fi

if [ "$JOB_OUTCOME" = "success" ]; then
  BODY_CONTENT="✅ Passed"
else
  REASON=""
  if [ -n "${REASON_FILE:-}" ] && [ -f "$REASON_FILE" ]; then
    REASON=$(cat "$REASON_FILE")
  fi
  [ -z "$REASON" ] && REASON="Compliance check failed."
  BODY_CONTENT="❌ Failed

\`\`\`
${REASON}
\`\`\`"
fi

COMMENT_BODY="${MARKER}
## Compliance

${BODY_CONTENT}"

# Fetch existing marker comment if present
EXISTING_ID=$(gh api "repos/${GITHUB_REPOSITORY}/issues/${PR_NUMBER}/comments" \
  --jq ".[] | select(.body | startswith(\"${MARKER}\")) | .id" | head -1 || true)

if [ -n "$EXISTING_ID" ]; then
  jq -n --arg body "$COMMENT_BODY" '{body: $body}' \
    | gh api "repos/${GITHUB_REPOSITORY}/issues/comments/${EXISTING_ID}" \
        --method PATCH --input - > /dev/null
  echo "Updated compliance comment #${EXISTING_ID}"
else
  jq -n --arg body "$COMMENT_BODY" '{body: $body}' \
    | gh api "repos/${GITHUB_REPOSITORY}/issues/${PR_NUMBER}/comments" \
        --method POST --input - > /dev/null
  echo "Posted new compliance comment on PR #${PR_NUMBER}"
fi
