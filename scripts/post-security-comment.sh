#!/bin/bash
set -euo pipefail

# Post or update a unified security scan PR comment.
# Handles two phases: source (dir:.) and image (docker:<ref>).
# Multiple images each get their own section, keyed by IMAGE_NAME.
#
# Expects:
#   GH_TOKEN          - GitHub token
#   SCAN_PHASE        - "source" or "image"
#   IMAGE_NAME        - image name for multi-image support (only used for image phase)
#   SEVERITY          - threshold used (for display)
#   PACKAGES          - "true"/"false"
#   LICENSES          - "true"/"false"
#   BLOCK_ON_PACKAGES - "true"/"false"
#   BLOCK_ON_CODE     - "true"/"false"
#   BLOCK_ON_LICENSES - "true"/"false"

MAIN_MARKER="<!-- security-scan-report -->"
SOURCE_START="<!-- security-source-start -->"
SOURCE_END="<!-- security-source-end -->"
LICENSE_START="<!-- security-license-start -->"
LICENSE_END="<!-- security-license-end -->"
CODE_START="<!-- security-code-start -->"
CODE_END="<!-- security-code-end -->"
IMAGES_START="<!-- security-images-start -->"
IMAGES_END="<!-- security-images-end -->"

IMAGE_NAME="${IMAGE_NAME:-}"

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

BLOCK_ON_PACKAGES="${BLOCK_ON_PACKAGES:-true}"
BLOCK_ON_CODE="${BLOCK_ON_CODE:-true}"
BLOCK_ON_LICENSES="${BLOCK_ON_LICENSES:-false}"

# Build a blocking status line for a section
blocking_status() {
  local blocking="$1" detail="$2"
  if [ "$blocking" = "true" ]; then
    echo "> 🚫 **Blocking** — ${detail}"
  else
    echo "> ℹ️ Informational — not blocking."
  fi
}

MAX_VULN_FINDINGS="${MAX_VULN_FINDINGS:-20}"
MAX_CODE_FINDINGS="${MAX_CODE_FINDINGS:-20}"
MAX_LICENSE_FINDINGS="${MAX_LICENSE_FINDINGS:-20}"
RUN_URL="https://github.com/${GITHUB_REPOSITORY}/actions/runs/${GITHUB_RUN_ID}"

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
  elif [ "$total"    -gt 0 ]; then echo "⚠️ ${medium} medium, ${low} low"
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
    local vuln_shown=$(( high_plus < MAX_VULN_FINDINGS ? high_plus : MAX_VULN_FINDINGS ))
    echo "**Critical & High (showing ${vuln_shown} of ${high_plus})**"
    echo ""
    echo "| Package | Version | CVE | Severity | Fixed In |"
    echo "|---------|---------|-----|----------|----------|"
    jq -r --argjson max "$MAX_VULN_FINDINGS" '
      [ .matches[]
        | select(.vulnerability.severity == "Critical" or .vulnerability.severity == "High")
      ] | limit($max; .[])
      | "| \(.artifact.name) | \(.artifact.version) | \(.vulnerability.id) | \(.vulnerability.severity) | \(
          if (.vulnerability.fix.versions | length) > 0
          then .vulnerability.fix.versions[0]
          else "-"
          end
        ) |"
    ' "$results_file"
    if [ "$high_plus" -gt "$MAX_VULN_FINDINGS" ]; then
      echo ""
      echo "> $(( high_plus - MAX_VULN_FINDINGS )) more - [see full output](${RUN_URL})"
    fi
  fi
}

