# container

Container lifecycle: build, scan, push, tag, reuse, retag. Calls `auth-gcp` internally. Scans a new image and a reused image via the `security` action.

## Inputs

| Input                        | Required | Default             | Description                                              |
| ---------------------------- | -------- | ------------------- | -------------------------------------------------------- |
| `name`                       | Yes      | -                   | Image name (used for registry path)                      |
| `dockerfile`                 | No       | `./Dockerfile`      | Path to Dockerfile                                       |
| `context`                    | No       | `./`                | Docker build context                                     |
| `target`                     | No       | -                   | Docker build stage target (`--target`)                   |
| `build`                      | No       | `true`              | Build the image                                          |
| `push`                       | No       | `false`             | Push to Artifact Registry after scan                     |
| `reuse`                      | No       | `true`              | Skip build and push if the image exists. Scan still runs |
| `tag`                        | No       | `github.sha`        | Image tag                                                |
| `extra-tags`                 | No       | -                   | Additional tags to apply                                 |
| `retag`                      | No       | `false`             | Retag an existing image (skip build + scan)              |
| `source-tag`                 | No       | -                   | Source tag for retag operation                           |
| `build-args`                 | No       | -                   | Docker build args (one per line)                         |
| `platform`                   | No       | `linux/amd64`       | Target platform (e.g. `linux/amd64`, `linux/arm64`)      |
| `no-cache-filters`           | No       | `""`                | Dockerfile stage names to build without the layer cache (comma- or newline-separated) |
| `pull`                       | No       | `false`             | Re-resolve every base image the Dockerfile references (`--pull`) |
| `project-id`                 | No       | -                   | GCP project ID                                           |
| `workload-identity-provider` | No       | -                   | WIF provider resource name                               |
| `service-account`            | No       | -                   | Service account email to impersonate via WIF             |
| `registry`                   | No       | `us-docker.pkg.dev` | Artifact Registry hostname                               |
| `scan`                       | No       | `true`              | Run the security scan on the image (syft + grype)        |
| `severity`                   | No       | `HIGH`              | Minimum severity to fail image scan on                   |
| `warpbuild-profile`          | No       | `""`                | WarpBuild Docker Builder profile name                    |
| `warpbuild-api-key`          | No       | `""`                | WarpBuild API key (only needed on non-WarpBuild runners) |

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

### Force a rebuild of stages that upgrade OS packages

A `RUN apk upgrade` layer caches until something above it changes. Alpine ships CVE fixes far
more often than a base image gets republished, so an image can keep serving packages the distro
has already patched. Name the stage that runs the upgrade and buildx rebuilds it every time.

`pull` does a different job. It re-resolves the digest a floating base tag points at, and it
does not re-run a cached `RUN`. Set both to get a fresh base and a fresh `apk upgrade`.

```yaml
- uses: credova/platform-workflows/actions/container@master
  with:
    name: merchant-portal
    build: true
    push: true
    no-cache-filters: runtime
    pull: true
```

Comma- and newline-separated lists both work:

```yaml
    no-cache-filters: base,runtime
```

Stage names are Dockerfile-specific, so there is no safe default. buildx ignores a name that
matches no stage and prints no warning, so a typo looks like success. Check the name against the
`AS <name>` clauses in the Dockerfile. A value that is set but names no stage at all, such as
`,,,`, fails the build rather than going green having busted nothing. Name the narrowest stage that holds the upgrade, because
busting an early stage discards the cache for everything after it.

This only bites where the layer cache survives between runs, meaning WarpBuild Docker Builders.
A plain buildx builder starts cold every job, so `apk upgrade` already re-runs there.

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

## Internal Flow (`build: true`)

1. Compute image metadata.
2. `auth-gcp`: authenticate to GCP and configure Docker for Artifact Registry.
3. Reuse check: skip the build and the push if the image already exists for this SHA (when `reuse: true`).
4. Build image via buildx or WarpBuild. `no-cache-filters` forces the named stages to rebuild; `pull` re-resolves base image digests.
5. Pull image for scan: `scripts/docker-pull-for-scan.sh` puts the image in the local Docker daemon when the build did not. A reuse hit, a multi-arch build, and a WarpBuild build that pushes all leave nothing there.
6. **Image scan:** delegates to the `security` action (syft SBOM + grype vuln scan), which posts results to the PR comment. Blocks on `severity` threshold. A reused image is scanned like a new one, because known vulnerabilities change even when the image does not. Skipped on `retag` or `scan: false`; `scan` is the only input that turns the scan off.
7. Tag and push: only if `push: true`, and only for an image the run built.

`extra-tags` follows the same rule on the buildx-push path, where the tags are applied in the
registry rather than by `docker push`: a tag that already exists and points elsewhere — a moving
tag such as `pr-<number>` — is overwritten with imagetools rather than moved.

In `retag` mode the step resolves both digests before it acts. It is a no-op when the target tag
already points at the source digest, which is what a re-run of an already-tagged job hits. It
calls `gcloud artifacts docker tags add` when the target tag does not exist yet. When the target
tag exists on a different digest it re-pushes the source manifest with `docker buildx imagetools
create` instead, because `tags add` would delete the old tag first and
`artifactregistry.tags.delete` is outside `roles/artifactregistry.writer`.
