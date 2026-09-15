# marketplace-coverage fixtures

Trello **1zBkhSZm**, AC-3: *"Pair it with a negative control — add a fixture that
omits one entry and prove the check reds — or it is a guard that has only ever
seen passing input."*

These are the inputs `scripts/check-marketplace-coverage.py` is run against in
CI, **including the ones it must FAIL on**. A guard whose red branch is never
executed is a guard nobody has measured.

| fixture | what it is | expected |
|---|---|---|
| `agrees/` | one plugin, one manifest entry | **exit 0** — the known-POSITIVE |
| `missing-entry/` | two plugin dirs, one manifest entry, no exclusion recorded | **exit 1** — the defect this card is about |
| `dangling-source/` | a manifest entry pointing at a directory that is not there | **exit 1** — users install nothing |
| `published-but-excluded/` | the dir IS in the manifest and STILL in `PENDING_DISPOSITION` | **exit 1** — the exclusion outlived the decision |
| `object-source/` | a manifest `source` that is an object, not a path | **exit 1**, and exactly ONE problem — never "plugins/'repo': 'x'}/ does not exist" |
| `no-manifest/` | plugins, no `.claude-plugin/marketplace.json` | **exit 1** as an `::error::`, never a traceback |
| `bad-json/` | a manifest that does not parse | **exit 1** as an `::error::`, never a traceback |

`--min-dirs` is not exposed on the CLI, so these fixtures are run through the
`audit()` function directly by `scripts/check-marketplace-coverage.test.py`,
which passes a floor of 1. The production floor stays at 20 — a vacuity floor
that a fixture can lower is not a floor.
