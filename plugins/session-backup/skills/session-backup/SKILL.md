---
name: session-backup
description: >
  Automated backup of Cowork skills, scheduled tasks, plugins, and configs to Google Drive.
  Use this skill when the user asks to back up their Cowork environment, save their setup,
  or run the daily backup manually. Triggers on: "backup", "back up my skills",
  "save my setup", "backup to drive", "run backup", or any request to preserve Cowork data.
---

# Session Backup

Back up all Cowork-related content to Google Drive. Designed to run as a daily scheduled task
or on-demand.

---

## What gets backed up

1. **Skills** — All Cowork skill definitions from the skills plugin directory
2. **Plugins** — Installed plugins, marketplace cache, plugin configs
3. **Claude Docs** — Scheduled tasks, session context files, MCP source code
4. **Configs** — `claude_desktop_config.json` and connection config files

---

## Step 1: Read the Google Drive config

```applescript
do shell script "cat ~/.cowork-gdrive-config.json"
```

Parse the JSON to get `url` and `apiKey`. If the file doesn't exist, tell the user to run
`/backup-setup`.

---

## Step 2: Try downloading the existing backup

Attempt to download the current backup from Drive for merge:

```applescript
with timeout of 120 seconds
  do shell script "curl -s -L 'APPS_SCRIPT_URL?action=download&fileName=cowork-full-backup-latest.zip&apiKey=API_KEY' -o /tmp/cowork-existing-backup.zip 2>&1; echo exit:$?"
end timeout
```

If the download returns a valid zip, extract to `/tmp/cowork-base/` for merging.
If not (JSON response or error), proceed with new content only.

---

## Step 3: Build new backup content

Create zips of each component. **Exclude** `node_modules/`, `.git/`, images (`*.png/*.jpg`),
and `package-lock.json` to keep sizes manageable.

### 3a: Skills
Zip the skills directory from the Cowork skills plugin path.

### 3b: Claude Docs
Zip `~/Documents/Claude/` excluding heavy directories:
```bash
find Claude/ -not -path '*/node_modules/*' -not -path '*/.git/*' \
  -not -name '*.png' -not -name '*.jpg' -not -name 'package-lock.json' \
  -type f | zip /tmp/cowork-new/claude-docs-backup.zip -@
```

### 3c: Plugins
Zip the cowork_plugins directory.

### 3d: Configs
Copy `claude_desktop_config.json` and `~/.cowork-gdrive-config.json`.

---

## Step 4: Merge old and new

Use Python to merge: old backup provides the base, new content overlays (new wins conflicts):

```python
import os, shutil

base = '/tmp/cowork-base'      # Old backup (if any)
new_dir = '/tmp/cowork-new'    # Fresh content
merged = '/tmp/cowork-merged'

os.makedirs(merged, exist_ok=True)

# Copy old backup first
if os.path.exists(base) and os.listdir(base):
    shutil.copytree(base, merged, dirs_exist_ok=True)

# Overlay new content (new files win)
for fname in os.listdir(new_dir):
    src = os.path.join(new_dir, fname)
    dst = os.path.join(merged, fname)
    if os.path.isdir(src):
        shutil.copytree(src, dst, dirs_exist_ok=True)
    else:
        shutil.copy2(src, dst)
```

---

## Step 5: Upload to Google Drive

**Split upload** — upload each component separately (Apps Script has ~10 MB payload limit):

For each zip file, build a base64-encoded JSON payload and POST to the Apps Script URL:

```json
{
  "fileName": "cowork-skills-backup.zip",
  "content": "<base64>",
  "mimeType": "application/zip",
  "apiKey": "API_KEY",
  "folderPath": "Cowork-Backups",
  "replaceExisting": true
}
```

Upload order: configs (tiny) → plugins (~2 MB) → skills (~3 MB) → docs (~8 MB).

Check each response for `"success": true` before proceeding.

---

## Step 6: Clean up

Remove all temp files:
```bash
rm -rf /tmp/cowork-base /tmp/cowork-new /tmp/cowork-merged \
  /tmp/cowork-existing-backup.zip /tmp/cowork-full-backup.zip \
  /tmp/upload_*.json
```

---

## Step 7: Report

For each uploaded component, report:
- File name
- Size
- Google Drive link (from `fileUrl` in the response)

If any upload failed, report the error.

---

## Important notes

- Always use `replaceExisting: true` so each run overwrites the previous backup
- The merge strategy preserves files that exist only in the old backup
- If the download endpoint isn't supported, skip merge and upload new content only
- `folderPath` must be `Cowork-Backups`
- Exclude `node_modules/`, `.git/`, images, and lockfiles to keep uploads small
- All uploads go to the same Drive folder — both accounts can contribute
