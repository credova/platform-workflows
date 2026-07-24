# go-report

Post or update Go job results (lint/security/test) on a PR comment.

> **Internal action.** Called by the Go workflows. Posts a sticky PR comment and runs only on `pull_request` events.

## Inputs

| Input              | Required | Default  | Description                                                              |
| ------------------ | -------- | -------- | ------------------------------------------------------------------------ |
| `job`              | Yes      |          | `"lint"`, `"security"`, or `"test"`                                      |
| `outcome`          | Yes      |          | `success \| failure \| skipped \| cancelled`                             |
| `output-file`      | No       | `""`     | Path to captured command output                                          |
| `lint-enabled`     | No       | `"true"` | If `"false"`, the Lint section renders `_Not enabled._` instead of pending |
| `security-enabled` | No       | `"true"` | If `"false"`, the Security section renders `_Not enabled._`              |
| `test-enabled`     | No       | `"true"` | If `"false"`, the Tests section renders `_Not enabled._`                 |

## Examples

### Report a lint result

```yaml
- uses: credova/platform-workflows/actions/go-report@master
  with:
    job: lint
    outcome: ${{ steps.lint.outcome }}
```

### Report a test result with captured output

```yaml
- uses: credova/platform-workflows/actions/go-report@master
  with:
    job: test
    outcome: ${{ steps.test.outcome }}
    output-file: test-output.txt
```
