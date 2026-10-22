#!/bin/bash
set -euo pipefail

# Post or update a unified Go PR comment.
# Each job (lint/security/test) updates its own section; others are preserved.
#
# Expects:
#   GH_TOKEN    - GitHub token
#   JOB         - "lint" | "security" | "test"
#   JOB_OUTCOME - "success" | "failure" | "skipped" | "cancelled"
#   OUTPUT_FILE - path to captured command output (optional)
#   LINT_ENABLED / SECURITY_ENABLED / TEST_ENABLED - "true"|"false" (optional,
#               default "true"). A disabled section renders "_Not enabled._"
#               instead of "_Pending..._" so workflows that only run some jobs
#               (e.g. IaC lint-only) don't show perpetual Pending.
#
# The comment is a report only: if it cannot be posted, the script prints a
# warning and exits 0, so it never fails a job whose check passed.

MAIN_MARKER="<!-- go-report -->"
LINT_START="<!-- go-lint-start -->"
LINT_END="<!-- go-lint-end -->"
SECURITY_START="<!-- go-security-start -->"
SECURITY_END="<!-- go-security-end -->"
TEST_START="<!-- go-test-start -->"
TEST_END="<!-- go-test-end -->"

# GitHub rejects a comment longer than 65,536 characters. The three sections
# share that limit, so each block of command output is cut to this many bytes.
MAX_OUTPUT_BYTES=18000

WORK_DIR=$(mktemp -d)
trap 'rm -rf "$WORK_DIR"' EXIT

PR_NUMBER=$(jq -r '.pull_request.number // empty' "$GITHUB_EVENT_PATH")
if [ -z "$PR_NUMBER" ]; then
  echo "Not a pull request - skipping comment"
  exit 0
fi

extract_section() {
  local start="$1" end="$2" body="$3"
  printf '%s' "$body" | awk \
    "found && index(\$0, \"${end}\"){found=0; next} found{print} index(\$0, \"${start}\"){found=1}" \
    || true
}

# Print stdin, cut at a line boundary to MAX_OUTPUT_BYTES, with a note if cut.
truncate_output() {
  local full="${WORK_DIR}/truncate-input"
  cat > "$full"
  local size
  size=$(wc -c < "$full" | tr -d ' ')
  if [ "$size" -le "$MAX_OUTPUT_BYTES" ]; then
    cat "$full"
    return
  fi
  head -c "$MAX_OUTPUT_BYTES" "$full" | sed '$d'
  echo "... (truncated: ${size} bytes in total, see the job log for the full output)"
}

build_job_section() {
  local outcome="$1"
  local output_file="${OUTPUT_FILE:-}"

  if [ "$outcome" = "skipped" ] || [ "$outcome" = "cancelled" ]; then
    echo "_Skipped._"
    return
  fi

  if [ "$outcome" = "success" ]; then
    echo "✅ Passed"
  else
    echo "❌ Failed"
  fi

  if [ -n "$output_file" ] && [ -f "$output_file" ]; then
    local lines
    lines=$(wc -l < "$output_file" | tr -d ' ')
    if [ "$lines" -gt 0 ]; then
      echo ""
      echo "<details>"
      echo "<summary>Output (${lines} lines)</summary>"
      echo ""
      echo '```'
      truncate_output < "$output_file"
      echo '```'
      echo ""
      echo "</details>"
    fi
  fi
}

build_test_section() {
  local outcome="$1"
  local output_file="${OUTPUT_FILE:-}"

  if [ "$outcome" = "skipped" ] || [ "$outcome" = "cancelled" ]; then
    echo "_Skipped._"
    return
  fi

  local status_icon
  [ "$outcome" = "success" ] && status_icon="✅" || status_icon="❌"

  # Extract total coverage from profile (most accurate) or fall back to output
  local coverage=""
  if [ -f "coverage.out" ]; then
    coverage=$(go tool cover -func=coverage.out 2>/dev/null | awk '/^total:/{print $NF}' || true)
  fi
  if [ -z "$coverage" ] && [ -n "$output_file" ] && [ -f "$output_file" ]; then
    coverage=$(grep -oE '[0-9]+\.[0-9]+% of statements' "$output_file" | tail -1 || true)
  fi

  if [ -n "$coverage" ]; then
    echo "${status_icon} $([ "$outcome" = "success" ] && echo "Passed" || echo "Failed") - coverage: **${coverage}**"
  else
    echo "${status_icon} $([ "$outcome" = "success" ] && echo "Passed" || echo "Failed")"
  fi

  # Show failed tests in a collapsible block
  if [ -n "$output_file" ] && [ -f "$output_file" ]; then
    local failures
    failures=$(grep -c "^--- FAIL" "$output_file" 2>/dev/null || echo 0)
    if [ "$failures" -gt 0 ]; then
      echo ""
      echo "<details>"
      echo "<summary>Failed tests (${failures})</summary>"
      echo ""
      echo '```'
      { grep -A 30 "^--- FAIL" "$output_file" || true; } | truncate_output
      echo '```'
      echo ""
      echo "</details>"
    fi
  fi
}

