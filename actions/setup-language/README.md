# setup-language

Setup a language runtime for the current job. Single action that handles Go, Node.js, Kotlin, Python, Ruby, and .NET.

## Inputs

| Input      | Required | Description                                                                                       |
| ---------- | -------- | ------------------------------------------------------------------------------------------------- |
| `language` | Yes      | `go`, `node`, `kotlin`, `python`, `ruby`, or `dotnet`                                             |
| `version`  | Yes      | Language/runtime version (e.g. `1.24`, `20`, `21`, `3.12`)                                        |
| `cache`    | No       | `false` — enable WarpBuild dependency caching. Auto-disables built-in Go/Node caches when `true`. |

## Examples

### Go

```yaml
- uses: credova/platform-workflows/actions/setup-language@v1
  with:
    language: go
    version: "1.24"
```

### Node.js

```yaml
- uses: credova/platform-workflows/actions/setup-language@v1
  with:
    language: node
    version: "20"
```

### Kotlin (JDK)

```yaml
- uses: credova/platform-workflows/actions/setup-language@v1
  with:
    language: kotlin
    version: "21"
```

### Python

```yaml
- uses: credova/platform-workflows/actions/setup-language@v1
  with:
    language: python
    version: "3.12"
```

### Ruby

```yaml
- uses: credova/platform-workflows/actions/setup-language@v1
  with:
    language: ruby
    version: "3.3"
```

### .NET

```yaml
- uses: credova/platform-workflows/actions/setup-language@v1
  with:
    language: dotnet
    version: "8.0"
```

### With WarpBuild caching

```yaml
- uses: credova/platform-workflows/actions/setup-language@v1
  with:
    language: go
    version: "1.24"
    cache: true
```

When `cache: true`, Go's built-in `actions/setup-go` cache and Node's `actions/setup-node` cache are automatically disabled to avoid double-caching.

## Internal Mapping

| Language | Action Used               | Version Input            |
| -------- | ------------------------- | ------------------------ |
| `go`     | `actions/setup-go@v5`     | `go-version`             |
| `node`   | `actions/setup-node@v4`   | `node-version`           |
| `kotlin` | `actions/setup-java@v4`   | `java-version` (Temurin) |
| `python` | `actions/setup-python@v5` | `python-version`         |
| `ruby`   | `ruby/setup-ruby@v1`      | `ruby-version`           |
| `dotnet` | `actions/setup-dotnet@v4` | `dotnet-version`         |
