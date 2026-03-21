---
name: backup-now
description: Run an immediate backup of all Cowork data to Google Drive
---

Run the full backup workflow now:

1. Read the Google Drive config from `~/.cowork-gdrive-config.json`
2. Build zips of skills, plugins, docs, and configs
3. Upload each to the `Cowork-Backups` folder on Google Drive
4. Report results with Drive links

Use the `session-backup` skill for the full implementation.
