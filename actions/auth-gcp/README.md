# auth-gcp

Authenticate to Google Cloud via Workload Identity Federation and configure Docker for Artifact Registry.

> **Internal action.** Consumed by `container`, `deployment`, and `secrets-setup`. Do not call directly.

## What it does

1. Authenticates to GCP via Workload Identity Federation (no service account keys, no PATs).
2. Sets up the `gcloud` CLI.
3. Configures Docker for `us-docker.pkg.dev`.

## Inputs

| Input                        | Required | Default             | Description                                  |
| ---------------------------- | -------- | ------------------- | -------------------------------------------- |
| `project-id`                 | Yes      | -                   | GCP project ID                               |
| `workload-identity-provider` | Yes      | -                   | Workload Identity Provider resource name     |
| `service-account`            | Yes      | -                   | Service account email to impersonate via WIF |
| `registry`                   | No       | `us-docker.pkg.dev` | Artifact Registry hostname                   |

## Examples

```yaml
# Called internally by container, deployment, secrets-setup
- uses: credova/platform-workflows/actions/auth-gcp@master
  with:
    project-id: <gcp-project-id>
    workload-identity-provider: projects/<project-number>/locations/global/workloadIdentityPools/<pool-name>/providers/<provider-name>
    service-account: <service-account-email>
```
