# Novyx Memory Integrity Check

A GitHub Action that runs memory integrity checks against the [Novyx API](https://novyxlabs.com) in your CI pipeline.

## Usage

```yaml
- uses: novyxlabs/novyx-test-action@v1
  with:
    api-key: ${{ secrets.NOVYX_API_KEY }}
```

## Inputs

| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| `api-key` | Yes | — | Your Novyx API key (`nram_...`) |
| `base-url` | No | `https://novyx-ram-api.fly.dev` | Novyx API base URL |
| `checks` | No | `audit_health,stats` | Comma-separated checks: `audit_health`, `stats`, `integrity` |
| `fail-on-error` | No | `true` | Fail the workflow step if any check fails |

## Outputs

| Output | Description |
|--------|-------------|
| `audit-healthy` | Whether the audit chain is healthy (`true`/`false`) |
| `memory-count` | Total number of memories |
| `integrity-valid` | Whether all memories pass integrity checks (`true`/`false`) |
| `summary` | JSON summary of all check results |

## Checks

### `audit_health` (Free tier)
Calls `GET /v1/audit/summary` and reports total operations and anomaly count. Warns if anomalies are detected.

### `stats` (Free tier)
Calls `GET /v1/memories/stats` and reports total memory count. Useful for tracking memory growth in CI.

### `integrity` (Pro tier)
Calls `GET /v1/audit/verify` to run cryptographic integrity verification on all memories. Fails the step if any memory fails SHA-256 validation.

## Example: Full check with integrity

```yaml
name: Memory Integrity
on: [push]
jobs:
  check:
    runs-on: ubuntu-latest
    steps:
      - uses: novyxlabs/novyx-test-action@v1
        id: novyx
        with:
          api-key: ${{ secrets.NOVYX_API_KEY }}
          checks: audit_health,stats,integrity
      - run: echo "Memories: ${{ steps.novyx.outputs.memory-count }}"
```

## License

MIT
