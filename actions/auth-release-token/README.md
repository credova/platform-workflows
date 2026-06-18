# auth-release-token

Generate a short-lived GitHub token scoped to specific repositories for release download access. Wraps `actions/create-github-app-token` with the org's release download GitHub App.

> **Internal action.** Used by reusable workflows to generate tokens for downloading releases from private repos.

## Inputs

| Input          | Required | Default | Description                                                                   |
| -------------- | -------- | ------- | ----------------------------------------------------------------------------- |
| `client-id`    | Yes      | -       | GitHub App client ID (from org secret `RELEASE_DOWNLOADER_APP_ID`)            |
| `private-key`  | Yes      | -       | GitHub App private key (from org secret `RELEASE_DOWNLOADER_APP_PRIVATE_KEY`) |
| `repositories` | No       | `pctl`  | Comma-separated repos to scope the token to                                   |

## Outputs

| Output  | Description                                               |
| ------- | --------------------------------------------------------- |
| `token` | Short-lived token with read access to the specified repos |

## Examples

```yaml
secrets:
  RELEASE_DOWNLOADER_APP_ID:
    required: true
  RELEASE_DOWNLOADER_APP_PRIVATE_KEY:
    required: true

jobs:
  deploy:
    runs-on: warp-ubuntu-2404-x64-2x
    steps:
      - name: Get release download token
        id: release-token
        uses: credova/platform-workflows/actions/auth-release-token@master
        with:
          client-id: ${{ secrets.RELEASE_DOWNLOADER_APP_ID }}
          private-key: ${{ secrets.RELEASE_DOWNLOADER_APP_PRIVATE_KEY }}

      - name: Install pctl
        uses: credova/platform-workflows/actions/install-pctl@master
        with:
          token: ${{ steps.release-token.outputs.token }}
```

## Runner

This is a composite action. It runs on the caller job's runner, set by `runs-on`.

- Default in examples: `warp-ubuntu-2404-x64-2x`.
- Sizes: `2x`, `4x`, `8x`, `16x`, `32x`. Arch: `x64`, `arm64`.
- Details: [Runners](../../README.md#runners). Confirm latest images: https://www.warpbuild.com/docs/ci/cloud-runners

## Why this exists

Keeps GitHub App credentials in one place. Update this action when the app changes; every workflow that downloads releases gets the fix.
