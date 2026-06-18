# setup-language

Set up a language runtime for the current job. Handles Go, Node.js, Kotlin, Python, Ruby, .NET, and PHP.

## Inputs

| Input      | Required | Description                                                                                      |
| ---------- | -------- | ------------------------------------------------------------------------------------------------ |
| `language` | Yes      | `go`, `node`, `kotlin`, `python`, `ruby`, `dotnet`, or `php`                                     |
| `version`  | Yes      | Language/runtime version (e.g. `1.24`, `20`, `21`, `3.12`, `8.2`)                                |
| `cache`    | No       | `false`. Enable WarpBuild dependency caching. Auto-disables built-in Go/Node caches when `true`. |

## Caching

When `cache: true`:

- Go's `actions/setup-go` cache and Node's `actions/setup-node` cache are disabled to avoid double-caching.
- For Kotlin, Gradle's built-in cache is disabled in favor of WarpBuild cache.

## Internal Mapping

| Language | Action Used                 | Version Input            | Notes                              |
| -------- | --------------------------- | ------------------------ | ---------------------------------- |
| `go`     | `actions/setup-go@v6`       | `go-version`             |                                    |
| `node`   | `actions/setup-node@v6`     | `node-version`           |                                    |
| `kotlin` | `actions/setup-java@v5`     | `java-version` (Temurin) | + `gradle/actions/setup-gradle@v4` |
| `python` | `actions/setup-python@v6`   | `python-version`         |                                    |
| `ruby`   | `ruby/setup-ruby@v1`        | `ruby-version`           |                                    |
| `dotnet` | `actions/setup-dotnet@v5`   | `dotnet-version`         |                                    |
| `php`    | `shivammathur/setup-php@v2` | `php-version`            |                                    |

## Examples

### Go

```yaml
- uses: credova/platform-workflows/actions/setup-language@master
  with:
    language: go
    version: "1.24"
```

### Node.js

```yaml
- uses: credova/platform-workflows/actions/setup-language@master
  with:
    language: node
    version: "20"
```

### Kotlin (JDK + Gradle)

Sets up JDK via Temurin and Gradle via `gradle/actions/setup-gradle`. Gradle wrapper validation, caching, and daemon management are handled automatically.

```yaml
- uses: credova/platform-workflows/actions/setup-language@master
  with:
    language: kotlin
    version: "21"
```

### Python

```yaml
- uses: credova/platform-workflows/actions/setup-language@master
  with:
    language: python
    version: "3.12"
```

### Ruby

```yaml
- uses: credova/platform-workflows/actions/setup-language@master
  with:
    language: ruby
    version: "3.3"
```

### .NET

```yaml
- uses: credova/platform-workflows/actions/setup-language@master
  with:
    language: dotnet
    version: "8.0"
```

### PHP

```yaml
- uses: credova/platform-workflows/actions/setup-language@master
  with:
    language: php
    version: "8.2"
```

### With WarpBuild caching

```yaml
- uses: credova/platform-workflows/actions/setup-language@master
  with:
    language: go
    version: "1.24"
    cache: true
```
