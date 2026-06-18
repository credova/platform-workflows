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
| `check-pr-shortcut-ticket`             | `actions/compliance@v1`                     | New: ticket check + policy gates    |
| N/A                                    | `actions/secrets-setup@v1`                  | New: fnox + GCP Secret Manager      |

## Migration Steps

1. Create `platform-workflows` repo via github-meta Pulumi.
2. Build composite actions (port + restructure from ops-actions).
3. Build reusable workflows that call composites.
4. Tag `v1.0.0`.
5. Migrate repos one at a time. Replace ops-actions references with platform-workflows.
6. Validate each migration.
7. Deprecate `ops-actions`: add deprecation notice, archive after migration complete.

---

## Migrating to Language-Specific Workflows

### Why migrate

The language-specific workflows (`go-pull-request.yaml`, `node-deploy.yaml`, etc.) are the recommended interface going forward. Benefits over the generic `pull-request.yaml` and `deploy.yaml`:

- **Opinionated structure**: lint, security, and test jobs are built in with per-language defaults.
- **Fail-fast ordering**: configurable run-order (linear, parallel, checks-first) so failures surface quickly.
- **mise integration**: if your repo has a `mise.toml` with `lint`, `security`, and/or `test` tasks, they are picked up automatically with no configuration.
- **Fewer inputs**: no need to specify `language` or `language-version`. The workflow already knows.

### How to migrate

Replace your generic `pull-request.yaml` + `deploy.yaml` calls with the language-specific pair. The inputs are similar but streamlined.

### Example: Node.js service

**Before** (generic):

```yaml
# .github/workflows/pull-request.yaml
name: Pull Request
on:
  pull_request:
    branches: [master]

jobs:
  ci:
    uses: credova/platform-workflows/.github/workflows/pull-request.yaml@master
    with:
      language: node
      language-version: "20"
      test-command: "npm ci && npm test"
```

```yaml
# .github/workflows/deploy.yaml
name: Deploy
on:
  push:
    branches: [master]

jobs:
  deploy:
    uses: credova/platform-workflows/.github/workflows/deploy.yaml@master
    with:
      language: node
      language-version: "20"
      config-path: deployments/
    secrets:
      RELEASE_DOWNLOADER_APP_ID: ${{ secrets.RELEASE_DOWNLOADER_APP_ID }}
      RELEASE_DOWNLOADER_APP_PRIVATE_KEY: ${{ secrets.RELEASE_DOWNLOADER_APP_PRIVATE_KEY }}
```

**After** (language-specific):

```yaml
# .github/workflows/pull-request.yaml
name: Pull Request
on:
  pull_request:
    branches: [master]

jobs:
  ci:
    uses: credova/platform-workflows/.github/workflows/node-pull-request.yaml@master
    secrets: inherit
```

```yaml
# .github/workflows/deploy.yaml
name: Deploy
on:
  push:
    branches: [master]

jobs:
  deploy:
    uses: credova/platform-workflows/.github/workflows/node-deploy.yaml@master
    secrets: inherit
    with:
      config-path: deployments/
```

No `language`, no `language-version`, no `test-command`. mise picks it up from `mise.toml`.

### Example: .NET service

**Before** (generic):

```yaml
# .github/workflows/pull-request.yaml
name: Pull Request
on:
  pull_request:
    branches: [master]

jobs:
  ci:
    uses: credova/platform-workflows/.github/workflows/pull-request.yaml@master
    with:
      language: dotnet
      language-version: "8.0"
```

```yaml
# .github/workflows/deploy.yaml
name: Deploy
on:
  push:
    branches: [master]

jobs:
  deploy:
    uses: credova/platform-workflows/.github/workflows/deploy.yaml@master
    with:
      language: dotnet
      language-version: "8.0"
      config-path: deployments/
    secrets:
      RELEASE_DOWNLOADER_APP_ID: ${{ secrets.RELEASE_DOWNLOADER_APP_ID }}
      RELEASE_DOWNLOADER_APP_PRIVATE_KEY: ${{ secrets.RELEASE_DOWNLOADER_APP_PRIVATE_KEY }}
```

**After** (language-specific):

```yaml
# .github/workflows/pull-request.yaml
name: Pull Request
on:
  pull_request:
    branches: [master]

jobs:
  ci:
    uses: credova/platform-workflows/.github/workflows/dotnet-pull-request.yaml@master
    secrets: inherit
```

```yaml
# .github/workflows/deploy.yaml
name: Deploy
on:
  push:
    branches: [master]

jobs:
  deploy:
    uses: credova/platform-workflows/.github/workflows/dotnet-deploy.yaml@master
    secrets: inherit
    with:
      config-path: deployments/
```

### Example: migrating directly from psq-ops-actions

If your repo still uses psq-ops-actions, skip the generic workflows and go straight to language-specific. Replace all ops-actions references with a single workflow call per file.

**Before** (psq-ops-actions):

```yaml
# .github/workflows/pull-request.yaml - typical ops-actions setup
name: Pull Request
on:
  pull_request:
    branches: [master]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7
      - uses: actions/setup-node@v6
        with:
          node-version: "20"
      - run: npm ci && npm test

  scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7
      - uses: psq-ops-actions/scanner@v11

  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7
      - uses: psq-ops-actions/tag-and-push-docker-image@v11
```

**After** (language-specific):

```yaml
# .github/workflows/pull-request.yaml
name: Pull Request
on:
  pull_request:
    branches: [master]

jobs:
  ci:
    uses: credova/platform-workflows/.github/workflows/node-pull-request.yaml@master
    secrets: inherit
```

The test, security scanning, and container build logic is handled by the workflow.

### mise integration

The language-specific workflows look for mise tasks automatically:

- **`mise run lint`**: runs if a `lint` task exists in `mise.toml`
- **`mise run security`**: runs if a `security` task exists in `mise.toml`
- **`mise run test`**: runs if a `test` task exists in `mise.toml`

If your repo has no `mise.toml` yet, or your tasks use different names, use the override inputs:

```yaml
jobs:
  ci:
    uses: credova/platform-workflows/.github/workflows/node-pull-request.yaml@master
    secrets: inherit
    with:
      lint-command: "npm run lint"
      test-command: "npm test"
```

### Release workflow

Repos that publish packages (npm, NuGet) using semantic-release or similar tools should migrate to `shared-release.yaml`. This replaces custom release jobs with a standardized workflow that supports edge and semantic release modes.

```yaml
# .github/workflows/release.yaml
name: Release
on:
  push:
    branches: [master]

jobs:
  release:
    uses: credova/platform-workflows/.github/workflows/shared-release.yaml@master
    secrets: inherit
    with:
      mode: semantic
      publish-npm: true
```
