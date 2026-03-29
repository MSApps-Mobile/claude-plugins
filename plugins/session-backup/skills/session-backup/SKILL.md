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

> **Why Desktop Commander?** The VM filesystem mount is read-only for deletes — use Desktop Commander to run the delete natively on the Mac.

Use `mcp__Desktop_Commander__start_process` with:

```
command: find ~/Documents/Claude -maxdepth 1 -type f \( -name '*.png' -o -name '*.jpg' -o -name '*.jpeg' -o -name '*.gif' \) -delete && echo 'Screenshots flushed'
timeout_ms: 15000
```

(Failure is non-fatal — continue anyway.)

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
- Part 2: `Claude/gcal-mcp/` → claude-docs-gcalmcp.zip
- Part 3: everything else in Claude/ → claude-docs-rest.zip

Each part uses the same exclusion flags.

### 3c: Plugins folder

The `.remote-plugins` folder is mounted read-only at `{SESSION_MNT}/.remote-plugins` — zip it directly from the VM:

```bash
cd '{SESSION_MNT}' && zip -r /tmp/cowork-backup/plugins-backup.zip .remote-plugins/ \
  -x '*.png' -x '*.jpg' -x '*.jpeg' -x '*.gif' \
  2>&1 | tail -1 && ls -lh /tmp/cowork-backup/plugins-backup.zip
```

### 3d: Config files

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

> **Why the two-step POST→GET?** Google Apps Script returns a 302 redirect to `script.googleusercontent.com`. curl's `-L` flag converts POST→GET for 302s, but the redirect endpoint still returns HTML. The fix: POST without following redirect, capture `Location` header, then GET that URL directly.

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
api_key = cfg["apiKey"]  # loaded from ~/.cowork-gdrive-config.json

staging = os.path.expanduser('~/Documents/Claude/.backup-tmp')

for fname in sorted(os.listdir(staging)):
    if not fname.endswith('.zip'):
        continue
    fpath = os.path.join(staging, fname)
    size_kb = os.path.getsize(fpath) // 1024
    print(f'Uploading {fname} ({size_kb}KB)...')
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

    # Step 1: POST without following redirect — capture Location header
    r1 = subprocess.run(
        ['curl', '-s', '-D', '-', '--max-redirs', '0',
         '-X', 'POST', url,
         '-H', 'Content-Type: application/json',
         '--data', f'@{payload_path}',
         '--max-time', '120'],
        capture_output=True, text=True
    )
    if os.path.exists(payload_path):
        os.remove(payload_path)

    # Extract Location header from response headers
    location = None
    for line in r1.stdout.splitlines():
        if line.lower().startswith('location:'):
            location = line.split(':', 1)[1].strip()
            break

    if not location:
        print(f'ERROR: No redirect location for {fname}')
        print(r1.stdout[:300])
        continue

    # Step 2: GET the redirect URL to retrieve the JSON response
    r2 = subprocess.run(
        ['curl', '-s', location, '--max-time', '30'],
        capture_output=True, text=True
    )
    print(f'{fname}: {r2.stdout[:300]}')

print('Upload complete.')
```

### 4c: Execute via Desktop Commander

Start the process (output will be slow — capture to file for reliability):

```
command: python3 ~/Documents/Claude/.backup-tmp/do_upload.py > ~/Documents/Claude/.backup-tmp/upload_result.txt 2>&1; echo "EXIT:$?" >> ~/Documents/Claude/.backup-tmp/upload_result.txt
timeout_ms: 15000
```

Then poll `read_process_output` until `✅ Process completed` appears (may take 60–180s for large files).

Finally, read the result:
```
command: cat ~/Documents/Claude/.backup-tmp/upload_result.txt
timeout_ms: 10000
```

**If any upload fails with 413**: split that zip into smaller parts and retry.

---

## Step 5: Clean up

```bash
rm -rf /tmp/cowork-backup /tmp/upload_payload.json
```

Also remove the staging area from the mounted folder via Desktop Commander:
```
command: rm -rf ~/Documents/Claude/.backup-tmp && echo 'Mac staging cleaned'
timeout_ms: 10000
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
- **Plugins ARE mounted** at `{SESSION_MNT}/.remote-plugins` (read-only) — include in backup as `plugins-backup.zip`
- **Screenshot flush must use Desktop Commander** (Mac-side) — VM filesystem mount blocks deletes
- **Upload must use two-step POST→GET** — Apps Script redirects with 302; curl `-L` alone lands on wrong page
- Upload must go via **Desktop Commander** (Mac-side) — the VM proxy blocks `script.google.com`
