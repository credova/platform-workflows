# dispatch-and-wait

Dispatch a `workflow_dispatch` workflow in a repo and wait for it to conclude, failing the step if the run fails. Used by `kotlin-deploy`'s staging/production validation gates to run a caller-owned smoke/acceptance suite as a post-deploy gate — all app-specific setup (runtime, browsers, credentials) stays in the dispatched workflow, so the shared workflow stays language/app-agnostic.

Needs a token with `actions: write` on the target repo (to dispatch and read runs).

## Inputs

| Input             | Required | Default            | Description                                                               |
| ----------------- | -------- | ------------------ | ------------------------------------------------------------------------- |
| `workflow`        | yes      |                    | Workflow filename to dispatch (e.g. `acceptance-tests.yaml`)              |
| `ref`             | yes      |                    | Branch or tag to dispatch on (workflow_dispatch needs a branch/tag, not a SHA) |
| `token`           | yes      |                    | GitHub token with `actions: write` on the target repo                    |
| `inputs-json`     | no       | `""`               | JSON object of inputs for the dispatched workflow (values are never logged) |
| `timeout-minutes` | no       | `"20"`             | Minutes to wait for the run to conclude before failing                   |
| `label`           | no       | `validation`       | Human label used in log/error messages                                   |
| `repo`            | no       | current repository | `owner/repo` the workflow lives in                                       |

## How it works

1. Records the newest existing `workflow_dispatch` run id for the workflow+branch (`gh workflow run` doesn't return a run id).
2. Dispatches the workflow, passing `inputs-json` as `--raw-field key=value` args (logging only whether inputs were provided, not their values).
3. Polls for a run newer than the recorded id, then waits for it to conclude (or `timeout-minutes`), failing the step on any non-`success` conclusion.

> Correlation caveat: the run is tracked by "newest new run", not a per-dispatch token, so a concurrent dispatch of the same workflow on the same ref could be tracked instead. See the inline comment in `action.yaml`.

## Example

```yaml
- uses: credova/platform-workflows/actions/dispatch-and-wait@master
  with:
    workflow: acceptance-tests.yaml
    ref: ${{ github.ref_name }}
    inputs-json: '{"environment":"staging","suite":"smoke"}'
    label: staging-validation
    token: ${{ github.token }}
```
