# install-pctl

Install pctl from the private `credova/pctl` GitHub releases. Handles version resolution, architecture detection, and SHA256 checksum verification. If the caller workflow has checked out the pctl source (detected by a `go.mod` with `module github.com/credova/pctl`), it builds from that checkout instead, so unreleased fixes can run in CI.

> **Internal action.** Consumed by `deployment` and `notification`. Do not call directly.

## Inputs

| Input     | Required | Default  | Description                                              |
| --------- | -------- | -------- | -------------------------------------------------------- |
| `version` | No       | `latest` | pctl version to install                                  |
| `token`   | Yes      | -        | GitHub token with read access to `credova/pctl` releases |

Generate the token at the reusable workflow level (e.g. via `actions/create-github-app-token`) and pass it down to composites. This keeps GitHub App credentials in one place.

## What it does

1. Checks if pctl is already installed (skips if so) and whether local pctl source is present.
2. **From source** (local `credova/pctl` checkout): sets up Go from `go.mod` and `go build`s pctl into `/usr/local/bin/pctl`.
3. **From release** (default): resolves `latest` version via `gh release view`, detects OS (`Linux`/`Darwin`) and architecture (`x86_64`/`arm64`), downloads the matching `.tar.gz` archive, verifies the SHA256 checksum against `checksums.txt`, and installs to `/usr/local/bin/pctl`.
