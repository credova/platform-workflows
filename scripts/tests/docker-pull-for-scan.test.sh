#!/bin/bash
set -uo pipefail

# Tests for scripts/docker-pull-for-scan.sh. A stub `docker` on PATH records the
# arguments it receives, so each case asserts on the command the script builds.
# Run directly, or through `scripts/tests/run.sh` with the other test files.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UNDER_TEST="${SCRIPT_DIR}/../docker-pull-for-scan.sh"
IMAGE_REF="us-docker.pkg.dev/psq-test/api:abc123"

FAILURES=0
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "${WORK_DIR}"' EXIT

# Write a stub `docker` that logs its arguments and reports whether the image is
# in the local daemon.
#   $1 - "present" or "absent" for the `docker image inspect` result
#   $2 - exit code for `docker pull`
stub_docker() {
  local inspect_result="$1" pull_exit="$2"
  cat > "${WORK_DIR}/docker" <<EOF
#!/bin/bash
echo "\$*" >> "${WORK_DIR}/calls"
case "\$1" in
  image) [ "${inspect_result}" = "present" ] && exit 0 || exit 1 ;;
  pull)  exit ${pull_exit} ;;
esac
exit 0
EOF
  chmod +x "${WORK_DIR}/docker"
  : > "${WORK_DIR}/calls"
}

# Run the script under test with the stub in front of PATH.
#   $1 - value for PLATFORM
run_under_test() {
  PATH="${WORK_DIR}:${PATH}" IMAGE="${IMAGE_REF}" PLATFORM="$1" \
    bash "${UNDER_TEST}" > "${WORK_DIR}/output" 2>&1
}

pull_calls() {
  grep '^pull ' "${WORK_DIR}/calls" || true
}

fail() {
  echo "  FAIL: $1"
  echo "        calls: $(tr '\n' ';' < "${WORK_DIR}/calls")"
  FAILURES=$((FAILURES + 1))
}

pass() {
  echo "  ok: $1"
}

echo "docker-pull-for-scan.sh"

# A build that loaded the image leaves it local. Pulling again is wasted work.
stub_docker present 0
run_under_test linux/amd64
status=$?
if [ "${status}" -ne 0 ]; then
  fail "local image: expected exit 0, got ${status}"
elif [ -n "$(pull_calls)" ]; then
  fail "local image: expected no pull, got '$(pull_calls)'"
else
  pass "skips the pull when the image is already in the local daemon"
fi

# The reuse-hit case this action needs: nothing local, so pull before the scan.
stub_docker absent 0
run_under_test linux/amd64
status=$?
if [ "${status}" -ne 0 ]; then
  fail "absent image: expected exit 0, got ${status}"
elif [ "$(pull_calls)" != "pull --platform linux/amd64 ${IMAGE_REF}" ]; then
  fail "absent image: unexpected pull '$(pull_calls)'"
else
  pass "pulls with --platform when the image is absent"
fi

# `docker pull --platform` takes one platform, so a manifest list must omit it.
stub_docker absent 0
run_under_test linux/amd64,linux/arm64
status=$?
if [ "${status}" -ne 0 ]; then
  fail "multi-arch: expected exit 0, got ${status}"
elif [ "$(pull_calls)" != "pull ${IMAGE_REF}" ]; then
  fail "multi-arch: expected no --platform, got '$(pull_calls)'"
else
  pass "omits --platform for a multi-platform value"
fi

stub_docker absent 0
run_under_test ""
status=$?
if [ "${status}" -ne 0 ]; then
  fail "empty platform: expected exit 0, got ${status}"
elif [ "$(pull_calls)" != "pull ${IMAGE_REF}" ]; then
  fail "empty platform: expected no --platform, got '$(pull_calls)'"
else
  pass "omits --platform when PLATFORM is empty"
fi

# A failed pull must red the run. Silence here would skip the scan again.
stub_docker absent 1
run_under_test linux/amd64
status=$?
if [ "${status}" -eq 0 ]; then
  fail "failed pull: expected a non-zero exit"
else
  pass "fails the step when the pull fails"
fi

# IMAGE is required - an unset value must not reach `docker pull`.
stub_docker absent 0
PATH="${WORK_DIR}:${PATH}" PLATFORM=linux/amd64 \
  bash "${UNDER_TEST}" > "${WORK_DIR}/output" 2>&1
status=$?
if [ "${status}" -eq 0 ]; then
  fail "missing IMAGE: expected a non-zero exit"
else
  pass "fails when IMAGE is not set"
fi

if [ "${FAILURES}" -gt 0 ]; then
  echo "${FAILURES} test(s) failed."
  exit 1
fi

echo "All tests passed."
