#!/bin/bash
set -uo pipefail

# Tests for scripts/cloudflare-purge.sh. A stub `curl` on PATH records the arguments
# it receives and replays a canned response, so each case asserts on the request the
# script builds and on how it reads the reply.
# Run directly, or through `scripts/tests/run.sh` with the other test files.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UNDER_TEST="${SCRIPT_DIR}/../cloudflare-purge.sh"
ZONE_ID="zone123"
API_TOKEN="cf-token"

FAILURES=0
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "${WORK_DIR}"' EXIT

# Write a stub `curl` that records its arguments and prints a canned body plus the
# trailing status line the script expects from --write-out.
#   $1 - response body
#   $2 - HTTP status code
stub_curl() {
  local body="$1" code="$2"
  cat > "${WORK_DIR}/curl" <<EOF
#!/bin/bash
printf '%s\n' "\$@" > "${WORK_DIR}/args"
# The --data value is the request body the script assembled.
prev=""
for arg in "\$@"; do
  [ "\${prev}" = "--data" ] && printf '%s' "\${arg}" > "${WORK_DIR}/body"
  prev="\${arg}"
done
printf '%s\n%s' '${body}' '${code}'
EOF
  chmod +x "${WORK_DIR}/curl"
  : > "${WORK_DIR}/args"
  : > "${WORK_DIR}/body"
}

# Run the script under test with the stub in front of PATH.
#   $1 - MODE, $2 - VALUE
run_under_test() {
  PATH="${WORK_DIR}:${PATH}" \
    MODE="$1" VALUE="$2" \
    CLOUDFLARE_ZONE_ID="${ZONE_ID}" CLOUDFLARE_API_TOKEN="${API_TOKEN}" \
    GITHUB_OUTPUT="${WORK_DIR}/github_output" \
    bash "${UNDER_TEST}" > "${WORK_DIR}/output" 2>&1
}

sent_body() {
  cat "${WORK_DIR}/body" 2>/dev/null || true
}

fail() {
  echo "  FAIL: $1"
  echo "        body: $(sent_body)"
  echo "        output: $(tr '\n' ';' < "${WORK_DIR}/output")"
  FAILURES=$((FAILURES + 1))
}

pass() {
  echo "  ok: $1"
}

OK_RESPONSE='{"success":true,"errors":[],"result":{"id":"purge-1"}}'

echo "cloudflare-purge.sh"

# The common case: one file URL becomes a one-element files array.
stub_curl "${OK_RESPONSE}" 200
run_under_test files "https://example.com/app.js"
status=$?
if [ "${status}" -ne 0 ]; then
  fail "single file: expected exit 0, got ${status}"
elif [ "$(sent_body | jq -c .)" != '{"files":["https://example.com/app.js"]}' ]; then
  fail "single file: unexpected body '$(sent_body)'"
else
  pass "sends a single file URL as a one-element array"
fi

# Multi-line input is the documented way to purge several values at once.
# Blank lines and stray indentation come free with YAML block scalars.
stub_curl "${OK_RESPONSE}" 200
run_under_test prefixes "$(printf 'example.com/a/\n\n  example.com/b/  \n')"
status=$?
if [ "${status}" -ne 0 ]; then
  fail "multi-line: expected exit 0, got ${status}"
elif [ "$(sent_body | jq -c .)" != '{"prefixes":["example.com/a/","example.com/b/"]}' ]; then
  fail "multi-line: unexpected body '$(sent_body)'"
else
  pass "trims each line and drops blank ones"
fi

# `files` also accepts the object form, which must survive as an object, not a string.
stub_curl "${OK_RESPONSE}" 200
run_under_test files '{"url":"https://example.com/app.js","headers":{"Accept-Encoding":"br"}}'
status=$?
if [ "${status}" -ne 0 ]; then
  fail "json line: expected exit 0, got ${status}"
elif [ "$(sent_body | jq -c '.files[0] | type')" != '"object"' ]; then
  fail "json line: expected an object, got '$(sent_body)'"
else
  pass "keeps a JSON line as an object"
fi

# The purge id is what a caller threads into later steps.
stub_curl "${OK_RESPONSE}" 200
run_under_test files "https://example.com/app.js"
if ! grep -q '^purge-id=purge-1$' "${WORK_DIR}/github_output" 2>/dev/null; then
  fail "output: expected purge-id in GITHUB_OUTPUT, got '$(cat "${WORK_DIR}/github_output" 2>/dev/null)'"
else
  pass "writes purge-id to GITHUB_OUTPUT"
fi

# Cloudflare answers 200 with success=false for some rejections. Trusting the status
# code alone would report a purge that never happened.
stub_curl '{"success":false,"errors":[{"code":1012,"message":"Request must contain one of prefixes"}]}' 200
run_under_test files "https://example.com/app.js"
status=$?
if [ "${status}" -eq 0 ]; then
  fail "success=false: expected a non-zero exit"
elif ! grep -q '1012' "${WORK_DIR}/output"; then
  fail "success=false: expected the API error in the output"
else
  pass "fails when the API returns success=false on a 200"
fi

# A bad token is the likeliest misconfiguration, and it must red the run.
stub_curl '{"success":false,"errors":[{"code":10000,"message":"Authentication error"}]}' 403
run_under_test files "https://example.com/app.js"
status=$?
if [ "${status}" -eq 0 ]; then
  fail "http 403: expected a non-zero exit"
else
  pass "fails on a non-200 status"
fi

# An unsupported mode must not reach the API as a malformed body.
stub_curl "${OK_RESPONSE}" 200
run_under_test everything "https://example.com/app.js"
status=$?
if [ "${status}" -eq 0 ]; then
  fail "bad mode: expected a non-zero exit"
elif [ -s "${WORK_DIR}/args" ]; then
  fail "bad mode: expected no request, got '$(tr '\n' ' ' < "${WORK_DIR}/args")'"
else
  pass "rejects a mode outside prefixes, files, tags"
fi

# All-blank input would otherwise send an empty array and report success.
stub_curl "${OK_RESPONSE}" 200
run_under_test files "$(printf '\n   \n')"
status=$?
if [ "${status}" -eq 0 ]; then
  fail "empty value: expected a non-zero exit"
elif [ -s "${WORK_DIR}/args" ]; then
  fail "empty value: expected no request, got '$(tr '\n' ' ' < "${WORK_DIR}/args")'"
else
  pass "fails when no values remain after trimming"
fi

# Each required input is checked before any request goes out.
stub_curl "${OK_RESPONSE}" 200
PATH="${WORK_DIR}:${PATH}" MODE=files VALUE="https://example.com/app.js" \
  CLOUDFLARE_ZONE_ID="${ZONE_ID}" \
  bash "${UNDER_TEST}" > "${WORK_DIR}/output" 2>&1
status=$?
if [ "${status}" -eq 0 ]; then
  fail "missing token: expected a non-zero exit"
else
  pass "fails when CLOUDFLARE_API_TOKEN is not set"
fi

if [ "${FAILURES}" -gt 0 ]; then
  echo "${FAILURES} test(s) failed."
  exit 1
fi

echo "All tests passed."
