# container

Container lifecycle: build, scan, push, tag, reuse, retag. Calls `auth-gcp` internally. Runs a security scan after every build via the `security` action.

## Inputs

| Input                        | Required | Default             | Description                                              |
| ---------------------------- | -------- | ------------------- | -------------------------------------------------------- |
| `name`                       | Yes      | -                   | Image name (used for registry path)                      |
| `dockerfile`                 | No       | `./Dockerfile`      | Path to Dockerfile                                       |
| `context`                    | No       | `./`                | Docker build context                                     |
| `target`                     | No       | -                   | Docker build stage target (`--target`)                   |
| `build`                      | No       | `true`              | Build the image                                          |
| `push`                       | No       | `false`             | Push to Artifact Registry after scan                     |
| `reuse`                      | No       | `true`              | Check if image exists first, skip build if so            |
| `tag`                        | No       | `github.sha`        | Image tag                                                |
| `extra-tags`                 | No       | -                   | Additional tags to apply                                 |
| `retag`                      | No       | `false`             | Retag an existing image (skip build + scan)              |
| `source-tag`                 | No       | -                   | Source tag for retag operation                           |
| `build-args`                 | No       | -                   | Docker build args (one per line)                         |
| `platform`                   | No       | `linux/amd64`       | Target platform (e.g. `linux/amd64`, `linux/arm64`)      |
| `project-id`                 | No       | -                   | GCP project ID                                           |
| `workload-identity-provider` | No       | -                   | WIF provider resource name                               |
| `service-account`            | No       | -                   | Service account email to impersonate via WIF             |
| `registry`                   | No       | `us-docker.pkg.dev` | Artifact Registry hostname                               |
| `scan`                       | No       | `true`              | Run security scan on the built image (syft + grype)      |
| `severity`                   | No       | `HIGH`              | Minimum severity to fail image scan on                   |
| `warpbuild-profile`          | No       | `""`                | WarpBuild Docker Builder profile name                    |
| `warpbuild-api-key`          | No       | `""`                | WarpBuild API key (only needed on non-WarpBuild runners) |
| `blacksmith`                 | No       | `false`             | Use Blacksmith's sticky-disk Docker builder (persistent layer cache; requires Blacksmith runners) |

## Outputs

| Output   | Description                              |
| -------- | ---------------------------------------- |
| `image`  | Full image reference (registry/project/repo/name:tag) |
| `digest` | Image content digest                     |
| `reused` | True if image was reused from registry   |

## Examples

### PR workflow: build and scan only, no push

```yaml
- uses: credova/platform-workflows/actions/container@master
  with:
    name: merchant-portal
    dockerfile: apps/merchant-portal/Dockerfile
    build: true
    push: false
```

### Deploy workflow: build, scan, tag, push

```yaml
- uses: credova/platform-workflows/actions/container@master
  with:
    name: merchant-portal
    dockerfile: apps/merchant-portal/Dockerfile
    build: true
    push: true
    reuse: true
    tag: v1.2.3
    extra-tags: latest
    project-id: <gcp-project-id>
    workload-identity-provider: projects/<project-number>/locations/global/...
```

### Multi-stage Dockerfile with explicit target

```yaml
- uses: credova/platform-workflows/actions/container@master
  with:
    name: merchant-portal
    dockerfile: apps/merchant-portal/Dockerfile
    target: release
    build: true
    push: true
```

### Retag for production (no build, no scan: already scanned at staging)

```yaml
- uses: credova/platform-workflows/actions/container@master
  with:
    name: merchant-portal
    retag: true
    source-tag: v1.2.3-stg
    tag: v1.2.3-prd
    project-id: <gcp-project-id>
    workload-identity-provider: projects/<project-number>/locations/global/...
```

### Opt out of image scan (must be explicit)

```yaml
- uses: credova/platform-workflows/actions/container@master
  with:
    name: merchant-portal
    build: true
    scan: false
```

### WarpBuild remote build

```yaml
- uses: credova/platform-workflows/actions/container@master
  with:
    name: merchant-portal
    build: true
    push: true
    warpbuild-profile: my-docker-builder
    project-id: <gcp-project-id>
    workload-identity-provider: projects/<project-number>/locations/global/...
```

### Blacksmith runners: persistent layer cache

On `blacksmith-*` runners, opt in to Blacksmith's sticky-disk-backed builder so
the BuildKit layer cache (base images, dependency-install layers, cache mounts)
persists across runs instead of starting cold on every build. Mutually
exclusive with `warpbuild-profile`.

```yaml
- uses: credova/platform-workflows/actions/container@master
  with:
    name: merchant-portal
    build: true
    push: true
    blacksmith: true
    project-id: <gcp-project-id>
    workload-identity-provider: projects/<project-number>/locations/global/...
```

## Internal Flow (`build: true`)

1. Compute image metadata.
2. `auth-gcp`: authenticate to GCP and configure Docker for Artifact Registry.
3. Reuse check: skip build if image already exists for this SHA (when `reuse: true`).
4. Build image via buildx (optionally on a Blacksmith sticky-disk builder) or WarpBuild.
5. **Image scan:** delegates to the `security` action (syft SBOM + grype vuln scan), which posts results to the PR comment. Blocks on `severity` threshold. Skipped on `retag`, reuse, or `scan: false`.
6. Tag and push: only if `push: true`.
