# Playwright Browser Testing

Set up Playwright in your workflow. Not a shared action. Inline these steps where needed.

## Setup steps

Add after your `setup-language` step for Node:

```yaml
- name: Install Playwright browsers
  shell: bash
  run: npx playwright install --with-deps chromium

- name: Run Playwright tests
  shell: bash
  run: npx playwright test
```

## With caching

Cache browser binaries to speed up subsequent runs:

```yaml
- name: Get Playwright version
  id: pw-version
  shell: bash
  run: echo "version=$(jq -r '.devDependencies["@playwright/test"]' package.json | sed 's/^[^0-9]*//')" >> "$GITHUB_OUTPUT"

- name: Cache Playwright browsers
  id: pw-cache
  uses: actions/cache@v5
  with:
    path: ~/.cache/ms-playwright
    key: playwright-${{ steps.pw-version.outputs.version }}

- name: Install Playwright browsers
  if: steps.pw-cache.outputs.cache-hit != 'true'
  shell: bash
  run: npx playwright install --with-deps chromium
```

## With pnpm

If your project uses pnpm:

```yaml
- name: Install Playwright browsers
  if: steps.pw-cache.outputs.cache-hit != 'true'
  shell: bash
  run: pnpm playwright install --with-deps chromium
```

## Multiple browsers

Replace `chromium` with specific browsers, or use `--with-deps` alone for all:

```yaml
# Specific browsers
run: npx playwright install --with-deps chromium firefox

# All browsers
run: npx playwright install --with-deps
```
