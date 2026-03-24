#!/bin/bash
set -euo pipefail

# Post or update a unified security scan PR comment.
# Handles two phases: source (dir:.) and image (docker:<ref>).
# Both phases write to the same comment - phase 2 preserves phase 1 content.
#
# Expects:
#   GH_TOKEN   - GitHub token
#   SCAN_PHASE - "source" or "image"
#   SEVERITY   - threshold used (for display)
#   PACKAGES   - "true"/"false"
#   LICENSES   - "true"/"false"

MAIN_MARKER="<!-- security-scan-report -->"
SOURCE_START="<!-- security-source-start -->"
SOURCE_END="<!-- security-source-end -->"
IMAGE_START="<!-- security-image-start -->"
IMAGE_END="<!-- security-image-end -->"
LICENSE_START="<!-- security-license-start -->"
LICENSE_END="<!-- security-license-end -->"
CODE_START="<!-- security-code-start -->"
CODE_END="<!-- security-code-end -->"

PR_NUMBER=$(jq -r '.pull_request.number // empty' "$GITHUB_EVENT_PATH")
if [ -z "$PR_NUMBER" ]; then
  echo "Not a pull request - skipping comment"
  exit 0
fi

# Extract section content from an existing comment body (exclusive of markers)
extract_section() {
  local start="$1" end="$2" body="$3"
  printf '%s' "$body" | awk \
    "found && index(\$0, \"${end}\"){found=0; next} found{print} index(\$0, \"${start}\"){found=1}" \
    || true
}

# Build the vuln table for a results file
build_vuln_section() {
  local results_file="$1"

  if [ ! -f "$results_file" ]; then
    echo "_Scan not run._"
    return
  fi

  local critical high medium low total high_plus
  critical=$(jq '[.matches[] | select(.vulnerability.severity == "Critical")] | length' "$results_file")
  high=$(jq     '[.matches[] | select(.vulnerability.severity == "High")]     | length' "$results_file")
  medium=$(jq   '[.matches[] | select(.vulnerability.severity == "Medium")]   | length' "$results_file")
  low=$(jq      '[.matches[] | select(.vulnerability.severity == "Low")]      | length' "$results_file")
  total=$(( critical + high + medium + low ))
  high_plus=$(( critical + high ))

  if   [ "$critical" -gt 0 ]; then echo "❌ ${critical} critical, ${high} high, ${medium} medium, ${low} low"
  elif [ "$high"     -gt 0 ]; then echo "❌ ${high} high, ${medium} medium, ${low} low"
  elif [ "$total"    -gt 0 ]; then echo "⚠️ ${medium} medium, ${low} low - no blockers at ${SEVERITY}+"
  else                              echo "✅ Clean"
  fi

  echo ""
  echo "| Severity | Count |"
  echo "|----------|------:|"
  echo "| 🔴 Critical | ${critical} |"
  echo "| 🟠 High     | ${high} |"
  echo "| 🟡 Medium   | ${medium} |"
  echo "| 🔵 Low      | ${low} |"

  if [ "$high_plus" -gt 0 ]; then
    echo ""
    echo "**Critical & High (${high_plus})**"
    echo ""
    echo "| Package | Version | CVE | Severity | Fixed In |"
    echo "|---------|---------|-----|----------|----------|"
    jq -r '
      .matches[]
      | select(.vulnerability.severity == "Critical" or .vulnerability.severity == "High")
      | "| \(.artifact.name) | \(.artifact.version) | \(.vulnerability.id) | \(.vulnerability.severity) | \(
          if (.vulnerability.fix.versions | length) > 0
          then .vulnerability.fix.versions[0]
          else "-"
          end
        ) |"
    ' "$results_file"
  fi
}

