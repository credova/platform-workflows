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

# Look up the existing marker comment's ID. Keep the API call and the jq/head
# filter as separate steps: a failed GET (auth/network/rate-limit) must abort,
# not be silently converted to "no existing comment" (which would post a
# duplicate). An empty ID after a *successful* GET is a genuine no-match.
find_marker_id() {
  local comments
  comments=$(gh api "repos/${GITHUB_REPOSITORY}/issues/${PR_NUMBER}/comments" --paginate) \
    || { echo "::error::Failed to list PR comments" >&2; return 1; }
  printf '%s' "$comments" \
    | jq -r "[.[] | select(.body | startswith(\"${MARKER}\")) | .id] | first // empty"
}

patch_comment() {
  jq -n --arg body "$COMMENT_BODY" '{body: $body}' \
    | gh api "repos/${GITHUB_REPOSITORY}/issues/comments/${1}" \
        --method PATCH --input - > /dev/null
}

# set -e does not abort on a failed command substitution here, so check
# explicitly: a lookup failure must exit non-zero, never fall through to POST.
if ! EXISTING_ID=$(find_marker_id); then
  exit 1
fi

if [ -n "$EXISTING_ID" ]; then
  patch_comment "$EXISTING_ID"
  echo "Updated compliance comment #${EXISTING_ID}"
else
  jq -n --arg body "$COMMENT_BODY" '{body: $body}' \
    | gh api "repos/${GITHUB_REPOSITORY}/issues/${PR_NUMBER}/comments" \
        --method POST --input - > /dev/null
  # Race guard: a concurrent run may also have found no marker and posted. If
  # more than one marker comment now exists, keep the earliest (lowest ID) and
  # delete the rest so the PR converges to a single sticky comment.
  DUP_IDS=$(gh api "repos/${GITHUB_REPOSITORY}/issues/${PR_NUMBER}/comments" --paginate \
    | jq -r "[.[] | select(.body | startswith(\"${MARKER}\")) | .id] | sort | .[1:][]" \
    || true)
  if [ -n "$DUP_IDS" ]; then
    while IFS= read -r dup; do
      [ -z "$dup" ] && continue
      gh api "repos/${GITHUB_REPOSITORY}/issues/comments/${dup}" --method DELETE > /dev/null || true
      echo "Removed duplicate compliance comment #${dup} (race)"
    done <<< "$DUP_IDS"
  fi
  echo "Posted new compliance comment on PR #${PR_NUMBER}"
fi
