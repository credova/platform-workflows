# setup-mise

Install mise and the tools in the repository's mise config. Wraps [`jdx/mise-action`](https://github.com/jdx/mise-action) and puts the tool cache on WarpCache when the job runs on a WarpBuild runner. On any other runner it behaves exactly like `jdx/mise-action`.

Use this in place of `uses: jdx/mise-action@v4`. The inputs below have the same names and defaults.

## Inputs

| Input               | Required | Default              | Description                                                        |
| ------------------- | -------- | -------------------- | ------------------------------------------------------------------ |
| `version`           | No       | latest release       | mise version to install                                            |
| `install`           | No       | `true`               | Run `mise install` after setup                                     |
| `install_args`      | No       | -                    | Arguments passed to `mise install`, e.g. `jq@1.7.1`                |
| `cache`             | No       | `true`               | Read and write the mise tool cache                                 |
| `cache_save`        | No       | `true`               | Write the cache after install                                      |
| `cache_key_prefix`  | No       | `mise-v1`            | Cache key prefix. Change it to invalidate the cache                |
| `github_token`      | No       | `${{ github.token }}` | Token mise uses to install GitHub-hosted tools                    |
| `working_directory` | No       | repository root      | Directory mise runs in                                             |

## Outputs

| Output      | Description                                                 |
| ----------- | ----------------------------------------------------------- |
| `cache-hit` | `true` when the tool cache was restored from the primary key |

## How it works

1. Detects a WarpBuild runner from the `WARPBUILD_RUNNER_VERIFICATION_TOKEN` environment variable.
2. Computes one cache key: `<prefix>-<os>-<arch>-<mise version>-<hash of install_args>-<hash of mise config files>`. The config hash covers `mise.toml`, `.mise.toml`, `.mise/config.toml`, `.config/mise.toml`, `.tool-versions`, `mise.lock`, and `.mise.*.toml` anywhere in the checkout. It falls back to `no-config` when none exist.
3. On WarpBuild: restores the mise data directory from WarpCache, runs `jdx/mise-action` with its own cache off, and saves to WarpCache after install when the restore missed.
4. Elsewhere: runs `jdx/mise-action` with its built-in GitHub Actions cache. No WarpCache calls are made.

Composite actions have no post step, so the WarpCache save runs right after install. The restore and save steps are `WarpBuilds/cache/restore` and `WarpBuilds/cache/save`, pinned by SHA.

## Usage

```yaml
- uses: actions/checkout@v7
- uses: credova/platform-workflows/actions/setup-mise@v1
```

Install one tool only:

```yaml
- uses: credova/platform-workflows/actions/setup-mise@v1
  with:
    install_args: jq@1.7.1
```

Read the cache without writing it, for example on a hotfix branch:

```yaml
- uses: credova/platform-workflows/actions/setup-mise@v1
  with:
    cache_save: false
```
