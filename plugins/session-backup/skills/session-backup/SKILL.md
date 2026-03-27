---
name: daily-cowork-backup
description: גיבוי יומי של תיקיות הסקילס, המשימות המתוזמנות והקונפיגורציות לגוגל דרייב
---

Back up all Cowork-related folders to Google Drive.

> **Session path note:** Cowork VM session names change every run. Do NOT hardcode a session name like `loving-gracious-allen`. Instead, discover the active session dynamically (Step 1).

---

## Step 1: Discover session path and read GDrive config

```python
import json, os, glob, sys

# Discover the active session that has the credentials file
candidates = glob.glob('/sessions/*/mnt/Claude/credentials/cowork-gdrive-config.json')
if not candidates:
    print('STATUS:NOT_FOUND')
    sys.exit(1)

cfg_path = candidates[0]
session_mnt = cfg_path.replace('/Claude/credentials/cowork-gdrive-config.json', '')  # e.g. /sessions/abc-xyz/mnt

with open(cfg_path) as f:
    cfg = json.load(f)

print('STATUS:OK')
print(f'SESSION_MNT:{session_mnt}')
print(f'URL:{cfg["url"]}')
print(f'APIKEY:{cfg["apiKey"]}')
```

If STATUS is NOT_FOUND, stop and report:
> Config file missing. On your Mac, run once:
> `cp ~/.cowork-gdrive-config.json ~/Documents/Claude/credentials/cowork-gdrive-config.json`

---

## Step 2: Flush debug screenshots

Delete temporary debug screenshots from the Claude docs folder (top level only).
Use the `SESSION_MNT` discovered in Step 1:

```bash
find '{SESSION_MNT}/Claude' -maxdepth 1 -type f \( -name '*.png' -o -name '*.jpg' -o -name '*.jpeg' -o -name '*.gif' \) -delete && echo 'Screenshots flushed'
```

(Failure due to file permissions is non-fatal — continue anyway.)

---

## Step 3: Build backup zips into /tmp/cowork-backup/

**All zips must exclude**: `*/node_modules/*`, `*/.git/*`, `*/.next/*`, `*.pyc`, `*.png`, `*.jpg`, `*.jpeg`, `*.gif`, `*/package-lock.json`

Use `SESSION_MNT` from Step 1 for all paths.

### 3a: Skills

```bash
mkdir -p /tmp/cowork-backup
cd '{SESSION_MNT}/.claude' && zip -r /tmp/cowork-backup/skills-backup.zip skills/ \
  -x '*/node_modules/*' -x '*/.git/*' -x '*/.next/*' -x '*.pyc' \
  -x '*.png' -x '*.jpg' -x '*.jpeg' -x '*.gif' -x '*/package-lock.json' \
  2>&1 | tail -2 && ls -lh /tmp/cowork-backup/skills-backup.zip
```

### 3b: Claude Documents folder

First try as ONE zip. If under 30MB, upload as one file. If over 30MB, split into 3 parts.

```bash
cd '{SESSION_MNT}' && zip -r /tmp/cowork-backup/claude-docs-backup.zip Claude/ \
  -x '*/node_modules/*' -x '*/.git/*' -x '*/.next/*' -x '*.pyc' \
  -x '*.png' -x '*.jpg' -x '*.jpeg' -x '*.gif' -x '*/package-lock.json' \
  2>&1 | tail -1 && ls -lh /tmp/cowork-backup/claude-docs-backup.zip
```

**If the zip is over 30MB**, delete it and split instead:
- Part 1: `Claude/opsAgent/` → claude-docs-opsagent.zip
- Part 2: `Claude/gcal-mcp/` → claude-docs-gcalmcp.zip
- Part 3: everything else in Claude/ → claude-docs-rest.zip

Each part uses the same exclusion flags.

### 3c: Config files

```bash
mkdir -p /tmp/cowork-backup/configs
cp '{SESSION_MNT}/Claude/credentials/cowork-gdrive-config.json' /tmp/cowork-backup/configs/
cd /tmp/cowork-backup && zip -r /tmp/cowork-backup/configs-backup.zip configs/ && echo done
```

