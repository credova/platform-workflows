# auth-npm-token

> **Internal action** - used by reusable workflows to generate tokens for npm package publishing.

Generates a short-lived GitHub token for npm publish operations. Wraps `actions/create-github-app-token` with the org's npm publishing GitHub App.

## Inputs

| Input          | Required | Default | Description                                                    |
| -------------- | -------- | ------- | -------------------------------------------------------------- |
| `app-id`       | Yes      | -       | GitHub App ID (from org secret `NPM_APP_ID`)                   |
| `private-key`  | Yes      | -       | GitHub App private key (from org secret `NPM_APP_PRIVATE_KEY`) |
| `repositories` | No       | -       | Comma-separated repos to scope the token to                    |

## Outputs

| Output  | Description                                 |
| ------- | ------------------------------------------- |
| `token` | Short-lived token with package write access |

## Usage in reusable workflows

```yaml
secrets:
  NPM_APP_ID:
    required: true
  NPM_APP_PRIVATE_KEY:
    required: true

jobs:
  publish:
    runs-on: ubuntu-latest
    steps:
      - name: Get npm publish token
        id: npm-token
        uses: ./actions/auth-npm-token
        with:
          app-id: ${{ secrets.NPM_APP_ID }}
          private-key: ${{ secrets.NPM_APP_PRIVATE_KEY }}

      - name: Publish package
        run: npm publish
        env:
          NODE_AUTH_TOKEN: ${{ steps.npm-token.outputs.token }}
```