# Build the code scan section from SARIF output
build_code_section() {
  if [ ! -f "opengrep-results.sarif" ]; then
    echo "_Code scan not run._"
    return
  fi

  local count
  count=$(jq '[.runs[].results[]] | length' opengrep-results.sarif)

  if [ "$count" -eq 0 ]; then
    echo "✅ Clean"
    return
  fi

  echo "⚠️ ${count} finding(s)"
  echo ""
  echo "<details>"
  echo "<summary>Findings (${count})</summary>"
  echo ""
  echo "| File | Rule | Description |"
  echo "|------|------|-------------|"
  jq -r --arg repo "$GITHUB_REPOSITORY" --arg sha "$GITHUB_SHA" '
    .runs[0] |
    (.tool.driver.rules // [] | map({(.id): {uri: .helpUri, desc: (.shortDescription.text // .fullDescription.text // "")}}) | add // {}) as $rules |
    .results[] |
    . as $r |
    ($r.locations[0].physicalLocation.artifactLocation.uri) as $file |
    ($r.locations[0].physicalLocation.region.startLine | tostring) as $line |
    ($rules[$r.ruleId]) as $rule |
    "| [\($file)#L\($line)](https://github.com/\($repo)/blob/\($sha)/\($file)#L\($line)) | \(if $rule.uri then "[\($r.ruleId)](\($rule.uri))" else $r.ruleId end) | \($rule.desc // "") |"
  ' opengrep-results.sarif
  echo ""
  echo "</details>"
}

# Build the license table
build_license_section() {
  if [ ! -f "grant-results.json" ]; then
    echo "_License scan not run._"
    return
  fi

  local high_l med_l low_l nonfree
  high_l=$(jq '[.[] | select(.risk == "High")]   | length' grant-results.json 2>/dev/null || echo 0)
  med_l=$(jq  '[.[] | select(.risk == "Medium")] | length' grant-results.json 2>/dev/null || echo 0)
  low_l=$(jq  '[.[] | select(.risk == "Low")]    | length' grant-results.json 2>/dev/null || echo 0)
  nonfree=$(( high_l + med_l ))

  echo "| Risk | Packages |"
  echo "|------|------:|"
  echo "| 🔴 High (strong copyleft) | ${high_l} |"
  echo "| 🟡 Medium (weak copyleft) | ${med_l} |"
  echo "| 🟢 Low (permissive)       | ${low_l} |"

  if [ "$nonfree" -gt 0 ]; then
    echo ""
    echo "<details>"
    echo "<summary>Non-permissive licenses (${nonfree})</summary>"
    echo ""
    echo "| Package | License | Risk |"
    echo "|---------|---------|------|"
    jq -r '
      .[]
      | select(.risk == "High" or .risk == "Medium")
      | "| \(.packageName) | \(.license) | \(.risk) |"
    ' grant-results.json 2>/dev/null || true
    echo ""
    echo "</details>"
  fi

  echo ""
  echo "> ℹ️ License scan is informational - not blocking."
}

# Fetch existing comment if present
EXISTING_ID=$(gh api "repos/${GITHUB_REPOSITORY}/issues/${PR_NUMBER}/comments" \
  --jq ".[] | select(.body | startswith(\"${MAIN_MARKER}\")) | .id" | head -1 || true)

EXISTING_BODY=""
if [ -n "$EXISTING_ID" ]; then
  EXISTING_BODY=$(gh api "repos/${GITHUB_REPOSITORY}/issues/comments/${EXISTING_ID}" --jq '.body')
fi

# Build each section - use local results for current phase, preserve existing for the other
if [ "${SCAN_PHASE}" = "source" ]; then
  SOURCE_CONTENT=$(build_vuln_section "grype-source-results.json")
  CODE_CONTENT=$(build_code_section)
  LICENSE_CONTENT=$(build_license_section)
  IMAGE_CONTENT=$(extract_section "$IMAGE_START" "$IMAGE_END" "$EXISTING_BODY")
  [ -z "$IMAGE_CONTENT" ] && IMAGE_CONTENT="_Container image scan runs after build._"
else
  IMAGE_CONTENT=$(build_vuln_section "grype-image-results.json")
  SOURCE_CONTENT=$(extract_section "$SOURCE_START" "$SOURCE_END" "$EXISTING_BODY")
  CODE_CONTENT=$(extract_section "$CODE_START" "$CODE_END" "$EXISTING_BODY")
  LICENSE_CONTENT=$(extract_section "$LICENSE_START" "$LICENSE_END" "$EXISTING_BODY")
  [ -z "$SOURCE_CONTENT" ] && SOURCE_CONTENT="_Source scan results unavailable._"
  [ -z "$CODE_CONTENT" ]   && CODE_CONTENT="_Code scan results unavailable._"
  [ -z "$LICENSE_CONTENT" ] && LICENSE_CONTENT="_License scan results unavailable._"
fi

# Assemble
COMMENT_BODY="${MAIN_MARKER}
## Security Scan

### Source - Package & OS Vulnerabilities
${SOURCE_START}
${SOURCE_CONTENT}
${SOURCE_END}

### Container Image - Package & OS Vulnerabilities
${IMAGE_START}
${IMAGE_CONTENT}
${IMAGE_END}

### Code - Static Analysis
${CODE_START}
${CODE_CONTENT}
${CODE_END}

### Licenses
${LICENSE_START}
${LICENSE_CONTENT}
${LICENSE_END}"

# Post or update via GitHub API (jq handles special character encoding)
if [ -n "$EXISTING_ID" ]; then
  jq -n --arg body "$COMMENT_BODY" '{body: $body}' \
    | gh api "repos/${GITHUB_REPOSITORY}/issues/comments/${EXISTING_ID}" \
        --method PATCH --input - > /dev/null
  echo "Updated security comment #${EXISTING_ID}"
else
  jq -n --arg body "$COMMENT_BODY" '{body: $body}' \
    | gh api "repos/${GITHUB_REPOSITORY}/issues/${PR_NUMBER}/comments" \
        --method POST --input - > /dev/null
  echo "Posted new security comment on PR #${PR_NUMBER}"
fi
