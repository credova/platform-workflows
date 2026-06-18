# auth-npm-token

Generate a short-lived GitHub token for npm publish operations. Wraps `actions/create-github-app-token` with the org's npm publishing GitHub App.

> **Internal action.** Used by reusable workflows to generate tokens for npm package publishing.

## Inputs

| Input          | Required | Default | Description                                                    |
| -------------- | -------- | ------- | -------------------------------------------------------------- |
| `client-id`    | Yes      | -       | GitHub App client ID (from org secret `NPM_APP_ID`)            |
| `private-key`  | Yes      | -       | GitHub App private key (from org secret `NPM_APP_PRIVATE_KEY`) |
| `repositories` | No       | `""`    | Comma-separated repos to scope the token to                    |

## Outputs

| Output  | Description                                 |
| ------- | ------------------------------------------- |
| `token` | Short-lived token with package write access |

## Examples

```yaml
secrets:
  NPM_APP_ID:
    required: true
  NPM_APP_PRIVATE_KEY:
    required: true

jobs:
  publish:
    runs-on: warp-ubuntu-2404-x64-2x
    steps:
      - name: Get npm publish token
        id: npm-token
        uses: credova/platform-workflows/actions/auth-npm-token@master
        with:
          client-id: ${{ secrets.NPM_APP_ID }}
          private-key: ${{ secrets.NPM_APP_PRIVATE_KEY }}

      - name: Publish package
        run: npm publish
        env:
          NODE_AUTH_TOKEN: ${{ steps.npm-token.outputs.token }}
```

## Runner

This is a composite action. It runs on the caller job's runner, set by `runs-on`.

- Default in examples: `warp-ubuntu-2404-x64-2x`.
- Sizes: `2x`, `4x`, `8x`, `16x`, `32x`. Arch: `x64`, `arm64`.
- Details: [Runners](../../README.md#runners). Confirm latest images: https://www.warpbuild.com/docs/ci/cloud-runners
