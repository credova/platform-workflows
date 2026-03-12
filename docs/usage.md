# Usage Guide

Every consuming repo uses the same file names:

```bash
any-repo/
└── .github/workflows/
    ├── pull-request.yaml    # PR validation
    ├── deploy.yaml          # merge to master → staging → production
    └── deploy-hotfix.yaml   # tag push → straight to production (hotfix)
```

---

## Pull Request Workflow

One workflow handles everything. Toggle what you need with flags.

### Service (container build — the default)

The simplest case. Builds a Dockerfile, scans it, runs compliance checks. No language setup needed — the Dockerfile handles everything.

```yaml
# .github/workflows/pull-request.yaml
name: Pull Request
on:
  pull_request:
    branches: [master]

jobs:
  ci:
    uses: credova/platform-workflows/.github/workflows/pull-request.yaml@v1
```

### Service with explicit image

```yaml
jobs:
  ci:
    uses: credova/platform-workflows/.github/workflows/pull-request.yaml@v1
    with:
      image: api:src/Dockerfile
```

### Service with multiple images (monorepo)

```yaml
jobs:
  ci:
    uses: credova/platform-workflows/.github/workflows/pull-request.yaml@v1
    with:
      images: |
        - name: api
          dockerfile: ./Dockerfile
        - name: worker
          dockerfile: ./cmd/worker/Dockerfile
```

### Service with tests outside the Dockerfile

Some repos need to run language-specific tests in CI in addition to the container build.

```yaml
jobs:
  ci:
    uses: credova/platform-workflows/.github/workflows/pull-request.yaml@v1
    with:
      language: go
      language-version: "1.24"
```

### Non-container repo (CLI, library, scheduled job)

Disable the container build. Language setup and tests run instead.

```yaml
jobs:
  ci:
    uses: credova/platform-workflows/.github/workflows/pull-request.yaml@v1
    with:
      language: go
      language-version: "1.24"
      container: false
```

### Custom test command

Override the default test command for your language.

```yaml
jobs:
  ci:
    uses: credova/platform-workflows/.github/workflows/pull-request.yaml@v1
    with:
      language: go
      language-version: "1.24"
      container: false
      test-command: "make test-integration"
```

### Supported languages

| Language | `language` value | Version example | Default test command                      |
| -------- | ---------------- | --------------- | ----------------------------------------- |
| Go       | `go`             | `1.24`          | `go test ./...`                           |
| Node.js  | `node`           | `20`            | `npm ci && npm test`                      |
| Kotlin   | `kotlin`         | `21`            | `./gradlew test`                          |
| Python   | `python`         | `3.12`          | `pip install -e ".[test]" && pytest`      |
| Ruby     | `ruby`           | `3.3`           | `bundle install && bundle exec rake test` |
| .NET     | `dotnet`         | `8.0`           | `dotnet test`                             |

---

## Deploy Workflow

One workflow handles everything. Same flags as pull-request plus deployment options.

### Standard service deploy

Merge to master → build → scan → push → staging → approval → production.

```yaml
# .github/workflows/deploy.yaml
name: Deploy
on:
  push:
    branches: [master]

jobs:
  deploy:
    uses: credova/platform-workflows/.github/workflows/deploy.yaml@v1
    with:
      config-path: deployments/
    secrets:
      RELEASE_APP_ID: ${{ secrets.RELEASE_APP_ID }}
      RELEASE_APP_PRIVATE_KEY: ${{ secrets.RELEASE_APP_PRIVATE_KEY }}
```

### Service with canary

```yaml
jobs:
  deploy:
    uses: credova/platform-workflows/.github/workflows/deploy.yaml@v1
    with:
      config-path: deployments/
      canary: 30
    secrets:
      RELEASE_APP_ID: ${{ secrets.RELEASE_APP_ID }}
      RELEASE_APP_PRIVATE_KEY: ${{ secrets.RELEASE_APP_PRIVATE_KEY }}
```

### Non-container repo (release only — no deploy)

Runs tests, creates a tag and GitHub Release. No container, no Cloud Run.

```yaml
jobs:
  deploy:
    uses: credova/platform-workflows/.github/workflows/deploy.yaml@v1
    with:
      language: go
      language-version: "1.24"
      container: false
      deploy: false
```

### Non-container repo that deploys (e.g. pctl as a scheduled Cloud Run job)

Runs tests, builds container, deploys to Cloud Run.

```yaml
jobs:
  deploy:
    uses: credova/platform-workflows/.github/workflows/deploy.yaml@v1
    with:
      language: go
      language-version: "1.24"
      config-path: deployments/
    secrets:
      RELEASE_APP_ID: ${{ secrets.RELEASE_APP_ID }}
      RELEASE_APP_PRIVATE_KEY: ${{ secrets.RELEASE_APP_PRIVATE_KEY }}
```

### Multi-image monorepo

