# increment-tag

Auto-increment semantic version tags. Supports suffix-based sequences for environment-specific tag tracking.

## Inputs

| Input    | Required | Default | Description                                                            |
| -------- | -------- | ------- | ---------------------------------------------------------------------- |
| `suffix` | No       | -       | Environment suffix (e.g., `stg`, `prd`) creates tags like `v1.0.0-stg` |
| `prefix` | No       | `v`     | Tag prefix                                                             |
| `bump`   | No       | `patch` | Version component to bump: `major`, `minor`, `patch`                   |

## Outputs

| Output         | Description                                   |
| -------------- | --------------------------------------------- |
| `tag`          | The new version tag                           |
| `previous-tag` | The previous version tag (empty if first tag) |

## Examples

### Basic patch bump

```yaml
- id: tag
  uses: credova/platform-workflows/actions/increment-tag@master

- run: echo "New tag: ${{ steps.tag.outputs.tag }}"
# v1.0.0 → v1.0.1
```

### Environment-specific tags

```yaml
- id: tag
  uses: credova/platform-workflows/actions/increment-tag@master
  with:
    suffix: stg
# v1.0.0-stg → v1.0.1-stg
```

### Minor version bump

```yaml
- id: tag
  uses: credova/platform-workflows/actions/increment-tag@master
  with:
    bump: minor
# v1.2.3 → v1.3.0
```

### Major version bump

```yaml
- id: tag
  uses: credova/platform-workflows/actions/increment-tag@master
  with:
    bump: major
# v1.2.3 → v2.0.0
```

## How It Works

1. Fetches all git tags.
2. Finds the latest tag matching `{prefix}X.Y.Z[-{suffix}]`.
3. Increments the specified component.
4. Outputs the new tag. Does **not** create or push the tag; that is the caller's job.
