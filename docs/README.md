# Documentation

- [Usage Guide](usage.md) - examples for every scenario (multi-image, canary, hotfix, opt-outs)
  - [WarpBuild](usage.md#warpbuild) - runners, Docker Builders, dependency caching
  - [Input Reference](usage.md#input-reference) - all workflow inputs at a glance
- [Architecture](architecture.md) - two-layer design, principles, pipeline ordering
- [Development](development.md) - repo structure, versioning, testing changes
- [Migration](migration.md) - mapping from psq-ops-actions to platform-workflows

## Language-Specific Workflows

| Language | Pull Request | Deploy |
| -------- | ------------ | ------ |
| Node.js | `node-pull-request.yaml` | `node-deploy.yaml` |
| .NET | `dotnet-pull-request.yaml` | `dotnet-deploy.yaml` |
| Go | `go-pull-request.yaml` | `go-deploy.yaml` |
| Kotlin | `kotlin-pull-request.yaml` | `kotlin-deploy.yaml` |
| PHP | `php-pull-request.yaml` | `php-deploy.yaml` |
| Python | `python-pull-request.yaml` | `python-deploy.yaml` |
| Ruby | `ruby-pull-request.yaml` | `ruby-deploy.yaml` |

## Shared Workflows

- **[shared-release.yaml](../../../.github/workflows/shared-release.yaml)** - reusable release workflow supporting edge/stable modes, npm publish, and version bumping
- **[dependabot-auto-merge.yaml](../../../.github/workflows/dependabot-auto-merge.yaml)** - auto-merge Dependabot PRs for patch/minor updates

## Actions

- **[terrateam](../actions/terrateam/)** - shared Terrateam action for Pulumi/Terraform repos (GCP auth, optional VPN, GitHub App token)
- **[run-job](../actions/run-job/)** - deploy and execute Cloud Run Jobs (migrations, memorystore patterns)

## Patterns

- [Playwright](patterns/playwright.md) - browser testing with Playwright
- [Cache Cleaner](patterns/cache-cleaner.md) - CDN/cache invalidation patterns
- [E2E Trigger](patterns/e2e-trigger.md) - triggering end-to-end test suites

## Examples

See [examples/](../examples/) for copy-paste starter workflows for every supported repo type.