```yaml
jobs:
  deploy:
    uses: credova/platform-workflows/.github/workflows/deploy.yaml@v1
    with:
      config-path: deployments/
      images: |
        - name: merchant-portal
          dockerfile: apps/merchant-portal/Dockerfile
          canary: 30
        - name: admin-portal
          dockerfile: apps/admin-portal/Dockerfile
    secrets:
      RELEASE_APP_ID: ${{ secrets.RELEASE_APP_ID }}
      RELEASE_APP_PRIVATE_KEY: ${{ secrets.RELEASE_APP_PRIVATE_KEY }}
```

---

## Hotfix Deploy

Same `deploy.yaml` with `hotfix: true`. Skips tests and staging — goes straight to build → [canary] → approve → production. Canary still works if `canary > 0`.

```yaml
# .github/workflows/deploy-hotfix.yaml
name: Deploy Hotfix
on:
  push:
    tags: ["v*"]

jobs:
  hotfix:
    uses: credova/platform-workflows/.github/workflows/deploy.yaml@v1
    with:
      config-path: deployments/
      hotfix: true
    secrets:
      RELEASE_APP_ID: ${{ secrets.RELEASE_APP_ID }}
      RELEASE_APP_PRIVATE_KEY: ${{ secrets.RELEASE_APP_PRIVATE_KEY }}
```

---

## Opting Out of Defaults

Security scanning and compliance checks are on by default. Opt out explicitly — visible in the workflow file, reviewable in PRs.

```yaml
jobs:
  ci:
    uses: credova/platform-workflows/.github/workflows/pull-request.yaml@v1
    with:
      security-code: false       # Skip static analysis
      compliance-ticket: false   # Skip ticket reference check
```

### What you cannot disable

- **Container scanning after build** — if you build and push, it gets scanned
- **Auth via WIF** — no PATs, no service account keys

---

## WarpBuild

