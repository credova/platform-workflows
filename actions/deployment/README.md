# deployment

Deploy to Cloud Run via pctl. Handles auth, notifications, and tag-based canary rollouts (promote, abort, set-weight, rollback). Calls `auth-gcp` internally. Notifications are handled by pctl during deploy.

pctl tracks revision roles with Cloud Run revision tags (`stable` / `canary`) and manages traffic through the `pctl deploy rollout` command group. A canary deploy tags the new revision `canary`; `promote` sends it 100% traffic and makes it `stable`, `abort` restores traffic to `stable`, and `set-weight` shifts the split without ending the rollout.

## Inputs

| Input                        | Required | Default       | Description                                        |
| ---------------------------- | -------- | ------------- | -------------------------------------------------- |
| `target`                     | Yes      | -             | Target name from CUE config                        |
| `tag`                        | No       | `github.sha`  | Image tag to deploy                                |
| `action`                     | No       | `deploy`      | Action: `deploy`, `promote`, `abort`, `set-weight`, `status`, `rollback` |
| `canary`                     | No       | -             | `deploy`: canary traffic % — empty = full deploy, `0` = dark canary (no traffic), `1-99` = canary rollout; `set-weight`: target canary weight (0-100) |
| `config-path`                | No       | `deployments` | Path to CUE config directory                       |
| `revision`                   | No       | -             | Explicit revision to roll back to (`rollback` only) |
| `project-id`                 | No       | -             | GCP project ID                                     |
| `workload-identity-provider` | No       | -             | WIF provider resource name                         |
| `slack-token`                | No       | -             | Slack bot token for deploy notifications           |
| `token`                      | Yes      | -             | GitHub token for pctl download                     |
| `pctl-version`               | No       | `latest`      | pctl version to install                            |
| `dash0-url`                  | No       | -             | Dash0 OTLP ingest base URL (region-specific)       |
| `dash0-token`                | No       | -             | Dash0 ingest token (emits deploy event on success) |

## Outputs

| Output     | Description                 |
| ---------- | --------------------------- |
| `revision` | Deployed Cloud Run revision |
| `traffic`  | JSON traffic allocation     |

## Slack Notifications

When `notifications.enabled` is `true` in the CUE deployment config, pctl sends Slack notifications throughout the deploy lifecycle:

1. **Deploy start:** posts initial "started" notification to the channel.
2. **PR changelog:** thread reply listing PRs between the currently deployed revision and the new one.
3. **Target started:** timeline thread reply when the target begins deploying.
4. **Target completed/failed:** timeline thread reply with status and error message.
5. **Main message update:** updates the original message to `success` or `failed`.

To enable, either:

- Pass `slack-token` input to the action.
- Set `PCTL_SLACK_BOT_TOKEN` as a workflow-level environment variable.

The token is passed to pctl via `PCTL_SLACK_BOT_TOKEN`. The channel and template are set in the CUE deployment config's `notifications` block.

## Examples

### Standard deploy

```yaml
- uses: credova/platform-workflows/actions/deployment@master
  with:
    target: gcp-stg-central1
    tag: v1.2.3
    config-path: deployments/
    project-id: <gcp-project-id>
    workload-identity-provider: projects/<project-number>/locations/global/...
    token: ${{ steps.auth.outputs.token }}
```

### Deploy with Slack notifications

```yaml
- uses: credova/platform-workflows/actions/deployment@master
  with:
    target: gcp-prd-central1
    tag: ${{ github.sha }}
    config-path: deployments/
    project-id: <gcp-project-id>
    workload-identity-provider: projects/<project-number>/locations/global/...
    slack-token: ${{ secrets.PCTL_SLACK_BOT_TOKEN }}
    token: ${{ steps.auth.outputs.token }}
```

### Canary deploy (30% traffic)

```yaml
- uses: credova/platform-workflows/actions/deployment@master
  with:
    target: gcp-prd-central1
    tag: v1.2.3
    canary: 30
    slack-token: ${{ secrets.PCTL_SLACK_BOT_TOKEN }}
    token: ${{ steps.auth.outputs.token }}
```

### Promote canary to 100%

Promotes whichever revision holds the `canary` tag — no revision needs to be passed.

```yaml
- uses: credova/platform-workflows/actions/deployment@master
  with:
    target: gcp-prd-central1
    action: promote
    token: ${{ steps.auth.outputs.token }}
```

### Shift canary weight (ramp)

```yaml
- uses: credova/platform-workflows/actions/deployment@master
  with:
    target: gcp-prd-central1
    action: set-weight
    canary: 50
    token: ${{ steps.auth.outputs.token }}
```

### Abort canary (restore traffic to stable)

```yaml
- uses: credova/platform-workflows/actions/deployment@master
  with:
    target: gcp-prd-central1
    action: abort
    token: ${{ steps.auth.outputs.token }}
```

### Rollback

```yaml
- uses: credova/platform-workflows/actions/deployment@master
  with:
    target: gcp-prd-central1
    action: rollback
    token: ${{ steps.auth.outputs.token }}
```

## Notes

- Canary is supported for Cloud Run Services only, not Jobs. Jobs deploy to 100% immediately.
- Wraps `pctl deploy execute`: CUE-based, type-safe deployment with native Go Cloud Run API calls.
- Notification channel and template are set in the CUE config `notifications` block, not in action inputs.
