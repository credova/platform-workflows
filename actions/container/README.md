# container

Full container lifecycle — build, scan, push, tag, reuse, retag. Self-contained: calls `auth-gcp` internally and runs a mandatory container scan after every build.

## Inputs

| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| `name` | Yes | — | Image name (used for registry path) |
| `dockerfile` | No | `./Dockerfile` | Path to Dockerfile |
| `context` | No | `./` | Docker build context |
| `target` | No | — | Docker build stage target (`--target`) |
| `build` | No | `true` | Build the image |
| `push` | No | `false` | Push to Artifact Registry after scan |
| `reuse` | No | `true` | Check if image exists first, skip build if so |
| `tag` | No | `github.sha` | Image tag |
| `extra-tags` | No | — | Additional tags to apply |
| `retag` | No | `false` | Retag an existing image (skip build + scan) |
| `source-tag` | No | — | Source tag for retag operation |
| `build-args` | No | — | Docker build args (one per line) |
| `project-id` | No | — | GCP project ID |
| `workload-identity-provider` | No | — | WIF provider resource name |
| `registry` | No | `us-docker.pkg.dev` | Artifact Registry hostname |
| `platform` | No | `linux/amd64` | Target platform (e.g. `linux/amd64`, `linux/arm64`) |
| `severity` | No | `HIGH` | Minimum severity to fail container scan on |
| `warpbuild-profile` | No | `""` | WarpBuild Docker Builder profile name (enables remote builds) |
| `warpbuild-api-key` | No | `""` | WarpBuild API key (only needed on non-WarpBuild runners) |

## Outputs

| Output | Description |
|--------|-------------|
| `image` | Full image reference (`registry/project/repo/name:tag`) |
| `digest` | Image digest |
| `reused` | Whether the image was reused from a previous build |

## Examples

### PR workflow — build and scan only, no push

```yaml
- uses: credova/platform-workflows/actions/container@v1
  with:
    name: merchant-portal
    dockerfile: apps/merchant-portal/Dockerfile
    context: ./
    build: true
    push: false
```

### Deploy workflow — full build, scan, tag, push

```yaml
- uses: credova/platform-workflows/actions/container@v1
  with:
    name: merchant-portal
    dockerfile: apps/merchant-portal/Dockerfile
    context: ./
    build: true
    push: true
    reuse: true
    tag: v1.2.3
    extra-tags: latest
    project-id: psq-shd-operations
    workload-identity-provider: projects/123/locations/global/...
```

### Multi-stage Dockerfile with explicit target

```yaml
- uses: credova/platform-workflows/actions/container@v1
  with:
    name: merchant-portal
    dockerfile: apps/merchant-portal/Dockerfile
    target: release
    build: true
    push: true
```

### Retag for production (no build, no scan — already scanned)

```yaml
- uses: credova/platform-workflows/actions/container@v1
  with:
    name: merchant-portal
    retag: true
    source-tag: v1.2.3-stg
    tag: v1.2.3-prd
    project-id: psq-shd-operations
    workload-identity-provider: projects/123/locations/global/...
```

### WarpBuild remote build

```yaml
- uses: credova/platform-workflows/actions/container@v1
  with:
    name: merchant-portal
    dockerfile: apps/merchant-portal/Dockerfile
    build: true
    push: true
    warpbuild-profile: my-docker-builder
    project-id: psq-shd-operations
    workload-identity-provider: projects/123/locations/global/...
```

### Cross-platform build (arm64)

```yaml
- uses: credova/platform-workflows/actions/container@v1
  with:
    name: merchant-portal
    platform: linux/arm64
    build: true
    push: true
    project-id: psq-shd-operations
    workload-identity-provider: projects/123/locations/global/...
```

## Internal Flow (`build: true` + `push: true`)

1. `auth-gcp` — authenticate to GCP + configure Docker for Artifact Registry
2. Reuse check — skip build if image already exists for this SHA (when `reuse: true`)
3. Build image (with `--target` if specified)
4. **Container scan (mandatory)** — trivy scan, blocks push on failure
5. Tag + push image — atomic, nothing escapes unscanned
