# auth-gcp

> **Internal action** — consumed by `container`, `deployment`, and `secrets-setup`. Teams should not call this directly.

Authenticates to Google Cloud via Workload Identity Federation and configures Docker credentials for Artifact Registry.

## What it does

1. Authenticates to GCP via Workload Identity Federation (no service account keys, no PATs)
2. Sets up the `gcloud` CLI
3. Configures Docker for `us-docker.pkg.dev`

## Inputs

| Input | Required | Description |
|-------|----------|-------------|
| `project-id` | Yes | GCP project ID |
| `workload-identity-provider` | Yes | Workload Identity Provider resource name |

## Usage

This action is called internally by other actions. You should not need to reference it directly.

```yaml
# Called internally by container, deployment, secrets-setup
- uses: credova/platform-workflows/actions/auth-gcp@v1
  with:
    project-id: psq-shd-operations
    workload-identity-provider: projects/123456/locations/global/workloadIdentityPools/github/providers/github
```
