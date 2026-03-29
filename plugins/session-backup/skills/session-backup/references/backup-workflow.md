# Backup Workflow Reference

## Architecture

```
Mac (host machine)
  ├── Skills directory      → zip → skills-backup.zip (~3 MB)
  ├── ~/Documents/Claude/   → split into 3 zips (excl. node_modules, images, .git)
  │     ├── gcal-mcp/       → claude-docs-gcalmcp.zip (~6 MB)
  │     └── everything else → claude-docs-rest.zip (~2 MB)
  ├── Plugins directory     → zip → plugins-backup.zip (~2 MB)
  └── Config files          → zip → configs-backup.zip (<1 KB)
                                    │
                                    ▼ (6 separate uploads)
                            Google Apps Script
                                    │
                                    ▼
                          Google Drive: Cowork-Backups/
                            ├── skills-backup.zip
                            ├── plugins-backup.zip
                            ├── claude-docs-gcalmcp.zip
                            ├── claude-docs-rest.zip
                            └── configs-backup.zip
```

## Why split uploads?

Apps Script has a ~50 MB payload limit per request. The Claude Docs folder alone can be
60+ MB even after excluding node_modules (due to screenshots and build artifacts).
By splitting into 6 component files, each upload stays well under the limit.

## Size management

| Component | Raw size | After exclusions | Base64 payload |
|-----------|----------|------------------|----------------|
| Skills | ~10 MB | ~3.3 MB | ~4.5 MB |
| Plugins | ~4 MB | ~1.9 MB | ~2.6 MB |
| Docs: gcal-mcp | ~159 MB | ~5.5 MB | ~7.7 MB |
| Docs: rest | ~5 MB | ~2 MB | ~2.8 MB |
| Configs | < 10 KB | < 2 KB | < 2 KB |

## Exclusions

These patterns are ALWAYS excluded from the docs backup:

- `node_modules/` — reinstallable dependencies (biggest size saver: 500+ MB)
- `.git/` — version control history
- `.next/` — Next.js build cache
- `*.png`, `*.jpg`, `*.jpeg`, `*.gif` — screenshots (temporary debug images, not critical)
- `*.pyc` — Python bytecode
- `package-lock.json` — regeneratable from package.json

## Error handling

| Error | Cause | Recovery |
|-------|-------|----------|
| 413 Entity Too Large | Payload exceeds Apps Script limit | Split the component further |
| osascript timeout | Large file processing | Increase timeout or split files |
| curl network error | Connectivity issue | Retry once, then report failure |

## Scheduling

Set up as a Cowork scheduled task to run daily. Each run is idempotent — safe to run
multiple times without side effects. Uses `replaceExisting: true` so each upload
overwrites the previous version.