---

## Step 4: Upload to Google Drive via Desktop Commander

> **Why Desktop Commander?** The Cowork VM proxy blocks outbound connections to `script.google.com`. Uploads must run on the Mac side. We do this by:
> 1. Copying zip files to the mounted Claude folder (which is the Mac's `~/Documents/Claude/`)
> 2. Writing a Python upload script there
> 3. Using Desktop Commander's `start_process` to run it natively on the Mac

### 4a: Stage files to mounted folder

```python
import shutil, os

session_mnt = 'SESSION_MNT_FROM_STEP1'
staging = f'{session_mnt}/Claude/.backup-tmp'
os.makedirs(staging, exist_ok=True)

backup_dir = '/tmp/cowork-backup'
for fname in os.listdir(backup_dir):
    if fname.endswith('.zip'):
        shutil.copy(os.path.join(backup_dir, fname), os.path.join(staging, fname))

print(f'Staged to: {staging}')
```

### 4b: Write the upload script to staging

Write this Python script to `{staging}/do_upload.py` (substitute real url and api_key values):

```python
import base64, json, subprocess, os

url = 'URL_FROM_STEP1'
api_key = 'APIKEY_FROM_STEP1'

staging = os.path.expanduser('~/Documents/Claude/.backup-tmp')

for fname in sorted(os.listdir(staging)):
    if not fname.endswith('.zip'):
        continue
    fpath = os.path.join(staging, fname)
    print(f'Uploading {fname} ({os.path.getsize(fpath) // 1024}KB)...')
    with open(fpath, 'rb') as f:
        b64 = base64.b64encode(f.read()).decode()
    payload = {
        'fileName': fname,
        'content': b64,
        'mimeType': 'application/zip',
        'apiKey': api_key,
        'folderPath': 'Cowork-Backups',
        'replaceExisting': True
    }
    payload_path = '/tmp/upload_payload.json'
    with open(payload_path, 'w') as f:
        json.dump(payload, f)
    result = subprocess.run(
        ['curl', '-s', '-X', 'POST', url,
         '-H', 'Content-Type: application/json',
         '--data', f'@{payload_path}',
         '--max-time', '180'],
        capture_output=True, text=True
    )
    print(f'{fname}: {result.stdout[:300]}')
    if payload_path and os.path.exists(payload_path):
        os.remove(payload_path)
```

### 4c: Execute via Desktop Commander

Use the `mcp__Desktop_Commander__start_process` tool to run on the Mac:

```
command: python3 ~/Documents/Claude/.backup-tmp/do_upload.py
```

Then use `mcp__Desktop_Commander__read_process_output` to read the results.

**If any upload fails with 413**: split that zip into smaller parts and retry.

---

## Step 5: Clean up

```bash
rm -rf /tmp/cowork-backup /tmp/upload_payload.json
```

Also remove the staging area from the mounted folder:
```bash
rm -rf '{SESSION_MNT}/Claude/.backup-tmp'
```

---

## Step 6: Report

List all uploaded files with their Drive links (from the JSON responses). Note which components were backed up and any that were skipped.

---

## Important notes
- **Never hardcode the session path** — session names change every run. Always discover dynamically.
- Try uploading docs as ONE file first; only split if it exceeds ~30MB or gets a 413 error
- Always flush screenshots before building the backup (Step 2) — failure is non-fatal
- Always use `replaceExisting: true` so each run overwrites the previous backup
- `folderPath` must be `Cowork-Backups`
- ALWAYS exclude: `*/node_modules/*`, `*/.git/*`, `*/.next/*`, `*.pyc`, `*.png`, `*.jpg`, `*.jpeg`, `*.gif`, `*/package-lock.json`
- Plugins folder (`~/Library/Application Support/Claude/.../cowork_plugins/`) is NOT mounted in the VM — skip silently and note in the report
- Upload must go via **Desktop Commander** (Mac-side) — the VM proxy blocks `script.google.com`
