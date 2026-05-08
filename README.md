# platform-workflows

Standardized CI/CD workflows and composite actions for all Credova services. One PR workflow, one deploy workflow - toggle what you need with flags.

## Quick Start

### PR validation

```yaml
# .github/workflows/pull-request.yaml
name: Pull Request
on:
  pull_request:
    branches: [master]

jobs:
  ci:
    uses: credova/platform-workflows/.github/workflows/pull-request.yaml@master
```

### Deploy

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
      config-path: deployments/
    secrets:
      RELEASE_DOWNLOADER_APP_ID: ${{ secrets.RELEASE_DOWNLOADER_APP_ID }}
      RELEASE_DOWNLOADER_APP_PRIVATE_KEY: ${{ secrets.RELEASE_DOWNLOADER_APP_PRIVATE_KEY }}
```

That's it. Security scanning, compliance checks, container build, and deployment are all on by default. All workflows run on [WarpBuild](https://warpbuild.com) runners (`warp-ubuntu-2204-x64-2x`) by default. See [usage guide](docs/usage.md) for customization.

## Workflows

### Generic

- **pull-request.yaml** - PR to master: security > test > build > compliance
- **deploy.yaml** - push to master: test > build > staging > production > release
- **deploy.yaml** (hotfix) - tag push: build > [canary] > approve > production > release

### Language-specific

| Workflow | PR                         | Deploy               |
| -------- | -------------------------- | -------------------- |
| Go       | `go-pull-request.yaml`     | `go-deploy.yaml`     |
| Node.js  | `node-pull-request.yaml`   | `node-deploy.yaml`   |
| Kotlin   | `kotlin-pull-request.yaml` | `kotlin-deploy.yaml` |
| Python   | `python-pull-request.yaml` | `python-deploy.yaml` |
| Ruby     | `ruby-pull-request.yaml`   | `ruby-deploy.yaml`   |
| .NET     | `dotnet-pull-request.yaml` | `dotnet-deploy.yaml` |
| PHP      | `php-pull-request.yaml`    | `php-deploy.yaml`    |

### Other

- **go.yaml** - Go repos with mise + GoReleaser (lint, security, test, release)
- **shared-release.yaml** - package publishing (npm, NuGet) with edge/semantic release modes
- **dependabot-auto-merge.yaml** - auto-merge Dependabot PRs

## Key Features

- **WarpBuild runners** by default - override with `runner` input
- **WarpBuild Docker Builders** (opt-in) - remote builds with native arm64 and built-in layer caching via `warpbuild-profile`
- **WarpBuild dependency caching** (opt-in) - `cache: true` enables `WarpBuilds/cache@v1` and auto-disables conflicting built-in caches
- **Multi-image builds** - parallel matrix builds via `images` YAML list
- **Cross-platform** - `platform` input for arm64 builds (QEMU or native via WarpBuild)
- **Shortcut ticket enforcement** - compliance checks PRs for `sc-NNNNN` references

## Actions

| Action                                    | Description                                                          |
| ----------------------------------------- | -------------------------------------------------------------------- |
| [compliance](actions/compliance/)         | Shortcut ticket reference check, automated PR skip                   |
| [container](actions/container/)           | Build, scan, push, retag - full container lifecycle                  |
| [deployment](actions/deployment/)         | Cloud Run deploy via pctl (deploy, promote, rollback)                |
| [increment-tag](actions/increment-tag/)   | Semantic version tag incrementor                                     |
| [notification](actions/notification/)     | Slack notifications via pctl                                         |
| [secrets-setup](actions/secrets-setup/)   | GCP Secret Manager loading via mise + fnox                           |
| [security](actions/security/)             | Syft + Grype vuln scan, Grant license scan, OpenGrep static analysis |
| [run-job](actions/run-job/)               | Deploy and execute a Cloud Run Job                                   |
| [setup-language](actions/setup-language/) | Multi-language runtime setup (Go, Node, Kotlin, Python, Ruby, .NET)  |
| [terrateam](actions/terrateam/)           | Terrateam composite for Pulumi/Terraform repos                       |

Internal actions (called by workflows, not directly by teams):

| Action                                            | Description                                      |
| ------------------------------------------------- | ------------------------------------------------ |
| [auth-gcp](actions/auth-gcp/)                     | Workload Identity Federation login               |
| [auth-npm-token](actions/auth-npm-token/)         | GitHub App token for npm publishing              |
| [auth-release-token](actions/auth-release-token/) | GitHub App token for private repo releases       |
| [install-pctl](actions/install-pctl/)             | pctl binary installer with checksum verification |

## Docs

- [Usage Guide](docs/usage.md) - examples for every scenario (multi-image, canary, hotfix, opt-outs)
- [Architecture](docs/architecture.md) - two-layer design, principles, pipeline ordering
- [Development](docs/development.md) - how to make changes, versioning, testing
- [Migration](docs/migration.md) - mapping from psq-ops-actions to platform-workflows
