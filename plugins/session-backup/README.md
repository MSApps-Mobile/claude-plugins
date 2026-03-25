# Session Backup — Claude Plugin by MSApps

Automated daily backups of your entire Cowork environment to Google Drive.

## What gets backed up

| Component | Description | Typical size |
|-----------|-------------|--------------|
| **Skills** | All Cowork skill definitions, references, and scripts | ~3 MB |
| **Plugins** | Installed plugins, marketplace cache, plugin configs | ~2 MB |
| **Claude Docs** | Scheduled tasks, session context files, MCP configs | ~8 MB |
| **Configs** | `claude_desktop_config.json` and connection configs | < 1 KB |

## How it works

1. **Download** the existing backup from Google Drive (if one exists)
2. **Build** fresh zips of each component from the local machine
3. **Merge** old + new content (new files win conflicts, old-only files preserved)
4. **Upload** each component as a separate zip to the `Cowork-Backups` folder on Drive

The merge strategy lets multiple accounts share the same Drive storage without overwriting each other.

## Split upload strategy

Google Apps Script has a ~10 MB base64 payload limit. The backup is split into 4 files:

- `cowork-skills-backup.zip`
- `cowork-plugins-backup.zip`
- `cowork-docs-backup.zip`
- `cowork-configs-backup.zip`

Each uploaded with `replaceExisting: true`.

## Size optimization

Excludes heavy regeneratable content to stay within upload limits:

- `node_modules/` — install from package.json
- `.git/` — version history
- `*.png`, `*.jpg` — screenshots
- `package-lock.json` — regeneratable

This typically reduces the docs backup from ~140 MB to ~8 MB.

## Installation

**Claude Code (CLI):**
```bash
/plugin marketplace add MSApps-Mobile/claude-plugins
/plugin install session-backup@msapps-plugins
```

**Cowork:** Search for "session-backup" in Settings → Plugins, or install from the [MSApps marketplace](https://github.com/MSApps-Mobile/claude-plugins).

## Requirements

- **Google Drive Upload connector** — Apps Script web app (see CONNECTORS.md)
- **Config file** at `~/.cowork-gdrive-config.json`
- One of the following:
  - **Claude Code** (CLI) — runs bash commands directly on your Mac
  - **Claude Cowork** — uses osascript to access host machine files

## Setup

1. Deploy the Apps Script (see [CONNECTORS.md](CONNECTORS.md))
2. Create config: `~/.cowork-gdrive-config.json` with `url` and `apiKey`
3. Set up as a Cowork scheduled task for daily runs

## Commands

| Command | Description |
|---------|-------------|
| `/backup-now` | Run an immediate backup |
| `/backup-setup` | Configure the backup connection |
| `/backup-status` | Check last backup status |

## License

MIT — Free and open source.

## Author

**MSApps** — [msapps.mobi](https://msapps.mobi) | [michal@msapps.mobi](mailto:michal@msapps.mobi)
