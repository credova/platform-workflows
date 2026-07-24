# compliance

Process and policy gates. All checks run by default; opt out explicitly.

Security asks "is this artifact safe?" Compliance asks "did the team follow the process?"

## Check Types

| Type     | Default | Description                                                       |
| -------- | ------- | ----------------------------------------------------------------- |
| `ticket` | `true`  | PR must reference a Shortcut ticket (`sc-12345` or Shortcut link) |

## Inputs

| Input    | Required | Default | Description                         |
| -------- | -------- | ------- | ----------------------------------- |
| `ticket` | No       | `true`  | Require a Shortcut ticket reference |

## Examples

### Default: ticket check enabled

```yaml
- uses: credova/platform-workflows/actions/compliance@master
```

### Opt out of ticket check

```yaml
- uses: credova/platform-workflows/actions/compliance@master
  with:
    ticket: false
```

## PR Comment

On `pull_request` events with the ticket check enabled (`ticket: true`, the
default), the action upserts a single `<!-- compliance-report -->` comment on
every run: `❌ Failed` with the reason (e.g. missing ticket reference) on
failure, or `✅ Passed` on success. A passing re-run flips a prior failure
comment to `✅ Passed`, so a fixed PR never leaves a stale failure comment
behind. Setting `ticket: false` skips both the check and the comment step, and
no comment is posted outside `pull_request` events.

## Ticket Patterns

The check searches the PR title, body, branch name, commit message, and PR comments for:

- **Tag:** `sc-12345` or `SC-12345`
- **Link:** `https://app.shortcut.com/<org>/story/12345`

Dependabot and Renovate PRs (branch prefix `dependabot/` or `renovate/`) are skipped.
