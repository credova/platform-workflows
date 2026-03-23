# secrets-setup

Load secrets from GCP Secret Manager into the workflow environment via mise + fnox. Self-contained: calls `auth-gcp` internally.

## Inputs

| Input                        | Required | Description                                        |
| ---------------------------- | -------- | -------------------------------------------------- |
| `profile`                    | Yes      | fnox profile (maps to secret paths in `fnox.toml`) |
| `project-id`                 | Yes      | GCP project ID for Secret Manager access           |
| `workload-identity-provider` | Yes      | Workload Identity Provider resource name           |

## Examples

### Load dev secrets

```yaml
- uses: credova/platform-workflows/actions/secrets-setup@v1
  with:
    profile: dev
    project-id: psq-shd-ops
    workload-identity-provider: projects/123/locations/global/...
```

### Load production secrets

```yaml
- uses: credova/platform-workflows/actions/secrets-setup@v1
  with:
    profile: prd
    project-id: psq-shd-ops
    workload-identity-provider: projects/123/locations/global/...
```

## How It Works

1. `auth-gcp` — authenticates to GCP via Workload Identity Federation
2. Sets up mise + fnox
3. Reads `fnox.toml` in the repo to determine which secrets to load for the given profile
4. Secrets are exported as environment variables for all subsequent steps
