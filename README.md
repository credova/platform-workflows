# platform-workflows

Standardized CI/CD workflows and composite actions for Credova services. One PR workflow, one deploy workflow. Toggle features with flags.

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

Defaults:

- Security scanning, compliance checks, container build, and deployment are on by default.
- All workflows run on [WarpBuild](https://warpbuild.com) runners (`warp-ubuntu-2404-x64-2x`).

See the [usage guide](docs/usage.md) for customization.

## Workflows

### Generic

- **pull-request.yaml**: PR to master. security > test > build > compliance
- **deploy.yaml**: push to master. test > build > staging > production > release
- **deploy.yaml** (hotfix): tag push. build > [canary] > approve > production > release

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

- **go.yaml**: Go repos with mise + GoReleaser (lint, security, test, release)
- **iac-pull-request.yaml**: Pulumi/IaC repos (platform-iac, github-meta, product-iac). lint + reeve (preview/apply) + compliance
- **shared-release.yaml**: package publishing (npm, NuGet) with edge/semantic release modes
- **dependabot-auto-merge.yaml**: auto-merge Dependabot PRs

## Runners

- Default: `warp-ubuntu-2404-x64-2x` ([WarpBuild](https://warpbuild.com)).
- Override per workflow with the `runner` input.

Naming pattern:

```
warp-ubuntu-2404-<arch>-<size>
```

- `arch`: `x64` or `arm64`
- `size`: `2x`, `4x`, `8x`, `16x`, `32x`

| Size           | vCPU | RAM    |
| -------------- | ---- | ------ |
| `2x` (default) | 2    | 8 GB   |
| `4x`           | 4    | 16 GB  |
| `8x`           | 8    | 32 GB  |
| `16x`          | 16   | 64 GB  |
| `32x`          | 32   | 128 GB |

Override example:

```yaml
jobs:
  ci:
    uses: credova/platform-workflows/.github/workflows/pull-request.yaml@master
    with:
      runner: warp-ubuntu-2404-x64-8x
```

Confirm latest images: https://www.warpbuild.com/docs/ci/cloud-runners

## Key Features

- **WarpBuild runners** by default. Override with `runner` input.
- **WarpBuild Docker Builders** (opt-in): remote builds with native arm64 and built-in layer caching via `warpbuild-profile`.
- **WarpBuild dependency caching** (opt-in): `cache: true` enables `WarpBuilds/cache@v1` and auto-disables conflicting built-in caches.
- **Multi-image builds**: parallel matrix builds via `images` YAML list.
- **Cross-platform**: `platform` input for arm64 builds (QEMU or native via WarpBuild).
- **Shortcut ticket enforcement**: compliance checks PRs for `sc-NNNNN` references.

## Actions

| Action                                    | Description                                                          |
| ----------------------------------------- | -------------------------------------------------------------------- |
| [compliance](actions/compliance/)         | Shortcut ticket reference check, automated PR skip                   |
| [container](actions/container/)           | Build, scan, push, retag. Full container lifecycle                   |
| [deployment](actions/deployment/)         | Cloud Run deploy via pctl (deploy, promote, rollback)                |
| [increment-tag](actions/increment-tag/)   | Semantic version tag incrementor                                     |
| [notification](actions/notification/)     | Slack notifications via pctl                                         |
| [secrets-setup](actions/secrets-setup/)   | GCP Secret Manager loading via mise + fnox                           |
| [security](actions/security/)             | Syft + Grype vuln scan, Grant license scan, OpenGrep static analysis |
| [run-job](actions/run-job/)               | Deploy and execute a Cloud Run Job                                   |
| [setup-language](actions/setup-language/) | Multi-language runtime setup (Go, Node, Kotlin, Python, Ruby, .NET)  |

Internal actions (called by workflows, not directly by teams):

| Action                                            | Description                                                     |
| ------------------------------------------------- | --------------------------------------------------------------- |
| [auth-gcp](actions/auth-gcp/)                     | Workload Identity Federation login                              |
| [auth-npm-token](actions/auth-npm-token/)         | GitHub App token for npm publishing                             |
| [auth-release-token](actions/auth-release-token/) | GitHub App token for private repo releases                      |
| [go-report](actions/go-report/)                   | Post/update Go job results (lint/security/test) on a PR comment |
| [install-pctl](actions/install-pctl/)             | pctl binary installer with checksum verification                |
| [parse-images](actions/parse-images/)             | Parse `image`/`images` inputs into a JSON build matrix          |

## Releases

### How to pin

Pin to a **major version tag** for standard usage. You receive every fix and feature added within that major automatically:

```yaml
uses: credova/platform-workflows/.github/workflows/pull-request.yaml@v1
```

| Tag                 | When to use                                                           |
| ------------------- | --------------------------------------------------------------------- |
| `@v1`               | **Standard.** Floating major. Gets all `v1.x.x` updates automatically |
| `@v1.2` / `@v1.2.3` | Troubleshooting only. Temporarily freeze to isolate a regression      |
| `@master`           | Troubleshooting only. Unreleased tip, may be unstable                 |

Pinning below the major (`@v1.2`, an exact patch, or `@master`) is for debugging: to bisect a bad release or test an unmerged fix. For normal use stay on `@$MAJOR` so updates and hotfixes propagate without manual bumps.

### What each bump means

| Bump      | Use for                                                                                                                                                     |
| --------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **major** | Breaking changes to existing actions/workflows: removed inputs, changed behavior, anything a consumer must react to. Consumers opt in by updating to `@v2`. |
| **minor** | Additions only: new actions, workflows, or inputs. No removals, no breakage. New behavior is opt-in or ships with reasonable defaults plus clear overrides. |
| **patch** | Hotfixes, small documentation changes, and other non-functional tweaks.                                                                                     |

A consumer on `@v1` is always safe to receive any `minor` or `patch` release without changes. Only a `major` requires action on their part.

### How to cut a release

Push a tag directly:

```bash
git tag v1.2.3 && git push origin v1.2.3
```

Or trigger via dispatch to auto-increment:

```bash
gh workflow run release.yaml -R credova/platform-workflows -f bump=patch   # v1.0.1
gh workflow run release.yaml -R credova/platform-workflows -f bump=minor   # v1.1.0
gh workflow run release.yaml -R credova/platform-workflows -f bump=major   # v2.0.0
```

## Docs

- [Usage Guide](docs/usage.md): examples for every scenario (multi-image, canary, hotfix, opt-outs)
- [Architecture](docs/architecture.md): two-layer design, principles, pipeline ordering
- [Development](docs/development.md): how to make changes, versioning, testing
- [Migration](docs/migration.md): mapping from psq-ops-actions to platform-workflows
