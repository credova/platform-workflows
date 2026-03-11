# Usage Guide

Every consuming repo uses the same file names:

```bash
any-repo/
└── .github/workflows/
    ├── pull-request.yaml    # PR validation
    ├── deploy.yaml          # merge to main → staging → production
    └── deploy-tag.yaml      # tag push → straight to production (hotfix)
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
    branches: [main]

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

Merge to main → build → scan → push → staging → approval → production.

```yaml
# .github/workflows/deploy.yaml
name: Deploy
on:
  push:
    branches: [main]

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
# .github/workflows/deploy-tag.yaml
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

## Input Reference

### pull-request.yaml

| Input               | Type    | Default | Description                                                          |
| ------------------- | ------- | ------- | -------------------------------------------------------------------- |
| `language`          | string  | `""`    | Language runtime: `go`, `node`, `kotlin`, `python`, `ruby`, `dotnet` |
| `language-version`  | string  | `""`    | Runtime version (required if language is set)                        |
| `test-command`      | string  | `""`    | Custom test command (defaults per language)                          |
| `container`         | boolean | `true`  | Build and scan a container image                                     |
| `image`             | string  | `""`    | Single image `name:dockerfile`                                       |
| `images`            | string  | `""`    | Multi-image YAML list                                                |
| `security-packages` | boolean | `true`  | Package vulnerability scan                                           |
| `security-code`     | boolean | `true`  | Code static analysis                                                 |
| `security-severity` | string  | `HIGH`  | Minimum severity to fail on                                          |
| `compliance-ticket` | boolean | `true`  | Require ticket reference                                             |

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
