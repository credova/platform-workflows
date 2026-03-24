# compliance

Process and policy gates. Ensures teams follow required procedures. All checks run by default - opt out explicitly.

**Distinction from security:** Security asks "is this artifact safe?" Compliance asks "did the team follow the process?"

## Check Types

| Type     | Default | Description                                                       |
| -------- | ------- | ----------------------------------------------------------------- |
| `ticket` | `true`  | PR must reference a Shortcut ticket (`sc-12345` or Shortcut link) |

## Inputs

| Input    | Required | Default | Description                         |
| -------- | -------- | ------- | ----------------------------------- |
| `ticket` | No       | `true`  | Require a Shortcut ticket reference |

## Examples

### Default - ticket check enabled

```yaml
- uses: credova/platform-workflows/actions/compliance@v1
```

### Opt out of ticket check

```yaml
- uses: credova/platform-workflows/actions/compliance@v1
  with:
    ticket: false
```

## Ticket Patterns

The check searches the PR title, body, branch name, commit message, and PR comments for:

- **Tag:** `sc-12345` or `SC-12345`
- **Link:** `https://app.shortcut.com/<org>/story/12345`

### Automated PRs

Dependabot and Renovate PRs (branch prefix `dependabot/` or `renovate/`) are automatically skipped.
