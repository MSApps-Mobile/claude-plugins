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

`--min-dirs` is not exposed on the CLI, so these fixtures are run through the
`audit()` function directly by `scripts/check-marketplace-coverage.test.py`,
which passes a floor of 1. The production floor stays at 20 — a vacuity floor
that a fixture can lower is not a floor.
