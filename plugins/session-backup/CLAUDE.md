# Session Backup

Automated daily backups of the entire Cowork environment to Google Drive. Backs up skills, plugins, Claude docs, and configs with smart merge strategy.

## Available Commands

- `/backup-now` — Run an immediate backup
- `/backup-setup` — Configure backup settings and scheduling
- `/backup-status` — Check last backup time and status

## What Gets Backed Up

- **Skills** (~3 MB) → `cowork-skills-backup.zip`
- **Plugins** (~2 MB) → `cowork-plugins-backup.zip`
- **Claude Docs** (~8 MB) → `cowork-docs-backup.zip`
- **Configs** (<1 KB) → `cowork-configs-backup.zip`

Split into 4 separate zips to stay under the 10 MB base64 upload limit.

## Merge Strategy

Download existing backup → build fresh → merge (new files win conflicts, old files preserved) → upload. This supports multi-account setups sharing the same Drive storage.

## Exclusions

Automatically excludes: `node_modules/`, `.git/`, images, `package-lock.json`. This reduces backup size from ~140 MB to ~8 MB.

## Configuration

Requires:
- Google Drive Upload connector installed and configured
- Config file at `~/.cowork-gdrive-config.json`

## Common Workflows

- "Back up my session" → runs /backup-now
- "Set up daily backups" → configures scheduled task
- "When was my last backup?" → runs /backup-status
- "Restore from backup" → downloads and extracts from Drive

## Best Practices

- Run a backup before making major changes to skills or plugins
- Use /backup-status to verify backups are running on schedule
- The merge strategy means you never lose old files — but new versions always win
- Keep the Google Drive Upload config current if you change Google accounts
