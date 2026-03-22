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
or on-demand. Uploads each component as a separate file to stay under Apps Script's payload limit.

---

## What gets backed up

1. **Skills** — All Cowork skill definitions from the skills plugin directory
2. **Plugins** — Installed plugins, marketplace cache, plugin configs
3. **Claude Docs** — Scheduled tasks, session context files, MCP source code (split into 3 parts)
4. **Configs** — `claude_desktop_config.json` and connection config files

---

## Step 1: Read the Google Drive config

```applescript
do shell script "cat ~/.cowork-gdrive-config.json"
```

Parse the JSON to get `url` and `apiKey`. If the file doesn't exist, tell the user to run
`/backup-setup`.

---

## Step 2: Build backup components into /tmp/cowork-backup/

Create zips of each component. **Always exclude** `node_modules/`, `.git/`, `.next/`,
images (`*.png/*.jpg/*.jpeg/*.gif`), `*.pyc`, and `package-lock.json`.

### 2a: Skills

```applescript
do shell script "mkdir -p /tmp/cowork-backup && cd '/Users/michalshatz/Library/Application Support/Claude/local-agent-mode-sessions/skills-plugin/27490a98-e7a1-4f0e-aa81-0f24f38544c6/22a74de5-a2af-47b2-b30e-eab1eb168f03' && zip -r /tmp/cowork-backup/skills-backup.zip skills/ 2>&1 | tail -2 && echo done"
```

### 2b: Claude Documents folder — split into 3 parts

The ~/Documents/Claude/ folder contains large projects (opsAgent, gcal-mcp) that must be
split to stay under upload limits. Each part excludes node_modules, .git, .next, images.

**Part 1 — opsAgent (~6 MB):**
```applescript
do shell script "cd '/Users/michalshatz/Documents' && zip -r /tmp/cowork-backup/claude-docs-opsagent.zip Claude/opsAgent/ -x '*/node_modules/*' -x '*/.git/*' -x '*/.next/*' -x '*.pyc' -x '*.png' -x '*.jpg' -x '*.jpeg' -x '*.gif' -x '*/package-lock.json' 2>&1 | tail -1 && ls -lh /tmp/cowork-backup/claude-docs-opsagent.zip"
```

**Part 2 — gcal-mcp (~6 MB):**
```applescript
do shell script "cd '/Users/michalshatz/Documents' && zip -r /tmp/cowork-backup/claude-docs-gcalmcp.zip Claude/gcal-mcp/ -x '*/node_modules/*' -x '*/.git/*' -x '*.pyc' -x '*.png' -x '*.jpg' 2>&1 | tail -1 && ls -lh /tmp/cowork-backup/claude-docs-gcalmcp.zip"
```

**Part 3 — everything else (~2 MB):**
```applescript
do shell script "cd '/Users/michalshatz/Documents' && zip -r /tmp/cowork-backup/claude-docs-rest.zip Claude/ -x 'Claude/opsAgent/*' -x 'Claude/gcal-mcp/*' -x '*/node_modules/*' -x '*/.git/*' -x '*/.next/*' -x '*.pyc' -x '*.png' -x '*.jpg' -x '*.jpeg' -x '*.gif' -x '*/package-lock.json' 2>&1 | tail -1 && ls -lh /tmp/cowork-backup/claude-docs-rest.zip"
```

### 2c: Plugins

```applescript
do shell script "cd '/Users/michalshatz/Library/Application Support/Claude/local-agent-mode-sessions/22a74de5-a2af-47b2-b30e-eab1eb168f03/27490a98-e7a1-4f0e-aa81-0f24f38544c6' && zip -r /tmp/cowork-backup/plugins-backup.zip cowork_plugins/ 2>&1 | tail -2 && echo done"
```

### 2d: Config files

```applescript
do shell script "mkdir -p /tmp/cowork-backup/configs && cp '/Users/michalshatz/.cowork-gdrive-config.json' /tmp/cowork-backup/configs/ && cp '/Users/michalshatz/Library/Application Support/Claude/claude_desktop_config.json' /tmp/cowork-backup/configs/ && cd /tmp/cowork-backup && zip -r /tmp/cowork-backup/configs-backup.zip configs/ && echo done"
```

---

## Step 3: Upload each component to Google Drive

For each zip file in /tmp/cowork-backup/, upload individually using Python to build a base64 payload and curl to POST it.

Build the payload:
```python
import base64, json
with open('FILEPATH', 'rb') as f:
    b64 = base64.b64encode(f.read()).decode()
payload = {
    'fileName': 'FILENAME',
    'content': b64,
    'mimeType': 'application/zip',
    'apiKey': 'API_KEY_FROM_CONFIG',
    'folderPath': 'Cowork-Backups',
    'replaceExisting': True
}
with open('/tmp/upload_payload.json', 'w') as f:
    json.dump(payload, f)
```

Then upload with curl (timeout 180s):
```bash
curl -s -L -H 'Content-Type: application/json' -d @/tmp/upload_payload.json 'APPS_SCRIPT_URL_FROM_CONFIG'
```

Upload all 6 files one by one:
1. configs-backup.zip (tiny, good to verify connectivity)
2. plugins-backup.zip (~2 MB)
3. skills-backup.zip (~3 MB)
4. claude-docs-opsagent.zip (~6 MB)
5. claude-docs-gcalmcp.zip (~6 MB)
6. claude-docs-rest.zip (~2 MB)

Each should return `{"success": true}`.

---

## Step 4: Clean up

```bash
rm -rf /tmp/cowork-backup /tmp/upload_payload.json
```

---

## Step 5: Report

For each uploaded component, report file name, size, and Google Drive link.
If any upload failed, report the error.

---

## Important notes

- Upload as **SEPARATE files** (not one giant zip) to stay under Apps Script's ~50 MB payload limit
- Always use `replaceExisting: true` so each run overwrites the previous version
- `folderPath` must be `Cowork-Backups`
- **Always exclude**: `*/node_modules/*`, `*/.git/*`, `*/.next/*`, `*.pyc`, `*.png`, `*.jpg`, `*.jpeg`, `*.gif`, `*/package-lock.json`
- If any individual upload fails with 413, split that component further
- The 6 backup files in Drive: skills-backup.zip, claude-docs-opsagent.zip, claude-docs-gcalmcp.zip, claude-docs-rest.zip, plugins-backup.zip, configs-backup.zip
- Both accounts share the same Drive folder — each run replaces its own files
