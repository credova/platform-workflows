# install-pctl

> **Internal action** — consumed by `deployment` and `notification`. Teams should not call this directly.

Installs pctl from the private `credova/pctl` GitHub releases. Handles version resolution, architecture detection, and SHA256 checksum verification.

## Inputs

| Input     | Required | Default  | Description                                              |
| --------- | -------- | -------- | -------------------------------------------------------- |
| `version` | No       | `latest` | pctl version to install                                  |
| `token`   | Yes      | —        | GitHub token with read access to `credova/pctl` releases |

The token should be generated at the reusable workflow level (e.g. via `actions/create-github-app-token`) and passed down to composites. This keeps GitHub App credentials in one place.

## What it does

1. Checks if pctl is already installed (skips if so)
2. Resolves `latest` version via `gh release view`
3. Detects OS (`Linux`/`Darwin`) and architecture (`x86_64`/`arm64`)
4. Downloads the correct `.tar.gz` archive
5. Verifies SHA256 checksum against `checksums.txt`
6. Installs to `/usr/local/bin/pctl`
