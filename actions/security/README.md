# security

Two-phase security scanning via [Anchore OSS](https://oss.anchore.com) (syft/grype/grant) and [OpenGrep](https://github.com/opengrep/opengrep). All scans run by default - opt out explicitly.

## Phases

| Phase      | Trigger                   | Tools                        | Blocks                                  |
| ---------- | ------------------------- | ---------------------------- | --------------------------------------- |
| **Source** | `target: dir:.` (default) | syft, grype, grant, opengrep | Yes - vuln + code at severity threshold |
| **Image**  | `target: docker:<ref>`    | syft, grype                  | Yes - vuln at severity threshold        |

Phase 1 runs in the security job before build. Phase 2 runs inside the `container` action automatically after every build - no extra wiring needed.

Both phases update the same PR comment. Phase 1 posts first with a "pending" placeholder for the image section; Phase 2 fills it in.

## Inputs

| Input      | Default | Description                                                                     |
| ---------- | ------- | ------------------------------------------------------------------------------- |
| `target`   | `dir:.` | Syft scan target. `dir:.` for source packages, `docker:<image>` for container   |
| `packages` | `true`  | SBOM generation + vulnerability scan (syft + grype)                             |
| `licenses` | `true`  | License compliance scan (grant) - informational only, never blocks. Source only |
| `code`     | `true`  | Static analysis (opengrep). Source phase only                                   |
| `severity` | `HIGH`  | Minimum severity to fail on (`LOW`, `MEDIUM`, `HIGH`, `CRITICAL`)               |

## PR Comment

Every scan posts or updates a single `## Security Scan` comment on the PR with sections for:

- **Source Packages** - grype vuln counts + Critical/High details table
- **Container Image** - grype vuln counts + Critical/High details table (filled in after build)
- **Code** - opengrep finding count + collapsible findings table
- **Licenses** - grant license breakdown by risk (informational, never blocks)

## Examples

### Default - all scans (no config needed)

```yaml
- uses: credova/platform-workflows/actions/security@master
```

### Opt out of license scanning

```yaml
- uses: credova/platform-workflows/actions/security@master
  with:
    licenses: false
```

### Only fail on critical

```yaml
- uses: credova/platform-workflows/actions/security@master
  with:
    severity: CRITICAL
```

### Container image scan (called internally by `container` action)

```yaml
- uses: credova/platform-workflows/actions/security@master
  with:
    target: docker:us-docker.pkg.dev/my-project/my-repo/my-image:abc1234
    licenses: false
    code: false
```

## Suppressing Vulnerabilities

### `.grype.yaml` ignore rules

Add a `.grype.yaml` in the root of your repo to suppress known/accepted vulnerabilities.

> **Important:** Grype reports vulnerabilities using **GHSA IDs** (e.g. `GHSA-r4mg-4433-c7g3`), not CVE IDs. Your ignore rules must use the ID that grype actually reports. Check the PR comment or scan logs for the exact IDs. CVE-based ignore rules will silently not match.

```yaml
# .grype.yaml
ignore:
  # Ignore a specific vulnerability by its GHSA ID (use the ID from scan results)
  - vulnerability: GHSA-r4mg-4433-c7g3

  # Ignore a vulnerability only when no fix is available
  - vulnerability: GHSA-9xrj-h377-fr87
    fix-state: not-fixed

  # Ignore all vulns in a specific package
  - package:
      name: libcurl

  # Ignore a specific package at a specific version
  - package:
      name: openssl
      version: 1.1.1g

  # Combine criteria - all must match
  - vulnerability: GHSA-353f-x4gh-cqq8
    package:
      name: nokogiri
```

Valid `fix-state` values: `fixed`, `not-fixed`, `wont-fix`, `unknown`

Ignored matches are not deleted - they appear under `ignoredMatches` in the JSON output and can be audited.

To only fail on issues that have a fix available:

```yaml
# .grype.yaml
ignore:
  - fix-state: not-fixed
  - fix-state: wont-fix
  - fix-state: unknown
```

## Tool Versions

Pinned in [`scripts/install-anchore.sh`](../../scripts/install-anchore.sh). Bump deliberately - do not use `latest`.

| Tool     | Purpose                                         |
| -------- | ----------------------------------------------- |
| syft     | SBOM generation                                 |
| grype    | Vulnerability scanning (offline after first DB) |
| grant    | License compliance                              |
| opengrep | Static analysis / SAST                          |

## Output Files

| File                        | Contents                          |
| --------------------------- | --------------------------------- |
| `sbom.spdx.json`            | SPDX SBOM for the scanned target  |
| `grype-source-results.json` | Grype vuln results - source scan  |
| `grype-image-results.json`  | Grype vuln results - image scan   |
| `grant-results.json`        | Grant license results             |
| `opengrep-results.sarif`    | OpenGrep findings in SARIF format |
