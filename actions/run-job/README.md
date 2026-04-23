# run-job

Deploy and execute a Cloud Run Job. Handles the common pattern of deploying a container as a Cloud Run Job via pctl, then triggering it with `gcloud run jobs execute`. Replaces the standalone db-migrate and memorystore patterns.

## Inputs

| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| `target` | yes | | pctl deploy target (e.g., `gcp-staging`) |
| `config-path` | yes | | Path to CUE/pctl config for the job (e.g., `deployments/migrations.yaml`) |
| `tag` | no | `""` | Image tag to deploy |
| `job-name` | yes | | Cloud Run Job name to execute (e.g., `fp-migrations-staging`) |
| `project` | yes | | GCP project ID for job execution |
| `region` | no | `us-east4` | GCP region |
| `wait` | no | `"true"` | Wait for job completion |
| `project-id` | yes | | GCP project ID for auth |
| `workload-identity-provider` | yes | | Workload Identity Provider resource name |
| `service-account` | no | `""` | Service account email |
| `token` | yes | | GitHub token for pctl download |

## How it works

1. Deploys the job container using the `deployment` action (pctl)
2. Authenticates to GCP via Workload Identity
3. Executes the Cloud Run Job with `gcloud run jobs execute`
4. Optionally waits for the job to complete (default: yes)

## Usage: Database migrations

```yaml
- uses: credova/platform-workflows/actions/run-job@master
  with:
    target: gcp-staging
    config-path: deployments/migrations.yaml
    tag: ${{ needs.build.outputs.tag }}
    job-name: fp-migrations-staging
    project: fxt-app-stg
    project-id: fxt-app-stg
    workload-identity-provider: projects/123456/locations/global/workloadIdentityPools/github-actions/providers/github
    service-account: deploy-sa@fxt-app-stg.iam.gserviceaccount.com
    token: ${{ secrets.GITHUB_TOKEN }}
```

## Usage: Memorystore cache operations

```yaml
- uses: credova/platform-workflows/actions/run-job@master
  with:
    target: gcp-staging
    config-path: deployments/cache-seed.yaml
    tag: ${{ needs.build.outputs.tag }}
    job-name: cache-seed-staging
    project: fxt-app-stg
    region: us-east4
    project-id: fxt-app-stg
    workload-identity-provider: projects/123456/locations/global/workloadIdentityPools/github-actions/providers/github
    service-account: deploy-sa@fxt-app-stg.iam.gserviceaccount.com
    token: ${{ secrets.GITHUB_TOKEN }}
```

## Usage: Fire-and-forget (no wait)

```yaml
- uses: credova/platform-workflows/actions/run-job@master
  with:
    target: gcp-production
    config-path: deployments/async-task.yaml
    job-name: async-task-production
    project: fxt-app-prd
    wait: "false"
    project-id: fxt-app-prd
    workload-identity-provider: projects/123456/locations/global/workloadIdentityPools/github-actions/providers/github
    service-account: deploy-sa@fxt-app-prd.iam.gserviceaccount.com
    token: ${{ secrets.GITHUB_TOKEN }}
```
