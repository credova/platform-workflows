# Development Guide

## Repository Structure

```text
platform-workflows/
├── .github/workflows/          # Reusable workflows (public interface)
│   ├── ci.yaml                 # Self-test: validate actions
│   ├── release.yaml            # Version + tag platform-workflows itself
│   ├── pull-request.yaml       # Unified PR validation
│   └── deploy.yaml             # Unified deploy (+ hotfix mode)
├── actions/                    # Composite actions (building blocks)
│   ├── auth-gcp/               # INTERNAL - WIF login + docker config
│   ├── auth-release-token/     # GitHub App token for private repo releases
│   ├── auth-npm-token/         # GitHub App token for npm publishing
│   ├── compliance/             # Process + policy gates
│   ├── container/              # Build, scan, push, tag, reuse, retag
│   ├── deployment/             # Cloud Run deploy via pctl
│   ├── increment-tag/          # Semver tag incrementor
│   ├── install-pctl/         # INTERNAL - pctl binary installer
│   ├── notification/           # Standalone Slack notifications
│   ├── secrets-setup/          # GCP Secret Manager via fnox
│   ├── security/               # Vulnerability + code scanning
│   └── setup-language/         # Multi-language runtime setup
├── scripts/                    # Helper scripts
│   ├── docker-utils.sh         # Docker helper functions
│   └── semver.sh               # Semver tag computation
└── docs/                       # Documentation
    ├── architecture.md         # Design principles + two-layer model
    ├── development.md          # This file
    ├── migration.md            # Migration from psq-ops-actions
    └── usage.md                # Consumption guide with examples
```

## Making Changes

1. Create a feature branch
2. Modify the composite action or reusable workflow
3. CI runs automatically to validate YAML syntax and structure
4. Get Platform team approval (required via CODEOWNERS)
5. Merge to main — release workflow creates a new tag

## Versioning

- Tags follow semantic versioning: `v1.0.0`, `v1.1.0`, etc.
- Major version tags (`v1`) are updated on each release for consumers using `@v1`
- Breaking changes require a major version bump

## Testing Changes

Test changes by pointing a consuming repo at your branch:

```yaml
uses: credova/platform-workflows/.github/workflows/pull-request.yaml@your-branch
```
