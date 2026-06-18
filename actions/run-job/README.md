# run-job

Deploy and execute a Cloud Run Job. Deploys a container as a Cloud Run Job via pctl, then triggers it with `gcloud run jobs execute`. Replaces the standalone db-migrate and memorystore patterns.

## Inputs

| Input                        | Required | Default    | Description                                                              |
| ---------------------------- | -------- | ---------- | ------------------------------------------------------------------------ |
| `target`                     | yes      |            | pctl deploy target (e.g. `gcp-staging`)                                  |
| `config-path`                | yes      |            | Path to CUE/pctl config for the job (e.g. `deployments/migrations.yaml`) |
| `tag`                        | no       | `""`       | Image tag to deploy                                                      |
| `job-name`                   | yes      |            | Cloud Run Job name to execute (e.g. `fp-migrations-staging`)             |
| `project`                    | yes      |            | GCP project ID for job execution                                         |
| `region`                     | no       | `us-east4` | GCP region                                                               |
| `wait`                       | no       | `"true"`   | Wait for job completion                                                  |
| `project-id`                 | yes      |            | GCP project ID for auth                                                  |
| `workload-identity-provider` | yes      |            | Workload Identity Provider resource name                                 |
| `service-account`            | no       | `""`       | Service account email                                                    |
| `token`                      | yes      |            | GitHub token for pctl download                                           |

## How it works

1. Deploys the job container using the `deployment` action (pctl).
2. Authenticates to GCP via Workload Identity.
3. Executes the Cloud Run Job with `gcloud run jobs execute`.
4. Waits for the job to complete when `wait` is `true` (default).

## Examples

### Database migrations

```yaml
- uses: credova/platform-workflows/actions/run-job@master
  with:
    target: gcp-staging
    config-path: deployments/migrations.yaml
    tag: ${{ needs.build.outputs.tag }}
    job-name: fp-migrations-staging
    project: <gcp-project-id>
    project-id: <gcp-project-id>
    workload-identity-provider: projects/<project-number>/locations/global/workloadIdentityPools/<pool-name>/providers/<provider-name>
    service-account: <service-account>@<gcp-project-id>.iam.gserviceaccount.com
    token: ${{ secrets.GITHUB_TOKEN }}
```

### Memorystore cache operations

```yaml
- uses: credova/platform-workflows/actions/run-job@master
  with:
    target: gcp-staging
    config-path: deployments/cache-seed.yaml
    tag: ${{ needs.build.outputs.tag }}
    job-name: cache-seed-staging
    project: <gcp-project-id>
    region: us-east4
    project-id: <gcp-project-id>
    workload-identity-provider: projects/<project-number>/locations/global/workloadIdentityPools/<pool-name>/providers/<provider-name>
    service-account: <service-account>@<gcp-project-id>.iam.gserviceaccount.com
    token: ${{ secrets.GITHUB_TOKEN }}
```

### Fire-and-forget (no wait)

```yaml
- uses: credova/platform-workflows/actions/run-job@master
  with:
    target: gcp-production
    config-path: deployments/async-task.yaml
    job-name: async-task-production
    project: <gcp-project-id>
    wait: "false"
    project-id: <gcp-project-id>
    workload-identity-provider: projects/<project-number>/locations/global/workloadIdentityPools/<pool-name>/providers/<provider-name>
    service-account: <service-account>@<gcp-project-id>.iam.gserviceaccount.com
    token: ${{ secrets.GITHUB_TOKEN }}
```
