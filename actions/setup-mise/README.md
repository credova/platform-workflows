# setup-mise

Install mise and the tools in the repository's mise config. Wraps [`jdx/mise-action`](https://github.com/jdx/mise-action) and puts the tool cache on WarpCache when the job runs on a WarpBuild runner. On any other runner it behaves exactly like `jdx/mise-action`.

Use this in place of `uses: jdx/mise-action@v4`. The action exposes a supported subset of `jdx/mise-action`'s inputs, with the same names and defaults. Inputs not listed below are not forwarded; a caller that passes one gets an "Unexpected input" warning and the value is dropped. Step-level `env` (for example `MISE_GITHUB_TOKEN`) is inherited by every step and needs no input.

## Inputs

| Input               | Required | Default              | Description                                                        |
| ------------------- | -------- | -------------------- | ------------------------------------------------------------------ |
| `version`           | No       | latest release       | mise version to install                                            |
| `install`           | No       | `true`               | Run `mise install` after setup                                     |
| `install_args`      | No       | -                    | Arguments passed to `mise install`, e.g. `bun`                     |
| `cache`             | No       | `true`               | Read and write the mise tool cache                                 |
| `cache_save`        | No       | `true`               | Write the cache after install                                      |
| `cache_key_prefix`  | No       | `mise-v1`            | Cache key prefix. Change it to invalidate the cache                |
| `github_token`      | No       | `${{ github.token }}` | Token mise uses to install GitHub-hosted tools                   |
| `working_directory` | No       | repository root      | Directory mise runs in                                             |

## Outputs

| Output      | Description                                                 |
| ----------- | ----------------------------------------------------------- |
| `cache-hit` | `true` when the tool cache was restored from the primary key |

## How it works

1. Detects a WarpBuild runner from the `WARPBUILD_RUNNER_VERIFICATION_TOKEN` environment variable.
2. Computes one cache key: `<prefix>-<os>-<arch>-<image>-<mise version>[-<MISE_ENV>]-<hash of install_args>-<hash of mise config files>`. `<image>` is the runner's `ImageOS` (for example `ubuntu24`) or `self-hosted`. The config hash covers the same files `jdx/mise-action` hashes: `mise.toml`, `.mise.toml`, `mise.*.toml`, `.config/mise.toml`, `.config/mise/config.toml`, `.mise/config.toml`, `mise/config.toml`, their `.lock` variants, and `.tool-versions`, anywhere in the checkout. It falls back to `no-config` when none exist.
3. On WarpBuild: restores the mise data directory from WarpCache, runs `jdx/mise-action` with its own cache off, and saves to WarpCache after `mise install` when the restore missed. As in `jdx/mise-action`, nothing is saved when `install` is `false`.
4. Elsewhere: runs `jdx/mise-action` with its built-in GitHub Actions cache. No WarpCache calls are made.

Composite actions have no post step, so the WarpCache save runs right after install, which is also where `jdx/mise-action` saves. The restore and save steps are `WarpBuilds/cache/restore` and `WarpBuilds/cache/save`, pinned by SHA. There is no `restore-keys` prefix fallback, matching `jdx/mise-action`: `cache-hit` means the full directory came back.

## Usage

```yaml
- uses: actions/checkout@v7
- uses: credova/platform-workflows/actions/setup-mise@v1
```

Install one tool only:

```yaml
- uses: credova/platform-workflows/actions/setup-mise@v1
  with:
    install_args: bun
```

Read the cache without writing it:

```yaml
- uses: credova/platform-workflows/actions/setup-mise@v1
  with:
    cache_save: false
```
