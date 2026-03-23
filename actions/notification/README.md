# notification

Standalone Slack notifications for any use case. Wraps `pctl slack notify` with Block Kit formatted messages and threading support.

> **Note:** The `deployment` action handles notifications automatically via pctl. This action exists for custom workflows or non-deploy use cases.

## Inputs

### Required Notification Inputs

| Input         | Required | Default | Description                                 |
| ------------- | -------- | ------- | ------------------------------------------- |
| `channel`     | Yes      | —       | Slack channel ID or name                    |
| `status`      | Yes      | —       | `started`, `success`, `failed`, `cancelled` |
| `service`     | Yes      | —       | Service name                                |
| `slack-token` | Yes      | —       | Slack bot token                             |
| `token`       | Yes      | —       | GitHub token for pctl download              |

### Optional Notification Inputs

| Input          | Required | Default        | Description                                                   |
| -------------- | -------- | -------------- | ------------------------------------------------------------- |
| `host`         | No       | —              | Service host/URL                                              |
| `project`      | No       | —              | GCP project ID                                                |
| `author`       | No       | `github.actor` | Commit author / who triggered                                 |
| `approver`     | No       | —              | Who approved the release                                      |
| `revision`     | No       | —              | Deployed revision name                                        |
| `message`      | No       | —              | Commit message or custom text                                 |
| `thread-ts`    | No       | —              | Without `reply`: updates in-place; with `reply`: thread reply |
| `reply`        | No       | `false`        | Post as thread reply instead of updating in-place             |
| `template`     | No       | —              | Template name (`deploy`, `general`, `security`) or file path  |
| `pctl-version` | No       | `latest`       | pctl version to install                                       |

### Link Inputs

These only appear in the notification if a value is provided:

| Input               | Required | Default              | Description                        |
| ------------------- | -------- | -------------------- | ---------------------------------- |
| `run-url`           | No       | Current workflow run | GitHub Actions run URL             |
| `story-url`         | No       | —                    | Shortcut story URL                 |
| `gcp-logs-url`      | No       | —                    | GCP Cloud Run logs URL             |
| `dashboard-url`     | No       | —                    | Observability dashboard URL        |
| `rollback-url`      | No       | —                    | GCP console rollback URL           |
| `rollback-revision` | No       | —                    | Revision number for rollback label |

## Outputs

| Output       | Description                             |
| ------------ | --------------------------------------- |
| `message-ts` | Slack message timestamp (for threading) |
| `channel-id` | Slack channel ID                        |

## Message Modes

1. **New message** — no `thread-ts`: posts a new message to the channel
2. **Update in-place** — `thread-ts` without `reply`: updates the existing message (e.g., started -> completed)
3. **Thread reply** — `thread-ts` with `reply: "true"`: posts a lightweight timeline event under the parent

## Examples

### Post a deploy started notification

```yaml
- uses: credova/platform-workflows/actions/notification@v1
  id: notify
  with:
    channel: C025J9R5YQP
    status: started
    service: psq-impact-api
    host: api.example.com
    project: credova-prd-apps
    slack-token: ${{ secrets.PCTL_SLACK_BOT_TOKEN }}
    token: ${{ steps.auth.outputs.token }}
```

### Update the original message to success

```yaml
- uses: credova/platform-workflows/actions/notification@v1
  with:
    channel: C025J9R5YQP
    status: success
    service: psq-impact-api
    thread-ts: ${{ steps.notify.outputs.message-ts }}
    slack-token: ${{ secrets.PCTL_SLACK_BOT_TOKEN }}
    token: ${{ steps.auth.outputs.token }}
```

### Post a thread reply (timeline event)

```yaml
- uses: credova/platform-workflows/actions/notification@v1
  with:
    channel: C025J9R5YQP
    status: failed
    service: psq-impact-api
    thread-ts: ${{ steps.notify.outputs.message-ts }}
    reply: "true"
    message: "container failed health check after 300s"
    slack-token: ${{ secrets.PCTL_SLACK_BOT_TOKEN }}
    token: ${{ steps.auth.outputs.token }}
```

### Custom message with general template

```yaml
- uses: credova/platform-workflows/actions/notification@v1
  with:
    channel: C025J9R5YQP
    status: started
    service: psq-impact-api
    template: general
    message: "Database migration running"
    slack-token: ${{ secrets.PCTL_SLACK_BOT_TOKEN }}
    token: ${{ steps.auth.outputs.token }}
```
