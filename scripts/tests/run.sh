#!/bin/bash
set -uo pipefail

# Run every *.test.sh in this directory and report a single pass or fail.
# The tests need bash only - they stub the commands they exercise on PATH.

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FAILED=0

for test_file in "${TESTS_DIR}"/*.test.sh; do
  [ -e "${test_file}" ] || continue
  if ! bash "${test_file}"; then
    echo "::error file=scripts/tests/$(basename "${test_file}")::test file failed"
    FAILED=$((FAILED + 1))
  fi
done

if [ "${FAILED}" -gt 0 ]; then
  echo "${FAILED} test file(s) failed."
  exit 1
fi

echo "All script tests passed."
