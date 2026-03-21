# Backup Workflow Reference

## Architecture

```
Mac (host machine)
  ├── Skills directory      → zip → cowork-skills-backup.zip
  ├── ~/Documents/Claude/   → zip → cowork-docs-backup.zip (excl. node_modules, images)
  ├── Plugins directory     → zip → cowork-plugins-backup.zip
  └── Config files          → zip → cowork-configs-backup.zip
                                      │
                                      ▼
                              Google Apps Script
                                      │
                                      ▼
                            Google Drive: Cowork-Backups/
                              ├── cowork-skills-backup.zip
                              ├── cowork-plugins-backup.zip
                              ├── cowork-docs-backup.zip
                              └── cowork-configs-backup.zip
```

## Merge strategy

Two accounts may share the same Drive storage. To avoid one overwriting the other:

1. **Download** the existing backup (if available)
2. **Extract** to a base directory
3. **Copy** new content on top (new files win conflicts)
4. **Upload** the merged result

This ensures files from both accounts accumulate in one backup.

## Size management

| Component | Raw size | After exclusions | Base64 payload |
|-----------|----------|------------------|----------------|
| Skills | ~10 MB | ~3.3 MB | ~4.5 MB |
| Plugins | ~4 MB | ~1.9 MB | ~2.6 MB |
| Docs | ~140 MB | ~7.7 MB | ~10.7 MB |
| Configs | < 10 KB | < 2 KB | < 2 KB |

Apps Script payload limit is ~50 MB per request. Split uploads keep each well under the limit.

## Exclusions

These patterns are excluded from the docs backup to reduce size:

- `node_modules/` — reinstallable dependencies
- `.git/` — version control history
- `*.png`, `*.jpg`, `*.jpeg` — screenshots (not critical for recovery)
- `package-lock.json` — regeneratable from package.json

## Error handling

| Error | Cause | Recovery |
|-------|-------|----------|
| 413 Entity Too Large | Payload exceeds Apps Script limit | Split into smaller uploads |
| Download returns JSON | GET download endpoint not supported | Skip merge, upload new only |
| osascript timeout | Large file processing | Increase timeout or split files |
| curl network error | Connectivity issue | Retry once, then report failure |

## Scheduling

Set up as a Cowork scheduled task to run daily. Each run is idempotent — safe to run
multiple times without side effects.