All workflows run on [WarpBuild](https://warpbuild.com) runners by default (`warp-ubuntu-2204-x64-2x`). WarpBuild also provides remote Docker Builders for faster container builds with built-in layer caching.

### Prerequisites

1. **WarpBuild runners** must be configured in your GitHub organization. All workflows default to `warp-ubuntu-2204-x64-2x`. Override with the `runner` input if needed.
2. **WarpBuild Docker Builder** (optional) — to use remote Docker builds, you must first create a Docker Builder profile in the [WarpBuild dashboard](https://app.warpbuild.com). The profile name is passed via the `warpbuild-profile` input.
3. **`WARPBUILD_API_KEY` secret** (optional) — only required if running on non-WarpBuild runners. Not needed when using WarpBuild runners.

### Using WarpBuild Docker Builders

Pass your Docker Builder profile name to enable remote builds:

```yaml
jobs:
  ci:
    uses: credova/platform-workflows/.github/workflows/pull-request.yaml@v1
    with:
      warpbuild-profile: my-docker-builder
```

Benefits over standard buildx:

- **Built-in layer caching** — no `cache-to`/`cache-from` configuration needed
- **Native arm64 support** — no QEMU emulation, builds run on real hardware
- **Faster builds** — dedicated remote build infrastructure

### Overriding the runner

To use a different runner (e.g. for repos not yet on WarpBuild):

```yaml
jobs:
  ci:
    uses: credova/platform-workflows/.github/workflows/pull-request.yaml@v1
    with:
      runner: ubuntu-latest
```

### Available WarpBuild runners

| Runner | vCPU | RAM | Arch |
| ------ | ---- | --- | ---- |
| `warp-ubuntu-2204-x64-2x` | 2 | 8 GB | x64 |
| `warp-ubuntu-2204-x64-4x` | 4 | 16 GB | x64 |
| `warp-ubuntu-2204-x64-8x` | 8 | 32 GB | x64 |
| `warp-ubuntu-2204-arm64-2x` | 2 | 8 GB | arm64 |
| `warp-ubuntu-2204-arm64-4x` | 4 | 16 GB | arm64 |
| `warp-ubuntu-2204-arm64-8x` | 8 | 32 GB | arm64 |
| `warp-ubuntu-2404-x64-2x` | 2 | 8 GB | x64 |
| `warp-ubuntu-2404-x64-4x` | 4 | 16 GB | x64 |
| `warp-ubuntu-2404-x64-8x` | 8 | 32 GB | x64 |
| `warp-ubuntu-2404-arm64-2x` | 2 | 8 GB | arm64 |
| `warp-ubuntu-2404-arm64-4x` | 4 | 16 GB | arm64 |
| `warp-ubuntu-2404-arm64-8x` | 8 | 32 GB | arm64 |

Default: `warp-ubuntu-2204-x64-2x`. Use 4x/8x for resource-intensive builds only.

### Dependency caching (WarpCache)

Enable `WarpBuilds/cache@v1` for dependency caching. This is a drop-in replacement for `actions/cache` with unlimited storage and better performance on WarpBuild runners.

```yaml
jobs:
  ci:
    uses: credova/platform-workflows/.github/workflows/pull-request.yaml@v1
    with:
      language: go
      language-version: "1.24"
      cache: true
```

Cached paths per language:

| Language | Cache path          | Key based on                              |
| -------- | ------------------- | ----------------------------------------- |
| Go       | `~/go/pkg/mod`      | `go.sum`                                  |
| Node.js  | `~/.npm`            | `package-lock.json`, `yarn.lock`          |
| Kotlin   | `~/.gradle/caches`  | `*.gradle*`, `gradle-wrapper.properties`  |
| Python   | `~/.cache/pip`      | `requirements*.txt`, `pyproject.toml`     |
| Ruby     | `vendor/bundle`     | `Gemfile.lock`                            |
| .NET     | `~/.nuget/packages` | `*.csproj`, `packages.lock.json`          |

When `cache: true`, built-in caches from `actions/setup-go` and `actions/setup-node` are automatically disabled to avoid double-caching.

---

## Input Reference

### pull-request.yaml

| Input               | Type    | Default                    | Description                          |
| ------------------- | ------- | -------------------------- | ------------------------------------ |
| `language`          | string  | `""`                       | Language runtime (see table above)   |
| `language-version`  | string  | `""`                       | Runtime version (required w/ lang)   |
| `test-command`      | string  | `""`                       | Custom test command                  |
| `container`         | boolean | `true`                     | Build and scan a container image     |
| `image`             | string  | `""`                       | Single image `name:dockerfile`       |
| `images`            | string  | `""`                       | Multi-image YAML list                |
| `platform`          | string  | `linux/amd64`              | Target platform for builds           |
| `warpbuild-profile` | string  | `""`                       | WarpBuild Docker Builder profile     |
| `cache`             | boolean | `false`                    | WarpBuild dependency caching         |
| `runner`            | string  | see WarpBuild section      | GitHub Actions runner label          |
| `security-packages` | boolean | `true`                     | Package vulnerability scan           |
| `security-code`     | boolean | `true`                     | Code static analysis                 |
| `security-severity` | string  | `HIGH`                     | Minimum severity to fail on          |
| `compliance-ticket` | boolean | `true`                     | Require ticket reference             |

### deploy.yaml

All inputs from pull-request.yaml plus:

| Input                        | Type    | Default        | Description                                                       |
| ---------------------------- | ------- | -------------- | ----------------------------------------------------------------- |
| `deploy`                     | boolean | `true`         | Deploy to Cloud Run via pctl                                      |
| `config-path`                | string  | `deployments/` | Path to CUE config directory                                      |
| `canary`                     | number  | `0`            | Canary traffic percentage                                         |
| `require-approval`           | boolean | `true`         | Require manual approval for production                            |
| `container-reuse`            | boolean | `true`         | Skip build if image exists for this SHA                           |
| `hotfix`                     | boolean | `false`        | Hotfix mode: skip tests, staging, canary — straight to production |
| `notifications`              | boolean | `true`         | Send Slack notifications                                          |
| `project-id`                 | string  | `""`           | GCP project ID                                                    |
| `workload-identity-provider` | string  | `""`           | WIF provider resource name                                        |

**Secrets** (both workflows): `WARPBUILD_API_KEY` (optional — only needed on non-WarpBuild runners).
Deploy also requires: `RELEASE_APP_ID`, `RELEASE_APP_PRIVATE_KEY`.

---

## Pipeline Flow

### PR: `security → test (optional) → build (optional) → compliance`

```bash
pull-request.yaml
├── validate-inputs
├── security          (trivy + opengrep)
├── test              (only if language is set)
├── build             (only if container: true)
│   └── container scan (mandatory)
└── compliance        (ticket check)
```

### Deploy: `test → build → staging → [canary] → production → release`

```bash
deploy.yaml
├── validate-inputs
├── auth              (GitHub App token for pctl)
├── test              (only if language is set)
├── build-scan-push   (only if container: true)
├── deploy-staging    (only if deploy: true)
├── approve-canary    (only if canary > 0)
├── deploy-canary     (only if canary > 0)
├── approve-production
├── deploy-production
├── release           (tag + GitHub Release)
└── cancel-superseded (clean up older waiting runs)
```

### Hotfix: `build → [canary] → approve → production → release`

```text
deploy.yaml (hotfix: true)
├── validate-inputs   (uses tag name instead of SHA)
├── auth              (GitHub App token for pctl)
├── build-scan-push   (always rebuilds, no reuse)
├── approve-canary    (only if canary > 0)
├── deploy-canary     (only if canary > 0)
├── approve-production
├── deploy-production (skips staging, not canary)
└── release           (from the tag that triggered)
```
