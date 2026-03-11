# Migration from psq-ops-actions

## Action Mapping

| Old (`psq-ops-actions`)                | New (`platform-workflows`)                  | Notes                               |
| -------------------------------------- | ------------------------------------------- | ----------------------------------- |
| `deployer@v1.0`                        | `actions/deployment@v1`                     | Now wraps pctl, auth baked in       |
| `scanner@v11`                          | `actions/security@v1`                       | Expanded: packages, code, container |
| `maybe-reuse-docker-image@v11`         | `actions/container@v1` (with `reuse: true`) | Merged into container module        |
| `tag-and-push-docker-image@v11`        | `actions/container@v1` (with `push: true`)  | Merged into container module        |
| `increment-tag@v11`                    | `actions/increment-tag@v1`                  | Same concept, clean interface       |
| `slack-deployment-notification@master` | `actions/notification@v1`                   | Also available via pctl             |
| `configure-gcp-docker@v1`              | `actions/auth-gcp@v1` (internal)            | Now internal, auto-called           |
| `check-pr-shortcut-ticket`             | `actions/compliance@v1`                     | New — ticket check + policy gates   |
| N/A                                    | `actions/secrets-setup@v1`                  | New — fnox + GCP Secret Manager     |

## Migration Steps

1. Create `platform-workflows` repo via github-meta Pulumi
2. Build composite actions (port + restructure from ops-actions)
3. Build reusable workflows that call composites
4. Tag `v1.0.0`
5. Migrate repos one at a time — replace ops-actions references with platform-workflows
6. Validate each migration thoroughly
7. Deprecate `ops-actions` — add deprecation notice, archive after migration complete
