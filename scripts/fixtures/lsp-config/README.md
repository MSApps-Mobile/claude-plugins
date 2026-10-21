# lsp-config fixtures

Trello **czICbElh**, AC-2: *"today's main passes (kotlin-lsp and swift-lsp use
the right keys); a fixture with `startupTimeoutMs` fails the check."*

These are the inputs `scripts/check-lsp-config.py` is run against in CI by
`scripts/check-lsp-config.test.py`, **including the ones it must FAIL on**.
They live under `scripts/fixtures/`, so the plugin and marketplace validators
never treat them as real plugins.

| fixture | what it is | expected |
|---|---|---|
| `valid/` | one plugin with `.lsp.json` (via `lspServers` path), one with inline `lspServers` | **exit 0** — the known-POSITIVE |
| `startup-timeout-ms/` | `startupTimeoutMs` instead of `startupTimeout` | **exit 1** — the defect this card is about |
| `missing-required/` | a server with neither `command` nor `extensionToLanguage` | **exit 1** |
| `inline-unknown-key/` | an unknown key inside an inline `lspServers` in plugin.json | **exit 1** |
| `dangling-path/` | `lspServers` points at a file that is not there | **exit 1** |
| `bad-json/` | a `.lsp.json` that does not parse | **exit 1** as an `::error::`, never a traceback |