# Build the code scan section from SARIF output, grouped by language
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

  # Get languages by extracting from ruleId (e.g. "ruby.lang.security.foo" -> "ruby")
  # Fall back to file extension if ruleId doesn't have a language prefix
  local languages
  languages=$(jq -r '
    [.runs[0].results[] |
      (.ruleId | split(".")[0]) // "other"
    ] | unique | .[]
  ' opengrep-results.sarif)

  local rules_file
  rules_file=$(mktemp)
  jq '
    .runs[0].tool.driver.rules // [] | map({(.id): {uri: .helpUri, desc: (.shortDescription.text // .fullDescription.text // "")}}) | add // {}
  ' opengrep-results.sarif > "$rules_file"

  while IFS= read -r lang; do
    [ -z "$lang" ] && continue

    local lang_count
    lang_count=$(jq --arg lang "$lang" '
      [.runs[0].results[] | select(.ruleId | startswith($lang + "."))] | length
    ' opengrep-results.sarif)

    [ "$lang_count" -eq 0 ] && continue

    local lang_shown=$(( lang_count < MAX_CODE_FINDINGS ? lang_count : MAX_CODE_FINDINGS ))

    echo "<details>"
    echo "<summary><b>${lang}</b> — ${lang_count} finding(s) (showing ${lang_shown} of ${lang_count})</summary>"
    echo ""
    echo "| File | Rule | Description |"
    echo "|------|------|-------------|"
    jq -r --arg repo "$GITHUB_REPOSITORY" --arg sha "$GITHUB_SHA" --argjson max "$MAX_CODE_FINDINGS" --arg lang "$lang" --slurpfile rules "$rules_file" '
      .runs[0].results
      | [ .[] | select(.ruleId | startswith($lang + ".")) ]
      | limit($max; .[])
      | . as $r |
      ($r.locations[0].physicalLocation.artifactLocation.uri) as $file |
      ($r.locations[0].physicalLocation.region.startLine | tostring) as $line |
      ($rules[0][$r.ruleId]) as $rule |
      "| [\($file)#L\($line)](https://github.com/\($repo)/blob/\($sha)/\($file)#L\($line)) | \(if $rule.uri then "[\($r.ruleId)](\($rule.uri))" else $r.ruleId end) | \($rule.desc // "") |"
    ' opengrep-results.sarif
    echo ""
    if [ "$lang_count" -gt "$MAX_CODE_FINDINGS" ]; then
      echo "> $(( lang_count - MAX_CODE_FINDINGS )) more - [see full output](${RUN_URL})"
      echo ""
    fi
    echo "</details>"
    echo ""
  done <<< "$languages"

  rm -f "$rules_file"
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
    local lic_shown=$(( nonfree < MAX_LICENSE_FINDINGS ? nonfree : MAX_LICENSE_FINDINGS ))
    echo "<summary>Non-permissive licenses (showing ${lic_shown} of ${nonfree})</summary>"
    echo ""
    echo "| Package | License | Risk |"
    echo "|---------|---------|------|"
    jq -r --argjson max "$MAX_LICENSE_FINDINGS" '
      [ .[] | select(.risk == "High" or .risk == "Medium") ]
      | limit($max; .[])
      | "| \(.packageName) | \(.license) | \(.risk) |"
    ' grant-results.json 2>/dev/null || true
    if [ "$nonfree" -gt "$MAX_LICENSE_FINDINGS" ]; then
      echo ""
      echo "> $(( nonfree - MAX_LICENSE_FINDINGS )) more - [see full output](${RUN_URL})"
    fi
    echo ""
    echo "</details>"
  fi
}

# Fetch existing comment if present
EXISTING_ID=$(gh api "repos/${GITHUB_REPOSITORY}/issues/${PR_NUMBER}/comments" \
  --jq ".[] | select(.body | startswith(\"${MAIN_MARKER}\")) | .id" | head -1 || true)

EXISTING_BODY=""
if [ -n "$EXISTING_ID" ]; then
  EXISTING_BODY=$(gh api "repos/${GITHUB_REPOSITORY}/issues/comments/${EXISTING_ID}" --jq '.body')
fi

# --- Build sections based on scan phase ---

if [ "${SCAN_PHASE}" = "source" ]; then
  # Source phase: build source/code/license sections, preserve images section
  SOURCE_CONTENT=$(build_vuln_section "grype-source-results.json")
  CODE_CONTENT=$(build_code_section)
  LICENSE_CONTENT=$(build_license_section)
  IMAGES_CONTENT=$(extract_section "$IMAGES_START" "$IMAGES_END" "$EXISTING_BODY")
  [ -z "$IMAGES_CONTENT" ] && IMAGES_CONTENT="_Container image scans run after build._"
else
  # Image phase: build this image's section, merge into existing images content
  IMAGE_VULN_CONTENT=$(build_vuln_section "grype-image-results.json")

  # Use image name for the section, fall back to "default"
  LABEL="${IMAGE_NAME:-default}"
  IMG_MARKER_START="<!-- security-image-${LABEL}-start -->"
  IMG_MARKER_END="<!-- security-image-${LABEL}-end -->"
  IMAGE_BLOCKING=$(blocking_status "$BLOCK_ON_PACKAGES" "fails on ${SEVERITY}+ severity vulnerabilities")

  # Build this image's block
  THIS_IMAGE_BLOCK="${IMG_MARKER_START}
#### \`${LABEL}\`
${IMAGE_BLOCKING}

${IMAGE_VULN_CONTENT}
${IMG_MARKER_END}"

  # Get existing images content
  EXISTING_IMAGES=$(extract_section "$IMAGES_START" "$IMAGES_END" "$EXISTING_BODY")

  if [ -n "$EXISTING_IMAGES" ] && printf '%s' "$EXISTING_IMAGES" | grep -qF "$IMG_MARKER_START"; then
    # Replace this image's existing block
    IMAGES_CONTENT=$(printf '%s' "$EXISTING_IMAGES" | awk \
      -v start="$IMG_MARKER_START" \
      -v end="$IMG_MARKER_END" \
      -v replacement="$THIS_IMAGE_BLOCK" \
      'index($0, start){skip=1; printed=0} skip && index($0, end){print replacement; skip=0; printed=1; next} !skip{print}')
  elif [ -n "$EXISTING_IMAGES" ] && ! printf '%s' "$EXISTING_IMAGES" | grep -qF "_Container image scans run after build._"; then
    # Append this image after existing images
    IMAGES_CONTENT="${EXISTING_IMAGES}

${THIS_IMAGE_BLOCK}"
  else
    # First image
    IMAGES_CONTENT="$THIS_IMAGE_BLOCK"
  fi

  # Preserve source sections from existing comment
  SOURCE_CONTENT=$(extract_section "$SOURCE_START" "$SOURCE_END" "$EXISTING_BODY")
  CODE_CONTENT=$(extract_section "$CODE_START" "$CODE_END" "$EXISTING_BODY")
  LICENSE_CONTENT=$(extract_section "$LICENSE_START" "$LICENSE_END" "$EXISTING_BODY")
  [ -z "$SOURCE_CONTENT" ] && SOURCE_CONTENT="_Source scan results unavailable._"
  [ -z "$CODE_CONTENT" ]   && CODE_CONTENT="_Code scan results unavailable._"
  [ -z "$LICENSE_CONTENT" ] && LICENSE_CONTENT="_License scan results unavailable._"
fi

# Build blocking status lines for source sections
SOURCE_BLOCKING=$(blocking_status "$BLOCK_ON_PACKAGES" "fails on ${SEVERITY}+ severity vulnerabilities")
CODE_BLOCKING=$(blocking_status "$BLOCK_ON_CODE" "fails on code analysis findings")
LICENSE_BLOCKING=$(blocking_status "$BLOCK_ON_LICENSES" "fails on high-risk (strong copyleft) licenses")

# Assemble
COMMENT_BODY="${MAIN_MARKER}
## Security Scan

### Source - Package & OS Vulnerabilities
${SOURCE_BLOCKING}

${SOURCE_START}
${SOURCE_CONTENT}
${SOURCE_END}

### Container Images - Package & OS Vulnerabilities

${IMAGES_START}
${IMAGES_CONTENT}
${IMAGES_END}

### Code - Static Analysis
${CODE_BLOCKING}

${CODE_START}
${CODE_CONTENT}
${CODE_END}

### Licenses
${LICENSE_BLOCKING}

${LICENSE_START}
${LICENSE_CONTENT}
${LICENSE_END}"

# Write body to temp file - avoids "Argument list too long" with large outputs
BODY_FILE=$(mktemp)
printf '%s' "$COMMENT_BODY" > "$BODY_FILE"

# Post or update via GitHub API
if [ -n "$EXISTING_ID" ]; then
  jq -n --rawfile body "$BODY_FILE" '{body: $body}' \
    | gh api "repos/${GITHUB_REPOSITORY}/issues/comments/${EXISTING_ID}" \
        --method PATCH --input - > /dev/null
  echo "Updated security comment #${EXISTING_ID}"
else
  jq -n --rawfile body "$BODY_FILE" '{body: $body}' \
    | gh api "repos/${GITHUB_REPOSITORY}/issues/${PR_NUMBER}/comments" \
        --method POST --input - > /dev/null
  echo "Posted new security comment on PR #${PR_NUMBER}"
fi

rm -f "$BODY_FILE"
