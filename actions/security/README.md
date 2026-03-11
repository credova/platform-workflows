# security

Vulnerability and code scanning with selectable scan types. All applicable scans run by default — opt out explicitly.

## Scan Types

| Type | Tool | Default | Description |
|------|------|---------|-------------|
| `packages` | [Trivy](https://github.com/aquasecurity/trivy) | `true` | Scans dependency manifests (package.json, go.mod, build.gradle, etc.) |
| `code` | [OpenGrep](https://github.com/opengrep/opengrep) | `true` | Static analysis / SAST across 30+ languages |
| `container` | [Trivy](https://github.com/aquasecurity/trivy) | `false` | Container image scanning (called internally by the `container` action) |

## Inputs

| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| `packages` | No | `true` | Run package vulnerability scan |
| `code` | No | `true` | Run code static analysis |
| `container` | No | `false` | Run container image scan |
| `image-ref` | No | `""` | Container image reference (required when `container: true`) |
| `severity` | No | `HIGH` | Minimum severity to fail on (`HIGH`, `CRITICAL`) |

## Examples

### Default — all scans enabled

```yaml
- uses: credova/platform-workflows/actions/security@v1
```

### Opt out of code scanning

```yaml
- uses: credova/platform-workflows/actions/security@v1
  with:
    code: false
```

### Only fail on critical vulnerabilities

```yaml
- uses: credova/platform-workflows/actions/security@v1
  with:
    severity: CRITICAL
```

### Package scan only

```yaml
- uses: credova/platform-workflows/actions/security@v1
  with:
    code: false
```

### Container image scan (called internally by `container` action)

```yaml
- uses: credova/platform-workflows/actions/security@v1
  with:
    packages: false
    code: false
    container: true
    image-ref: us-docker.pkg.dev/my-project/my-repo/my-image:latest
```

## Outputs

- SARIF results from OpenGrep are written to `opengrep-results.sarif` in the workspace for GitHub Code Scanning integration.

## Internal Tools

These are implementation details — swappable without consumer impact:

- **Trivy** — package and container vulnerability scanning
- **OpenGrep** — code/static analysis (Semgrep-compatible, LGPL 2.1)
