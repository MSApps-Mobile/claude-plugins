---
name: listing-lint
description: >
  Checks Claude plugins against the Anthropic directory's listing and submission rules before
  they are pushed or submitted: listing fields (displayName, license, documentationUrl, supportUrl,
  privacyPolicyUrl, termsOfServiceUrl, keywords), README length, pinned npx/uvx/pipx/dlx launchers, locked uv run,
  credentials through userConfig, and the hooks.json shape. Use when the user says "lint my
  plugins", "check the listing", "why does the portal say No value", "will this pass the
  directory", "unpinned launcher", "pre-submission check", or before pushing a plugin change.
---

# Listing lint

Run the checker. It is deterministic; do not re-derive its rules by reading files.

```bash
python3 "${CLAUDE_PLUGIN_ROOT}/skills/listing-lint/scripts/listing_lint.py" --repo <repo root>   # every plugins/*/
python3 "${CLAUDE_PLUGIN_ROOT}/skills/listing-lint/scripts/listing_lint.py" <plugin folder> ...   # named plugins
```

Add `--json` for machine-readable output. Exit 0 = no errors, 1 = errors, 2 = bad input.

## What it checks and why

| Rule | Level | Why |
|---|---|---|
| name, description (not `---`), author.name | error | the listing has no title or summary without them |
| license field or LICENSE file | error | the directory does not list a plugin without one |
| README with 40+ words | error | the README is the listing description; validation blocks shorter |
| `privacy_policy` / `terms_of_service` | error | not read; the directory reads `privacyPolicyUrl` / `termsOfServiceUrl` |
| npx/bunx/pnpx/uvx, `uv tool run`, `pipx run`, `pnpm dlx`, `yarn dlx` without an exact version | error | portal blocks it as "Unpinned npx/uvx launcher" |
| `uv run` without `--locked` or `--frozen` | error | the pre-submission checklist requires a locked `uv run` |
| `${ENV_VAR}` in `.mcp.json` | error | claude.ai and Cowork users cannot set env vars; use `userConfig` and `${user_config.KEY}` |
| `${user_config.X}` with no `userConfig.X` | error | the value is never asked for |
| hooks.json without top-level `hooks` | error | portal holds the version |
| displayName, homepage, keywords, the four listing URLs | warn | the portal's Listing tab shows "No value" |
| secret-looking userConfig key without `sensitive: true` | warn | it would be stored in plain settings |

## Fixing

Fix in `plugin.json`, `.mcp.json`, README. Then run the checker again until it exits 0, and run
`claude plugin validate <folder>` as well (it checks the manifest schema, which this does not).
The directory picks up the change only after a push to the tracked branch and a new scan.

This skill does not change the portal and does not publish anything.
