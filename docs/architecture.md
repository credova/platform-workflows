# Architecture

## Two Layers

- **Reusable workflows** (public interface): the standardized pipelines teams import. Define pipeline shape, ordering, and gating.
- **Composite actions** (internal building blocks): atomic modules that each handle one concern. Reusable workflows call these internally.

```text
reusable workflow (deploy.yaml)
  └── calls composite: setup-language (runtime setup)
  └── calls composite: container (build + scan + push)
  └── calls composite: deployment (Cloud Run via pctl)
  └── calls composite: increment-tag (semver release)
```

## Design Principles

- **Fail early, fail fast**: security and compliance checks run first.
- **Opt-out, not opt-in**: security scanning and compliance gates are on by default.
- **On rails**: defaults handle conflicts automatically. Enabling WarpBuild cache auto-disables built-in Go/Node caches.
- **Feature flags, not separate workflows**: one `pull-request.yaml`, one `deploy.yaml` with boolean toggles (`container`, `deploy`, `hotfix`, `cache`).
- **Self-contained modules**: each composite handles its own auth, dependencies, and setup.
- **One interface, hidden internals**: swap grype for something else by updating one composite.
- **Zero PATs**: all auth uses GitHub Apps, GITHUB_TOKEN, or OIDC (Workload Identity Federation).
- **WarpBuild-first**: all workflows default to WarpBuild runners, with opt-in Docker Builders and dependency caching.

## Workflows

| Workflow               | Trigger                      | Purpose                                           |
| ---------------------- | ---------------------------- | ------------------------------------------------- |
| `pull-request.yaml`    | PR to master                 | Security > test > build > compliance              |
| `deploy.yaml`          | Push to master               | Test > build > staging > production > release     |
| `deploy.yaml` (hotfix) | Tag push with `hotfix: true` | Build > [canary] > approve > production > release |

## Pipeline Ordering

- PR workflows: `security → test (optional) → build (optional) → compliance`
- Deploy workflows: `test → build → scan → push → staging → [canary] → production → release`
- Hotfix workflows: `build → scan → push → [canary] → approve → production → release`
