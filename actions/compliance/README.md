# compliance

Process and policy gates. Ensures teams follow required procedures. All checks run by default — opt out explicitly.

**Distinction from security:** Security asks "is this artifact safe?" Compliance asks "did the team follow the process?"

## Check Types

| Type | Default | Description |
|------|---------|-------------|
| `ticket` | `true` | PR/commit must reference a ticket (e.g., `JIRA-123`, `PROJECT-456`, `#123`) |

## Inputs

| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| `ticket` | No | `true` | Require a ticket reference in PR title, body, or commit message |

## Examples

### Default — ticket check enabled

```yaml
- uses: credova/platform-workflows/actions/compliance@v1
```

### Opt out of ticket check

```yaml
- uses: credova/platform-workflows/actions/compliance@v1
  with:
    ticket: false
```

## Ticket Pattern

Matches these patterns in PR title, body, or commit messages:
- `JIRA-123` / `PROJECT-456` — Jira-style references
- `#123` — GitHub issue references
