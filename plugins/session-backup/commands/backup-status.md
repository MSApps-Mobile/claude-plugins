---
name: backup-status
description: Check the status of the last backup
---

Check backup health:

1. **Config**: Verify `~/.cowork-gdrive-config.json` exists and is valid
2. **Drive check**: List files in the `Cowork-Backups` folder on Google Drive
3. **Report**:
   - Last backup date (from file modification times on Drive)
   - Files present and their sizes
   - Any missing components (skills, plugins, docs, configs)
   - Whether the scheduled task is active
