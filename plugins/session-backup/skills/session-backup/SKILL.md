---
name: daily-cowork-backup
description: גיבוי יומי של תיקיות הסקילס, המשימות המתוזמנות והקונפיגורציות לגוגל דרייב
---

Back up all Cowork-related folders to Google Drive.

> **Environment note:** This skill works in both Claude Code and Cowork. In Claude Code, bash commands run directly on the Mac. In Cowork, osascript is used to bridge the VM to the host machine. The instructions below provide both methods where needed.

## Step 1: Read the Google Drive upload config

**In Claude Code:**
```bash
cat ~/.cowork-gdrive-config.json
```

**In Cowork:**
```applescript
do shell script "cat '/Users/michalshatz/.cowork-gdrive-config.json'"
```

Parse to get `url` and `apiKey`.

## Step 2: Flush debug screenshots
Delete temporary debug screenshots from ~/Documents/Claude/ before building the backup.
These are not needed for recovery and waste space.

**In Claude Code:**
```bash
find ~/Documents/Claude -maxdepth 1 -type f \( -name "*.png" -o -name "*.jpg" -o -name "*.jpeg" -o -name "*.gif" \) -delete && echo "Screenshots flushed"
```

**In Cowork:**
```applescript
do shell script "find '/Users/michalshatz/Documents/Claude' -maxdepth 1 -type f \\( -name '*.png' -o -name '*.jpg' -o -name '*.jpeg' -o -name '*.gif' \\) -delete && echo 'Screenshots flushed'"
```

## Step 3: Build backup content into /tmp/cowork-backup/

**All zips must exclude**: `*/node_modules/*`, `*/.git/*`, `*/.next/*`, `*.pyc`, `*.png`, `*.jpg`, `*.jpeg`, `*.gif`, `*/package-lock.json`

### Locating directories

The paths to skills, plugins, and docs directories depend on the environment:

**In Claude Code** — check for the standard Cowork paths on the host Mac:
```bash
# Skills directory (find dynamically)
SKILLS_DIR=$(find ~/Library/Application\ Support/Claude/local-agent-mode-sessions -name "skills" -type d 2>/dev/null | head -1)

# Plugins directory (find dynamically)
PLUGINS_DIR=$(find ~/Library/Application\ Support/Claude/local-agent-mode-sessions -name "cowork_plugins" -type d 2>/dev/null | head -1)

# Docs directory
DOCS_DIR=~/Documents/Claude
```

**In Cowork** — use the known paths via osascript (same as the original skill).

### 3a: Skills
```bash
mkdir -p /tmp/cowork-backup
cd "$SKILLS_DIR/.." && zip -r /tmp/cowork-backup/skills-backup.zip skills/ 2>&1 | tail -2 && echo done
```

### 3b: Claude Documents folder
First try as ONE zip (with all exclusions). If the resulting base64 is under ~45MB, upload as one file.
```bash
cd ~/Documents && zip -r /tmp/cowork-backup/claude-docs-backup.zip Claude/ \
  -x '*/node_modules/*' -x '*/.git/*' -x '*/.next/*' -x '*.pyc' \
  -x '*.png' -x '*.jpg' -x '*.jpeg' -x '*.gif' -x '*/package-lock.json' \
  2>&1 | tail -1 && ls -lh /tmp/cowork-backup/claude-docs-backup.zip
```

**If the zip is over 30MB** (which means base64 will be over 40MB and may hit 413), split into 3 parts instead:
- Part 1: `Claude/opsAgent/` -> claude-docs-opsagent.zip
- Part 2: `Claude/gcal-mcp/` -> claude-docs-gcalmcp.zip
- Part 3: everything else -> claude-docs-rest.zip

Each part uses the same exclusion flags.

### 3c: Plugins
```bash
cd "$PLUGINS_DIR/.." && zip -r /tmp/cowork-backup/plugins-backup.zip cowork_plugins/ 2>&1 | tail -2 && echo done
```

### 3d: Config files
```bash
mkdir -p /tmp/cowork-backup/configs
cp ~/.cowork-gdrive-config.json /tmp/cowork-backup/configs/ 2>/dev/null
cp ~/Library/Application\ Support/Claude/claude_desktop_config.json /tmp/cowork-backup/configs/ 2>/dev/null
cd /tmp/cowork-backup && zip -r /tmp/cowork-backup/configs-backup.zip configs/ && echo done
```

## Step 4: Upload to Google Drive

For each zip file in /tmp/cowork-backup/, build a base64 payload and upload:

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

Then upload with curl (timeout 180s). Each should return `{"success": true}`.

**If any upload fails with 413**: split that component into smaller parts and retry.

## Step 5: Clean up
```bash
rm -rf /tmp/cowork-backup /tmp/upload_payload.json
```

## Step 6: Report
List all uploaded files with their Drive links. If any failed, report the error.

## Important notes
- Try uploading docs as ONE file first; only split if it exceeds ~30MB or gets a 413 error
- Always flush screenshots before building the backup (Step 2)
- Always use `replaceExisting: true` so each run overwrites the previous backup
- folderPath must be `Cowork-Backups`
- ALWAYS exclude: `*/node_modules/*`, `*/.git/*`, `*/.next/*`, `*.pyc`, `*.png`, `*.jpg`, `*.jpeg`, `*.gif`, `*/package-lock.json`
