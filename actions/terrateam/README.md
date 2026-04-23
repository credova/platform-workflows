# terrateam

Shared Terrateam composite action for Pulumi/Terraform repos. Handles GCP OIDC auth, optional GitHub App token for cross-repo access, optional Tailscale VPN, and Terrateam execution.

Repos keep a thin `terrateam.yml` wrapper with `workflow_dispatch` triggers that delegates to this action.

## Inputs

| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| `project-id` | yes | | GCP project ID |
| `workload-identity-provider` | yes | | GCP Workload Identity Provider resource name |
| `service-account` | yes | | GCP service account email |
| `work-token` | yes | | Terrateam work token (from `workflow_dispatch` input) |
| `api-base-url` | no | `""` | Terrateam API base URL (from `workflow_dispatch` input) |
| `github-app-id` | no | `""` | GitHub App ID for cross-repo token generation |
| `github-app-private-key` | no | `""` | GitHub App private key PEM |
| `tailscale` | no | `"false"` | Connect to Tailscale VPN before running |
| `tailscale-oauth-client-id` | no | `""` | Tailscale OAuth client ID (required if `tailscale` is `true`) |
| `tailscale-oauth-secret` | no | `""` | Tailscale OAuth secret (required if `tailscale` is `true`) |

## Important

The caller workflow **must** pass `SECRETS_CONTEXT` and `VARIABLES_CONTEXT` as `env` vars on the step that uses this action, since composite actions cannot access the `secrets` or `vars` contexts directly.

## Usage

Create `.github/workflows/terrateam.yml` in your repo:

```yaml
name: 'Terrateam Workflow'
on:
  workflow_dispatch:
    inputs:
      work-token:
        description: 'Work Token'
        required: true
      api-base-url:
        description: 'API Base URL'
      environment:
        description: 'Environment in which to run the action'
        type: environment
      runs_on:
        description: 'runs-on configuration'
        type: string
        default: '"warp-ubuntu-2204-x64-2x"'
jobs:
  terrateam:
    permissions:
      id-token: write
      contents: read
    runs-on: ${{ fromJSON(github.event.inputs.runs_on) }}
    timeout-minutes: 1440
    name: Terrateam Action
    environment: '${{ github.event.inputs.environment }}'
    steps:
      - uses: credova/platform-workflows/actions/terrateam@master
        with:
          project-id: fxt-ops-shd
          workload-identity-provider: projects/640813936102/locations/global/workloadIdentityPools/github-actions/providers/github
          service-account: repo-YOUR-REPO-access@fxt-ops-shd.iam.gserviceaccount.com
          work-token: ${{ github.event.inputs.work-token }}
          api-base-url: ${{ github.event.inputs.api-base-url }}
          github-app-id: ${{ vars.IAC_TOKEN_APP_ID }}
          github-app-private-key: ${{ secrets.IAC_TOKEN_APP_PRIVATE_KEY }}
        env:
          SECRETS_CONTEXT: ${{ toJson(secrets) }}
          VARIABLES_CONTEXT: ${{ toJson(vars) }}
```

Replace `YOUR-REPO` in the service account email with your repo name.

### With Tailscale VPN

For repos that need VPN access (e.g., to reach private databases):

```yaml
      - uses: credova/platform-workflows/actions/terrateam@master
        with:
          project-id: fxt-ops-shd
          workload-identity-provider: projects/640813936102/locations/global/workloadIdentityPools/github-actions/providers/github
          service-account: repo-YOUR-REPO-access@fxt-ops-shd.iam.gserviceaccount.com
          work-token: ${{ github.event.inputs.work-token }}
          api-base-url: ${{ github.event.inputs.api-base-url }}
          tailscale: "true"
          tailscale-oauth-client-id: ${{ secrets.TAILSCALE_OAUTH_CLIENT_ID }}
          tailscale-oauth-secret: ${{ secrets.TAILSCALE_OAUTH_SECRET }}
        env:
          SECRETS_CONTEXT: ${{ toJson(secrets) }}
          VARIABLES_CONTEXT: ${{ toJson(vars) }}
```
