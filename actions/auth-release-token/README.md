# auth-release-token

> **Internal action** - used by reusable workflows to generate tokens for downloading releases from private repos.

Generates a short-lived GitHub token scoped to specific repositories for release download access. Wraps `actions/create-github-app-token` with the org's release download GitHub App.

## Inputs

| Input          | Required | Default | Description                                                        |
| -------------- | -------- | ------- | ------------------------------------------------------------------ |
| `app-id`       | Yes      | -       | GitHub App ID (from org secret `RELEASE_APP_ID`)                   |
| `private-key`  | Yes      | -       | GitHub App private key (from org secret `RELEASE_APP_PRIVATE_KEY`) |
| `repositories` | No       | `pctl`  | Comma-separated repos to scope the token to                        |

## Outputs

| Output  | Description                        |
| ------- | ---------------------------------- |
| `token` | Short-lived token with read access |

## Usage in reusable workflows

```yaml
secrets:
  RELEASE_APP_ID:
    required: true
  RELEASE_APP_PRIVATE_KEY:
    required: true

jobs:
  deploy:
    runs-on: warp-ubuntu-2204-x64-2x
    steps:
      - name: Get release download token
        id: release-token
        uses: ./actions/auth-release-token
        with:
          app-id: ${{ secrets.RELEASE_APP_ID }}
          private-key: ${{ secrets.RELEASE_APP_PRIVATE_KEY }}

      - name: Install pctl
        uses: ./actions/install-pctl
        with:
          token: ${{ steps.release-token.outputs.token }}
```

## Why this exists

Keeps GitHub App credentials in one place. If the app changes, update this action - every workflow that downloads releases gets the fix automatically.
