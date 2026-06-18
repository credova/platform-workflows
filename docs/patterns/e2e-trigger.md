# Cross-Repo E2E Test Trigger

Trigger E2E tests in another repo after a deploy. Not a shared action. Inline where needed.

## Fire and forget

Trigger E2E tests without waiting for results:

```yaml
- name: Trigger E2E tests
  shell: bash
  env:
    GH_TOKEN: ${{ secrets.E2E_TRIGGER_TOKEN }}
    ENVIRONMENT: staging
  run: |
    gh workflow run e2e.yaml \
      -R credova/impact-e2e \
      -f environment="${ENVIRONMENT}" \
      -f ref="${GITHUB_SHA}"
```

## Wait for completion

Trigger and poll until complete:

```yaml
- name: Trigger E2E tests
  id: trigger
  shell: bash
  env:
    GH_TOKEN: ${{ secrets.E2E_TRIGGER_TOKEN }}
    ENVIRONMENT: staging
  run: |
    gh workflow run e2e.yaml \
      -R credova/impact-e2e \
      -f environment="${ENVIRONMENT}" \
      -f ref="${GITHUB_SHA}"

    # Wait for the run to appear
    sleep 5

    # Find the run we just triggered
    RUN_ID=$(gh run list \
      -R credova/impact-e2e \
      -w e2e.yaml \
      --limit 1 \
      --json databaseId \
      --jq '.[0].databaseId')

    echo "run-id=${RUN_ID}" >> "$GITHUB_OUTPUT"

- name: Wait for E2E results
  shell: bash
  env:
    GH_TOKEN: ${{ secrets.E2E_TRIGGER_TOKEN }}
    RUN_ID: ${{ steps.trigger.outputs.run-id }}
  run: |
    echo "Waiting for E2E run #${RUN_ID}..."
    gh run watch "${RUN_ID}" -R credova/impact-e2e --exit-status
```

## Auth

The token needs `actions:write` permission on the target repo. Options:

1. **GitHub App token** via `auth-release-token` with the E2E repo in scope.
2. **Fine-grained PAT** scoped to the E2E repo with actions write permission.

## E2E repo setup

The target E2E repo needs a `workflow_dispatch` trigger:

```yaml
# In credova/impact-e2e .github/workflows/e2e.yaml
name: E2E Tests
on:
  workflow_dispatch:
    inputs:
      environment:
        description: Environment to test against
        required: true
        type: choice
        options:
          - staging
          - production
      ref:
        description: Commit SHA that triggered this run
        required: false
        type: string

jobs:
  e2e:
    runs-on: warp-ubuntu-2404-x64-2x
    steps:
      - uses: actions/checkout@v7
      # ... your E2E test steps
```
