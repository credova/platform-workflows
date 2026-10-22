#!/bin/bash
set -uo pipefail

# Tests for scripts/post-go-comment.sh. A stub `gh` on PATH reports no existing
# comment, saves the JSON the script sends, and exits with a chosen status, so
# each case asserts on the comment body and on the script's exit status.
# Run directly, or through `scripts/tests/run.sh` with the other test files.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UNDER_TEST="${SCRIPT_DIR}/../post-go-comment.sh"

# GitHub rejects a comment body longer than this many characters.
GITHUB_COMMENT_LIMIT=65536

FAILURES=0
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "${WORK_DIR}"' EXIT

printf '{"pull_request":{"number":42}}' > "${WORK_DIR}/event.json"

# Write a stub `gh`. A call without --input is the lookup of existing comments
# and prints nothing. A call with --input saves the request JSON it names
# ("-" for stdin).
#   $1 - exit status for the request that posts the comment
stub_gh() {
  local post_status="$1"
  cat > "${WORK_DIR}/gh" <<EOF
#!/bin/bash
prev=""
for arg in "\$@"; do
  if [ "\${prev}" = "--input" ]; then
    if [ "\${arg}" = "-" ]; then cat; else cat "\${arg}"; fi > "${WORK_DIR}/request.json"
    exit ${post_status}
  fi
  prev="\${arg}"
done
EOF
  chmod +x "${WORK_DIR}/gh"
  rm -f "${WORK_DIR}/request.json"
}

# Run the script under test for the security job with the stub in front of PATH.
#   $1 - job outcome, $2 - path to the job output
run_under_test() {
  PATH="${WORK_DIR}:${PATH}" \
    GH_TOKEN="test-token" GITHUB_REPOSITORY="credova/example" \
    GITHUB_EVENT_PATH="${WORK_DIR}/event.json" \
    JOB="security" JOB_OUTCOME="$1" OUTPUT_FILE="$2" \
    bash "${UNDER_TEST}" > "${WORK_DIR}/output" 2>&1
}

sent_body() {
  jq -r '.body' "${WORK_DIR}/request.json" 2>/dev/null || true
}

fail() {
  echo "  FAIL: $1"
  echo "        output: $(head -c 500 "${WORK_DIR}/output" | tr '\n' ';')"
  FAILURES=$((FAILURES + 1))
}

pass() {
  echo "  ok: $1"
}

echo "post-go-comment.sh"

# Small output goes into the comment unchanged.
printf 'Summary:\n  Issues : 0\n' > "${WORK_DIR}/small.txt"
stub_gh 0
run_under_test success "${WORK_DIR}/small.txt"
status=$?
body="$(sent_body)"
if [ "${status}" -ne 0 ]; then
  fail "small output: expected exit 0, got ${status}"
elif [[ "${body}" != *"Issues : 0"* ]]; then
  fail "small output: expected the output in the comment"
elif [[ "${body}" == *"truncated"* ]]; then
  fail "small output: expected no truncation note"
else
  pass "posts small output in full"
fi

# Output too large for one command-line argument, and for one comment
# (credova/pctl run 39853362129: gosec printed type errors for 38 packages).
for i in $(seq 1 20000); do
  echo "[gosec] 2026/10/22 12:00:00 Golang errors in package: example.com/pkg${i}: undefined: thing"
done > "${WORK_DIR}/large.txt"
stub_gh 0
run_under_test success "${WORK_DIR}/large.txt"
status=$?
body="$(sent_body)"
if [ "${status}" -ne 0 ]; then
  fail "large output: expected exit 0, got ${status}"
elif [ -z "${body}" ]; then
  fail "large output: expected a comment to be sent"
elif [ "${#body}" -ge "${GITHUB_COMMENT_LIMIT}" ]; then
  fail "large output: comment has ${#body} characters, limit is ${GITHUB_COMMENT_LIMIT}"
elif [[ "${body}" != *"truncated"*"job log"* ]]; then
  fail "large output: expected a truncation note that points to the job log"
elif [[ "${body}" != *"pkg1: undefined"* ]]; then
  fail "large output: expected the start of the output to be kept"
else
  pass "truncates large output to fit in one comment"
fi

# A failed comment post must not fail a scan that passed.
stub_gh 1
run_under_test success "${WORK_DIR}/small.txt"
status=$?
if [ "${status}" -ne 0 ]; then
  fail "post fails: expected exit 0, got ${status}"
elif ! grep -q '::warning::' "${WORK_DIR}/output"; then
  fail "post fails: expected a ::warning:: annotation"
else
  pass "warns and exits 0 when the comment cannot be posted"
fi

if [ "${FAILURES}" -gt 0 ]; then
  echo "${FAILURES} test(s) failed."
  exit 1
fi

echo "All tests passed."
