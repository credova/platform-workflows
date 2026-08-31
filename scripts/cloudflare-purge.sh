#!/bin/bash
set -euo pipefail

# Purge entries from the Cloudflare cache.
# Required env vars: MODE, VALUE, CLOUDFLARE_ZONE_ID, CLOUDFLARE_CACHE_TOKEN
# API reference: https://developers.cloudflare.com/api/resources/cache/methods/purge/

: "${MODE:?MODE is required}"
: "${VALUE:?VALUE is required}"
: "${CLOUDFLARE_ZONE_ID:?CLOUDFLARE_ZONE_ID is required}"
: "${CLOUDFLARE_CACHE_TOKEN:?CLOUDFLARE_CACHE_TOKEN is required}"

case "${MODE}" in
  prefixes | files | tags) ;;
  *)
    echo "::error::MODE must be one of prefixes, files, tags (got '${MODE}')"
    exit 1
    ;;
esac

# One value per line. A line that parses as JSON is kept as an object, so `files`
# accepts both plain URLs and the {"url": ..., "headers": {...}} form the API takes.
BODY=$(printf '%s\n' "${VALUE}" | jq -Rn --arg mode "${MODE}" '
  {($mode): [
    inputs
    | gsub("^\\s+|\\s+$"; "")
    | select(length > 0)
    | if startswith("{") then (fromjson? // .) else . end
  ]}
')

COUNT=$(printf '%s' "${BODY}" | jq --arg mode "${MODE}" '.[$mode] | length')
if [ "${COUNT}" -eq 0 ]; then
  echo "::error::VALUE contained no ${MODE} to purge"
  exit 1
fi

echo "Purging ${COUNT} ${MODE} from zone ${CLOUDFLARE_ZONE_ID}"
printf '%s' "${BODY}" | jq --arg mode "${MODE}" -r '.[$mode][] | "  - " + (. | tostring)'

# --fail is deliberately omitted: on a 4xx the response body carries the reason,
# and curl would discard it.
RESPONSE=$(curl --silent --show-error \
  --request POST \
  --url "https://api.cloudflare.com/client/v4/zones/${CLOUDFLARE_ZONE_ID}/purge_cache" \
  --header 'Content-Type: application/json' \
  --header "Authorization: Bearer ${CLOUDFLARE_CACHE_TOKEN}" \
  --data "${BODY}" \
  --retry 3 --retry-connrefused \
  --write-out '\n%{http_code}')

HTTP_CODE=$(printf '%s' "${RESPONSE}" | tail -n1)
PAYLOAD=$(printf '%s' "${RESPONSE}" | sed '$d')

# A purge that silently no-ops leaves stale content served as if the deploy worked,
# so anything other than an explicit success fails the step.
if [ "${HTTP_CODE}" != "200" ] || [ "$(printf '%s' "${PAYLOAD}" | jq -r '.success // false')" != "true" ]; then
  echo "::error::Cloudflare purge failed (HTTP ${HTTP_CODE})"
  printf '%s' "${PAYLOAD}" | jq -r '.errors[]? | "  \(.code): \(.message)"' 2>/dev/null || printf '%s\n' "${PAYLOAD}"
  exit 1
fi

PURGE_ID=$(printf '%s' "${PAYLOAD}" | jq -r '.result.id // empty')
echo "Purge accepted (id=${PURGE_ID:-none})"

if [ -n "${GITHUB_OUTPUT:-}" ]; then
  echo "purge-id=${PURGE_ID}" >> "${GITHUB_OUTPUT}"
fi
