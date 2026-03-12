# notification

Standalone Slack notifications for any use case. Wraps `pctl slack notify` with Block Kit formatted messages and threading support.

> **Note:** The `deployment` action handles notifications automatically via pctl. This action exists for custom workflows or non-deploy use cases.

## Inputs

| Input          | Required | Default              | Description                                 |
| -------------- | -------- | -------------------- | ------------------------------------------- |
| `channel`      | Yes      | —                    | Slack channel ID or name                    |
| `status`       | Yes      | —                    | `started`, `success`, `failed`, `cancelled` |
| `service`      | Yes      | —                    | Service name                                |
| `environment`  | Yes      | —                    | Environment name                            |
| `revision`     | No       | —                    | Deployed revision name                      |
| `deployer`     | No       | `github.actor`       | Who initiated                               |
| `pr-number`    | No       | —                    | Related PR number                           |
| `pr-url`       | No       | —                    | Related PR URL                              |
| `run-url`      | No       | Current workflow run | GitHub Actions run URL                      |
| `thread-ts`    | No       | —                    | Thread timestamp for updates                |
| `message`      | No       | —                    | Custom message override                     |
| `token`        | Yes      | —                    | GitHub token for pctl download              |
| `pctl-version` | No       | `latest`             | pctl version to install                     |

## Outputs

| Output       | Description                             |
| ------------ | --------------------------------------- |
| `message-ts` | Slack message timestamp (for threading) |
| `channel-id` | Slack channel ID                        |

## Examples

### Send a deploy started notification

```yaml
- uses: credova/platform-workflows/actions/notification@v1
  id: notify
  with:
    channel: deployments
    status: started
    service: psq-impact-api
    environment: production
    deployer: ${{ github.actor }}
```

### Thread a success follow-up onto the original message

```yaml
- uses: credova/platform-workflows/actions/notification@v1
  with:
    channel: deployments
    status: success
    service: psq-impact-api
    environment: production
    thread-ts: ${{ steps.notify.outputs.message-ts }}
```

### Custom message

```yaml
- uses: credova/platform-workflows/actions/notification@v1
  with:
    channel: deployments
    status: failed
    service: psq-impact-api
    environment: staging
    message: "Build failed due to flaky test — retrying"
```

## Message Formatting by Status

| Status      | Color  | Content                                                |
| ----------- | ------ | ------------------------------------------------------ |
| `started`   | Blue   | Deployment initiated with service/env/deployer context |
| `success`   | Green  | Includes revision, duration, links to service and PR   |
| `failed`    | Red    | Includes error context, links to workflow logs         |
| `cancelled` | Yellow | Includes reason and workflow link                      |
