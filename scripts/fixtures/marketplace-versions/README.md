# marketplace-versions fixtures

Trello **okOoGKTA**, AC-3: the guard must be proved RED on a deliberately mismatched
fixture before it is trusted green. These are the inputs `scripts/marketplace-versions.py`
runs against in `scripts/marketplace-versions.test.py`.

| fixture | what it is | expected |
|---|---|---|
| `agrees/` | manifest and plugin.json both say 1.0.0 | **exit 0**, the known-positive |
| `drifted/` | manifest lists 0.1.0, plugin.json ships 0.2.2 | **exit 1**, the defect this card is about |
| `unreadable-plugin-json/` | a manifest entry whose plugin has no plugin.json | **exit 1** as an `::error::`, never a traceback |
