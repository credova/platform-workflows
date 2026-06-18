# parse-images

Parse `image`/`images` inputs into a JSON matrix for `strategy.matrix.include`.

Internal helper that feeds a downstream container build matrix.

## Inputs

| Input       | Required | Default       | Description                                                                     |
| ----------- | -------- | ------------- | ------------------------------------------------------------------------------- |
| `image`     | No       | `""`          | Single image: `name:dockerfile` or just `name` (defaults to `./Dockerfile`)     |
| `images`    | No       | `""`          | Multi-image YAML list with name, dockerfile, optional target, context, platform |
| `container` | No       | `true`        | Whether container builds are enabled                                            |
| `platform`  | No       | `linux/amd64` | Target platform for single-image builds                                         |
| `repo-name` | No       | `""`          | Fallback image name (repository name)                                           |

## Outputs

| Output         | Description                              |
| -------------- | ---------------------------------------- |
| `image-matrix` | JSON array for `strategy.matrix.include` |

## Examples

### Single image

```yaml
- id: parse
  uses: credova/platform-workflows/actions/parse-images@master
  with:
    repo-name: ${{ github.event.repository.name }}
```

### Multiple images

```yaml
- id: parse
  uses: credova/platform-workflows/actions/parse-images@master
  with:
    images: |
      - name: api
        dockerfile: ./api/Dockerfile
      - name: worker
        dockerfile: ./worker/Dockerfile
        platform: linux/arm64
```

### Consume the matrix in a downstream job

```yaml
jobs:
  parse:
    runs-on: ubuntu-latest
    outputs:
      image-matrix: ${{ steps.parse.outputs.image-matrix }}
    steps:
      - id: parse
        uses: credova/platform-workflows/actions/parse-images@master
        with:
          repo-name: ${{ github.event.repository.name }}

  build:
    needs: parse
    runs-on: ubuntu-latest
    strategy:
      matrix:
        include: ${{ fromJSON(needs.parse.outputs.image-matrix) }}
    steps:
      - run: echo "Building ${{ matrix.name }}"
```
