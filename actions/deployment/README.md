# deployment

Deploy to Cloud Run via pctl. Handles auth, notifications, canary, promote, and rollback. Self-contained: calls `auth-gcp` internally. Notifications are handled by pctl as part of the deploy process.

## Inputs

| Input                        | Required | Default       | Description                                        |
| ---------------------------- | -------- | ------------- | -------------------------------------------------- |
| `target`                     | Yes      | —             | Target name from CUE config                        |
| `tag`                        | No       | `github.sha`  | Image tag to deploy                                |
| `action`                     | No       | `deploy`      | Action: `deploy`, `promote`, `rollback`, `abort`   |
| `canary`                     | No       | `0`           | Canary traffic percentage (0 = full deploy)        |
| `config-path`                | No       | `deployments` | Path to CUE config directory                       |
| `revision`                   | No       | —             | Revision name (required for `promote`/`rollback`)  |
| `project-id`                 | No       | —             | GCP project ID                                     |
| `workload-identity-provider` | No       | —             | WIF provider resource name                         |
| `token`                      | Yes      | —             | GitHub token for pctl download (from GitHub App) |
| `pctl-version`             | No       | `latest`      | pctl version to install                          |

## Outputs

| Output     | Description                    |
| ---------- | ------------------------------ |
| `revision` | Deployed Cloud Run revision    |
| `traffic`  | JSON traffic allocation        |

## Examples

### Standard deploy

```yaml
- uses: credova/platform-workflows/actions/deployment@v1
  with:
    target: gcp-stg-central1
    tag: v1.2.3
    config-path: deployments/
    project-id: psq-shd-operations
    workload-identity-provider: projects/123/locations/global/...
    token: ${{ steps.auth.outputs.token }}
```

### Canary deploy (30% traffic)

```yaml
- uses: credova/platform-workflows/actions/deployment@v1
  with:
    target: gcp-prd-central1
    tag: v1.2.3
    canary: 30
    token: ${{ steps.auth.outputs.token }}
```

### Promote canary to 100%

```yaml
- uses: credova/platform-workflows/actions/deployment@v1
  with:
    target: gcp-prd-central1
    action: promote
    revision: ${{ steps.canary.outputs.revision }}
    token: ${{ steps.auth.outputs.token }}
```

### Rollback

```yaml
- uses: credova/platform-workflows/actions/deployment@v1
  with:
    target: gcp-prd-central1
    action: rollback
    token: ${{ steps.auth.outputs.token }}
```

## Notes

- Canary is only supported for Cloud Run Services, not Jobs. Jobs deploy to 100% immediately.
- pctl handles Slack notifications automatically as part of the deploy process.
- Wraps `pctl deploy execute` — CUE-based, type-safe deployment with native Go Cloud Run API calls.
