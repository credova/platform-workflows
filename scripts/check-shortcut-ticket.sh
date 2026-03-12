#!/bin/bash
set -e

# Check for Shortcut ticket references in PR metadata.
# Expects these environment variables:
#   PR_TITLE        - Pull request title
#   PR_BODY         - Pull request body/description
#   PR_BRANCH       - Branch name (head ref)
#   HEAD_COMMIT_MSG - Head commit message
#   PR_NUMBER       - Pull request number (optional, enables comment check)
#   REPO            - Repository (owner/name)
#   GH_TOKEN        - GitHub token (for API calls)

# Shortcut tag: sc-12345 or SC-12345
TICKET_PATTERN='(sc|SC)-[0-9]+'
# Shortcut link: https://app.shortcut.com/<org>/story/<id>
LINK_PATTERN='https://app\.shortcut\.com/[a-zA-Z0-9_-]+/story/[0-9]+'

# Skip automated PRs
if [[ "${PR_BRANCH}" =~ ^dependabot/ ]] || [[ "${PR_BRANCH}" =~ ^renovate/ ]]; then
  echo "Automated PR (${PR_BRANCH}), skipping ticket check."
  exit 0
fi

check_text() {
  local label="$1"
  local text="$2"

  if [ -z "$text" ]; then
    return 1
  fi

  if echo "$text" | grep -qEi "$TICKET_PATTERN"; then
    echo "Found Shortcut tag in ${label}."
    return 0
  fi

  if echo "$text" | grep -qE "$LINK_PATTERN"; then
    echo "Found Shortcut link in ${label}."
    return 0
  fi

  return 1
}

# Check all available sources
check_text "PR title" "$PR_TITLE" && exit 0
check_text "PR body" "$PR_BODY" && exit 0
check_text "branch name" "$PR_BRANCH" && exit 0
check_text "commit message" "$HEAD_COMMIT_MSG" && exit 0

# Check PR comments via GitHub API
if [ -n "$PR_NUMBER" ]; then
  COMMENTS=$(gh api "repos/${REPO}/issues/${PR_NUMBER}/comments" --jq '.[].body' 2>/dev/null || true)
  if [ -n "$COMMENTS" ]; then
    check_text "PR comments" "$COMMENTS" && exit 0
  fi
fi

echo "::error::No Shortcut ticket reference found."
echo ""
echo "Add a Shortcut reference to your PR title, body, branch name, commit message, or PR comment."
echo "Accepted formats:"
echo "  - Tag:  sc-12345"
echo "  - Link: https://app.shortcut.com/<org>/story/12345"
exit 1
