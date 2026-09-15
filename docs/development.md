# Development Guide

## Repository Structure

```text
platform-workflows/
├── .github/
│   ├── CODEOWNERS
│   └── dependabot.yml          # Monthly third-party action bumps (see Dependencies)
├── .github/workflows/          # Reusable workflows (public interface; selected below)
│   ├── ci.yaml                 # Self-test: validate actions
│   ├── release.yaml            # Version + tag platform-workflows itself
│   ├── shared-release.yaml     # Shared release (edge/semantic modes)
│   ├── pull-request.yaml       # Unified PR validation
│   ├── deploy.yaml             # Unified deploy (+ hotfix mode)
│   ├── iac-pull-request.yaml   # Pulumi/IaC PR: lint + reeve + compliance
│   ├── go.yaml, go-*.yaml      # Language-specific (also node/python/ruby/php/dotnet/kotlin)
│   └── dependabot-auto-merge.yaml
├── actions/                    # Composite actions (building blocks)
│   ├── auth-gcp/               # INTERNAL - WIF login + docker config
│   ├── auth-release-token/     # GitHub App token for private repo releases
│   ├── auth-npm-token/         # GitHub App token for npm publishing
│   ├── cloudflare-purge/       # Cloudflare cache purge (prefixes, files, tags)
│   ├── compliance/             # Shortcut ticket check + policy gates
│   ├── container/              # Build, scan, push, retag (standard + WarpBuild)
│   ├── deployment/             # Cloud Run deploy via pctl
│   ├── go-report/              # INTERNAL - post Go job results on a PR comment
│   ├── increment-tag/          # Semver tag incrementor
│   ├── install-pctl/           # INTERNAL - pctl binary installer
│   ├── notification/           # Slack notifications via pctl
│   ├── parse-images/           # INTERNAL - image inputs → JSON build matrix
│   ├── run-job/                # Deploy and execute a Cloud Run Job
│   ├── secrets-setup/          # GCP Secret Manager via fnox
│   ├── security/               # syft + grype + grant + opengrep scanning
│   ├── setup-language/         # Runtime setup + WarpBuild dep caching
│   └── setup-mise/             # mise install + WarpCache tool cache
├── scripts/                    # Shell scripts (called by actions)
│   ├── check-shortcut-ticket.sh  # Shortcut ticket pattern matching
│   ├── cloudflare-purge.sh       # Cloudflare cache purge API call
│   ├── deploy.sh                 # pctl deploy (deploy/promote/abort/set-weight/status/rollback)
│   ├── docker-build.sh           # Docker buildx build wrapper
│   ├── docker-push.sh            # Docker push + extra tags
│   ├── grant-scan.sh             # grant license compliance scan
│   ├── grype-scan.sh             # grype vulnerability scan
│   ├── install-anchore.sh        # syft/grype/grant installer
│   ├── install-opengrep.sh       # opengrep installer
│   ├── install-pctl.sh           # pctl download + SHA256 verify
│   ├── notify-slack.sh           # Slack notification via pctl
│   ├── opengrep-scan.sh          # OpenGrep static analysis
│   ├── parse-images.sh           # Image input → JSON matrix
│   ├── post-compliance-comment.sh  # Upsert compliance PR comment
│   ├── post-go-comment.sh        # Upsert Go lint/security/test PR comment
│   ├── post-security-comment.sh  # Upsert security scan PR comment
│   └── semver.sh                 # Semver tag computation
└── docs/                       # Documentation
    ├── README.md               # Doc index
    ├── architecture.md         # Design principles + two-layer model
    ├── development.md          # This file
    ├── migration.md            # Migration from psq-ops-actions
    └── usage.md                # Consumption guide with examples
```

## Making Changes

1. Create a feature branch.
2. Modify the composite action or reusable workflow.
3. CI runs automatically to validate YAML syntax and structure.
4. Get Platform team approval (required via CODEOWNERS).
5. Merge to master.

## Releasing

Releases are triggered manually via `workflow_dispatch`. Merging to master does not auto-release.

**GitHub UI:** Actions tab > Release > Run workflow > select bump type.

**CLI:**
```bash
gh workflow run release.yaml -R credova/platform-workflows -f bump=patch
gh workflow run release.yaml -R credova/platform-workflows -f bump=minor
gh workflow run release.yaml -R credova/platform-workflows -f bump=major
```

## Dependencies

Third-party actions (`actions/checkout`, `jdx/mise-action`, `docker/*`, `WarpBuilds/*`, and
so on) are kept current by Dependabot from `.github/dependabot.yml`. It runs monthly and opens
one grouped PR per surface (workflows, composite actions) for minor and patch updates, plus a
separate PR for each major. Majors change action inputs and outputs, so read them individually.

Nothing auto-merges. A merged bump reaches every consumer on `@master` at their next run, and
this repo's CI does not exercise the actions, so each PR gets a human review. Merged bumps to
composite actions need a patch release before consumers on `@v1` see them (see Releasing).

`reeveops/reeve` is excluded. It is pinned to an exact 0.x tag where every minor can break, so
bump it by hand with its own story.

## Versioning

- Tags follow semantic versioning: `v1.0.0`, `v1.1.0`, etc.
- Major version tags (`v1`) are updated on each release for consumers using `@v1`.
- Breaking changes require a major version bump. Consumers must opt in by updating to `@v2`.

## Testing Changes

Point a consuming repo at your branch:

```yaml
uses: credova/platform-workflows/.github/workflows/pull-request.yaml@your-branch
```
