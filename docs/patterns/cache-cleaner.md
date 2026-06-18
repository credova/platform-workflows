# GitHub Actions Cache Cleanup

Clean up old GitHub Actions caches. Not a shared workflow. Add it directly to repos that need it.

## Scheduled cleanup

Add this workflow to your repo:

```yaml
name: Cache Cleanup
on:
  schedule:
    - cron: '0 0 * * 0'  # Weekly on Sunday midnight
  workflow_dispatch:

jobs:
  cleanup:
    runs-on: warp-ubuntu-2404-x64-2x
    permissions:
      actions: write
    steps:
      - name: Delete old caches
        shell: bash
        env:
          GH_TOKEN: ${{ github.token }}
          REPO: ${{ github.repository }}
        run: |
          echo "Listing caches..."
          gh actions-cache list -R "${REPO}" --sort created-at --order asc --limit 100 | while read -r key size _; do
            echo "Deleting cache: ${key}"
            gh actions-cache delete "${key}" -R "${REPO}" --confirm || true
          done
```

## With age filter

Delete only caches older than 7 days:

```yaml
      - name: Delete caches older than 7 days
        shell: bash
        env:
          GH_TOKEN: ${{ github.token }}
          REPO: ${{ github.repository }}
          MAX_AGE_DAYS: 7
        run: |
          CUTOFF=$(date -d "-${MAX_AGE_DAYS} days" +%s 2>/dev/null || date -v-${MAX_AGE_DAYS}d +%s)
          gh api "repos/${REPO}/actions/caches" --paginate --jq '.actions_caches[] | [.key, .created_at] | @tsv' | while read -r key created_at; do
            CACHE_TIME=$(date -d "${created_at}" +%s 2>/dev/null || date -jf "%Y-%m-%dT%H:%M:%S" "${created_at%%.*}" +%s)
            if [ "${CACHE_TIME}" -lt "${CUTOFF}" ]; then
              echo "Deleting old cache: ${key}"
              gh actions-cache delete "${key}" -R "${REPO}" --confirm || true
            fi
          done
```

## Notes

- GitHub auto-evicts caches after 7 days of no access.
- The 10GB per-repo cache limit evicts old caches as new ones are added.
- Use this for repos with many cache keys that hit the limit.