warn() {
  echo "::warning::Go PR comment: $1"
}

# Fetch existing comment if present
EXISTING_ID=$(gh api "repos/${GITHUB_REPOSITORY}/issues/${PR_NUMBER}/comments" \
  --jq ".[] | select(.body | startswith(\"${MAIN_MARKER}\")) | .id" | head -1 || true)

EXISTING_BODY=""
if [ -n "$EXISTING_ID" ]; then
  if ! EXISTING_BODY=$(gh api "repos/${GITHUB_REPOSITORY}/issues/comments/${EXISTING_ID}" --jq '.body'); then
    warn "could not read comment #${EXISTING_ID}; skipping the update"
    exit 0
  fi
fi

# Preserve sections for other jobs; update current job's section
LINT_CONTENT=$(extract_section "$LINT_START" "$LINT_END" "$EXISTING_BODY")
SECURITY_CONTENT=$(extract_section "$SECURITY_START" "$SECURITY_END" "$EXISTING_BODY")
TEST_CONTENT=$(extract_section "$TEST_START" "$TEST_END" "$EXISTING_BODY")

# Fill empty sections: "_Not enabled._" if the job is disabled, else
# "_Pending..._" (job enabled but hasn't reported yet).
fill_default() {
  local enabled="$1"
  [ "$enabled" = "false" ] && echo "_Not enabled._" || echo "_Pending..._"
}
[ -z "$LINT_CONTENT" ]     && LINT_CONTENT=$(fill_default "${LINT_ENABLED:-true}")
[ -z "$SECURITY_CONTENT" ] && SECURITY_CONTENT=$(fill_default "${SECURITY_ENABLED:-true}")
[ -z "$TEST_CONTENT" ]     && TEST_CONTENT=$(fill_default "${TEST_ENABLED:-true}")

case "$JOB" in
  lint)     LINT_CONTENT=$(build_job_section "$JOB_OUTCOME") ;;
  security) SECURITY_CONTENT=$(build_job_section "$JOB_OUTCOME") ;;
  test)     TEST_CONTENT=$(build_test_section "$JOB_OUTCOME") ;;
esac

COMMENT_BODY="${MAIN_MARKER}
## Go

### Lint
${LINT_START}
${LINT_CONTENT}
${LINT_END}

### Security
${SECURITY_START}
${SECURITY_CONTENT}
${SECURITY_END}

### Tests
${TEST_START}
${TEST_CONTENT}
${TEST_END}"

# Pass the body to jq through a file: as a command-line argument, a large body
# fails with "Argument list too long".
printf '%s' "$COMMENT_BODY" > "${WORK_DIR}/body.md"
if ! jq -n --rawfile body "${WORK_DIR}/body.md" '{body: $body}' > "${WORK_DIR}/request.json"; then
  warn "could not build the request body"
  exit 0
fi

if [ -n "$EXISTING_ID" ]; then
  if gh api "repos/${GITHUB_REPOSITORY}/issues/comments/${EXISTING_ID}" \
      --method PATCH --input "${WORK_DIR}/request.json" > /dev/null; then
    echo "Updated Go comment #${EXISTING_ID}"
  else
    warn "could not update comment #${EXISTING_ID}"
  fi
else
  if gh api "repos/${GITHUB_REPOSITORY}/issues/${PR_NUMBER}/comments" \
      --method POST --input "${WORK_DIR}/request.json" > /dev/null; then
    echo "Posted new Go comment on PR #${PR_NUMBER}"
  else
    warn "could not post a comment on PR #${PR_NUMBER}"
  fi
fi
