# cloudflare-purge

Purge entries from the Cloudflare cache. Wraps the [Cloudflare cache purge API](https://developers.cloudflare.com/api/resources/cache/methods/purge/).

Use this after a deploy that changes an asset served from a long-lived cache. Cloudflare keeps serving the old body until the entry is purged or expires.

> **Note:** Purging everything and purging by host are not supported. Both are blunt, and a full purge on a busy zone sends every request to the origin.

## Inputs

| Input       | Required | Default | Description                                              |
| ----------- | -------- | ------- | -------------------------------------------------------- |
| `mode`      | Yes      | -       | `prefixes`, `files`, or `tags`                           |
| `value`     | Yes      | -       | Newline-delimited values to purge                        |
| `zone-id`   | Yes      | -       | Cloudflare zone ID to purge from                         |
| `api-token` | Yes      | -       | Cloudflare API token with the `Zone.Cache Purge` permission |

### Modes

| Mode       | Each line is                                                              |
| ---------- | ------------------------------------------------------------------------- |
| `prefixes` | A URL prefix, without a scheme — `example.com/assets/`                    |
| `files`    | A full URL, or a JSON object as defined by the API                        |
| `tags`     | A `Cache-Tag` value set by the origin                                     |

`prefixes` and `tags` need an Enterprise plan. `files` works on every plan.

## Credentials

`CLOUDFLARE_API_TOKEN` is a GitHub organisation secret. `square_root` and `platform-iac` already use it, and every repo in the org can read it. No per-repo setup is needed — pass it straight through:

```yaml
api-token: ${{ secrets.CLOUDFLARE_API_TOKEN }}
```

The same name is what `pctl cloudflare` reads from the environment, so one token covers both.

A zone ID is not a secret. `square_root` keeps zone IDs in committed terraform. Pass it as a plain value, or hold it in a repo or org variable if you prefer one place to change it.

## Outputs

| Output      | Description                 |
| ----------- | --------------------------- |
| `purge-id`  | Cloudflare purge request ID |

## Usage

Purge one file after a deploy:

```yaml
- name: Purge checkout.js
  uses: credova/platform-workflows/actions/cloudflare-purge@v1
  with:
    mode: files
    value: https://plugin.payments.stg.credova.com/bigcommerce/payments/abc123/checkout.js
    zone-id: 0123456789abcdef0123456789abcdef # the zone the hostname belongs to
    api-token: ${{ secrets.CLOUDFLARE_API_TOKEN }} # org secret, nothing to set up
```

Purge several values — one per line:

```yaml
- name: Purge static assets
  uses: credova/platform-workflows/actions/cloudflare-purge@v1
  with:
    mode: prefixes
    value: |
      example.com/static/
      example.com/assets/
    zone-id: ${{ vars.CLOUDFLARE_ZONE_ID }}
    api-token: ${{ secrets.CLOUDFLARE_API_TOKEN }}
```

Purge a file and send the headers that identify the cached variant:

```yaml
- name: Purge a variant
  uses: credova/platform-workflows/actions/cloudflare-purge@v1
  with:
    mode: files
    value: |
      {"url": "https://example.com/app.js", "headers": {"Accept-Encoding": "br"}}
    zone-id: ${{ vars.CLOUDFLARE_ZONE_ID }}
    api-token: ${{ secrets.CLOUDFLARE_API_TOKEN }}
```

## Behaviour

- The step fails if the API does not return an explicit success. A purge that quietly does nothing leaves stale content in place, which looks the same as a good deploy.
- Blank lines in `value` are dropped, and each line is trimmed.
- A line that parses as JSON is sent as an object. Every other line is sent as a string.

## Limits

Cloudflare caps each request: 30 files on Free, Pro, and Business plans, and 500 on Enterprise. Prefixes and tags are capped at 30 per request. Split larger lists across steps.
