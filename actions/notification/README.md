# notification

Standalone Slack notifications. Wraps `pctl slack notify` with Block Kit messages and threading.

> **Note:** The `deployment` action handles notifications automatically via pctl. Use this action for custom or non-deploy workflows.

## Inputs

### Required

| Input         | Required | Default | Description                                 |
| ------------- | -------- | ------- | ------------------------------------------- |
| `channel`     | Yes      | -       | Slack channel ID or name (required)         |
| `status`      | Yes      | -       | `started`, `success`, `failed`, `cancelled` |
| `service`     | Yes      | -       | Service name                                |
| `slack-token` | Yes      | -       | Slack bot token                             |
| `token`       | Yes      | -       | GitHub token for pctl download              |

### Optional

| Input          | Required | Default        | Description                                                   |
| -------------- | -------- | -------------- | ------------------------------------------------------------- |
| `host`         | No       | -              | Service host/URL                                              |
| `project`      | No       | -              | GCP project ID                                                |
| `author`       | No       | `github.actor` | Commit author / who triggered                                 |
| `approver`     | No       | -              | Who approved the release                                      |
| `revision`     | No       | -              | Deployed revision name                                        |
| `message`      | No       | -              | Commit message or custom text                                 |
| `thread-ts`    | No       | -              | Without `reply`: updates in-place; with `reply`: thread reply |
| `reply`        | No       | `false`        | Post as thread reply instead of updating in-place             |
| `template`     | No       | -              | Template name (`deploy`, `general`, `security`) or file path  |
| `pctl-version` | No       | `latest`       | pctl version to install                                       |

### Links

Each appears in the notification only when a value is provided.

| Input               | Required | Default              | Description                        |
| ------------------- | -------- | -------------------- | ---------------------------------- |
| `run-url`           | No       | Current workflow run | GitHub Actions run URL             |
| `story-url`         | No       | -                    | Shortcut story URL                 |
| `gcp-logs-url`      | No       | -                    | GCP Cloud Run logs URL             |
| `dashboard-url`     | No       | -                    | Observability dashboard URL        |
| `rollback-url`      | No       | -                    | GCP console rollback URL           |
| `rollback-revision` | No       | -                    | Revision number for rollback label |

## Outputs

| Output       | Description                             |
| ------------ | --------------------------------------- |
| `message-ts` | Slack message timestamp (for threading) |
| `channel-id` | Slack channel ID                        |

## Message Modes

1. **New message:** no `thread-ts`. Posts a new message to the channel.
2. **Update in-place:** `thread-ts` without `reply`. Updates the existing message (e.g. started to completed).
3. **Thread reply:** `thread-ts` with `reply: "true"`. Posts a timeline event under the parent.

## Examples

### Post a deploy started notification

```yaml
- uses: credova/platform-workflows/actions/notification@master
  id: notify
  with:
    channel: <your-slack-channel-id>
    status: started
    service: psq-impact-api
    host: api.example.com
    project: <gcp-project-id>
    slack-token: ${{ secrets.PCTL_SLACK_BOT_TOKEN }}
    token: ${{ steps.auth.outputs.token }}
```

### Update the original message to success

```yaml
- uses: credova/platform-workflows/actions/notification@master
  with:
    channel: <your-slack-channel-id>
    status: success
    service: psq-impact-api
    thread-ts: ${{ steps.notify.outputs.message-ts }}
    slack-token: ${{ secrets.PCTL_SLACK_BOT_TOKEN }}
    token: ${{ steps.auth.outputs.token }}
```

### Post a thread reply (timeline event)

```yaml
- uses: credova/platform-workflows/actions/notification@master
  with:
    channel: <your-slack-channel-id>
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
- uses: credova/platform-workflows/actions/notification@master
  with:
    channel: <your-slack-channel-id>
    status: started
    service: psq-impact-api
    template: general
    message: "Database migration running"
    slack-token: ${{ secrets.PCTL_SLACK_BOT_TOKEN }}
    token: ${{ steps.auth.outputs.token }}
```
