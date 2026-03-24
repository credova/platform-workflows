# deployment

Deploy to Cloud Run via pctl. Handles auth, notifications, canary, promote, and rollback. Self-contained: calls `auth-gcp` internally. Notifications are handled by pctl as part of the deploy process.

## Inputs

| Input                        | Required | Default       | Description                                      |
| ---------------------------- | -------- | ------------- | ------------------------------------------------ |
| `target`                     | Yes      | -             | Target name from CUE config                      |
| `tag`                        | No       | `github.sha`  | Image tag to deploy                              |
| `action`                     | No       | `deploy`      | Action: `deploy`, `promote`, `rollback`, `abort` |
| `canary`                     | No       | `0`           | Canary traffic percentage (0 = full deploy)      |
| `config-path`                | No       | `deployments` | Path to CUE config directory                     |
| `revision`                   | No       | -             | Revision name (for `promote`/`rollback`)         |
| `project-id`                 | No       | -             | GCP project ID                                   |
| `workload-identity-provider` | No       | -             | WIF provider resource name                       |
| `slack-token`                | No       | -             | Slack bot token for deploy notifications         |
| `token`                      | Yes      | -             | GitHub token for pctl download                   |
| `pctl-version`               | No       | `latest`      | pctl version to install                          |

## Outputs

| Output     | Description                 |
| ---------- | --------------------------- |
| `revision` | Deployed Cloud Run revision |
| `traffic`  | JSON traffic allocation     |

## Slack Notifications

When `notifications.enabled` is `true` in the CUE deployment config, pctl automatically sends Slack notifications throughout the deploy lifecycle:

1. **Deploy start** - posts initial "started" notification to the channel
2. **PR changelog** - thread reply listing PRs between the currently deployed revision and the new one
3. **Target started** - timeline thread reply when the target begins deploying
4. **Target completed/failed** - timeline thread reply with status and error message
5. **Main message update** - updates the original message to `success` or `failed`

To enable, either:

- Pass `slack-token` input to the action
- Set `PCTL_SLACK_BOT_TOKEN` as a workflow-level environment variable

The token is passed to pctl via `PCTL_SLACK_BOT_TOKEN`. The channel and template are configured in the CUE deployment config's `notifications` block.

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

### Deploy with Slack notifications

```yaml
- uses: credova/platform-workflows/actions/deployment@v1
  with:
    target: gcp-prd-central1
    tag: ${{ github.sha }}
    config-path: deployments/
    project-id: credova-prd-apps
    workload-identity-provider: projects/123/locations/global/...
    slack-token: ${{ secrets.PCTL_SLACK_BOT_TOKEN }}
    token: ${{ steps.auth.outputs.token }}
```

### Canary deploy (30% traffic)

```yaml
- uses: credova/platform-workflows/actions/deployment@v1
  with:
    target: gcp-prd-central1
    tag: v1.2.3
    canary: 30
    slack-token: ${{ secrets.PCTL_SLACK_BOT_TOKEN }}
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
- Wraps `pctl deploy execute` - CUE-based, type-safe deployment with native Go Cloud Run API calls.
- Notification channel and template are configured in the CUE config `notifications` block, not in the action inputs.
