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

All three modes work on every plan.

## Credentials

Pass `CLOUDFLARE_CACHE_TOKEN`, a token scoped to the `Zone.Cache Purge` permission:

```yaml
api-token: ${{ secrets.CLOUDFLARE_CACHE_TOKEN }}
```

This is not `CLOUDFLARE_API_TOKEN`. That token is much broader — `square_root` and `platform-iac` use it to apply terraform — and a purge does not need it.

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
    api-token: ${{ secrets.CLOUDFLARE_CACHE_TOKEN }}
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
    api-token: ${{ secrets.CLOUDFLARE_CACHE_TOKEN }}
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
    api-token: ${{ secrets.CLOUDFLARE_CACHE_TOKEN }}
```

## Behaviour

- The step fails if the API does not return an explicit success. A purge that quietly does nothing leaves stale content in place, which looks the same as a good deploy.
- Blank lines in `value` are dropped, and each line is trimmed.
- A line that parses as JSON is sent as an object. Every other line is sent as a string.

## Limits

Cloudflare caps each request at 100 values. `files` is the one exception: an Enterprise plan raises that cap to 500. Split larger lists across steps.

Cloudflare also rate-limits purge requests per account, and the rate depends on the plan. See [Availability and limits](https://developers.cloudflare.com/cache/how-to/purge-cache/#availability-and-limits).
