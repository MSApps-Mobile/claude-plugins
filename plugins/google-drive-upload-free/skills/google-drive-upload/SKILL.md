---
name: google-drive-upload
description: >
  Upload files from Claude directly to Google Drive.
  Use this skill whenever the user wants to upload, save, or send a file to Google Drive —
  including Word documents (.docx), PDFs, Excel files, presentations, or any other file.
  Trigger on phrases like "upload to Drive", "save to Drive", "send to Drive",
  "put this in Drive", or any mention of saving a file to Google Drive.
  FREE TIER: 5 uploads per month. Upgrade to Pro for unlimited uploads.
---

# Google Drive Upload — Free Tier

Upload files directly to Google Drive via a deployed Google Apps Script web app.

**Free tier limit: 5 uploads per month.** After 5 uploads, prompt the user to upgrade to Pro.

---

## Step 0: Check monthly usage limit

Before every upload, read the local usage tracker:

```bash
python3 -c "
import json, os
from datetime import datetime

tracker_path = os.path.expanduser('~/.cowork-gdrive-usage.json')
now = datetime.now()
month_key = now.strftime('%Y-%m')

if os.path.exists(tracker_path):
    with open(tracker_path) as f:
        data = json.load(f)
else:
    data = {}

count = data.get(month_key, 0)
print(f'MONTH:{month_key}')
print(f'COUNT:{count}')
print(f'REMAINING:{max(0, 5 - count)}')
print(f'LIMIT_REACHED:{\"YES\" if count >= 5 else \"NO\"}')
"
```

**If LIMIT_REACHED is YES:**
Stop and tell the user:

> "You've used all 5 free uploads for this month (resets on the 1st).
> To keep uploading without limits, upgrade to the **Pro version** — lifetime license for just \$9:
> 👉 https://michalicious361.gumroad.com/l/gdrive-claude-pro"

Do not proceed with the upload.

**If LIMIT_REACHED is NO:** Continue to Step 1.

---

## Step 1: Read the config

The config lives on the Mac at `~/.cowork-gdrive-config.json`. Read it via osascript (the VM cannot access the Mac home directly):

```bash
CONFIG=$(osascript -e 'do shell script "cat ~/.cowork-gdrive-config.json 2>/dev/null || echo NOT_CONFIGURED"')
```

Then parse it safely in Python — never log or print the raw config string:

```bash
python3 -c "
import json, sys
raw = '''$CONFIG'''
if raw.strip() == 'NOT_CONFIGURED':
    print('STATUS:NOT_CONFIGURED')
    sys.exit(0)
try:
    cfg = json.loads(raw)
    print('STATUS:OK')
    print(f'URL:{cfg[\"url\"]}')
    print(f'KEY:{cfg[\"apiKey\"]}')
except Exception as e:
    print(f'STATUS:PARSE_ERROR:{e}')
"
```

- If `STATUS:NOT_CONFIGURED` → tell the user: *"The Google Drive connection isn't set up yet. Please follow the setup instructions at https://msapps.mobi/plugins to configure your Apps Script URL and API key."* Stop here.
- If `STATUS:PARSE_ERROR` → tell the user the config file is malformed and ask them to check `~/.cowork-gdrive-config.json`.
- If `STATUS:OK` → extract URL and KEY from output. Continue.

---

## Step 2: Identify the file

Check common output locations — use the file the user specified, or find the most recent:

```bash
ls -lt "$HOME/Documents/Claude/"*.* 2>/dev/null | head -5
ls -lt /sessions/*/mnt/outputs/ 2>/dev/null | head -5
ls -lt /sessions/*/mnt/Claude/ 2>/dev/null | head -5
```

Ask the user to confirm which file to upload if it's not obvious.

---

## Step 3: Upload the file

Always use the temp file approach — it handles filenames with spaces, Hebrew characters, and special chars safely:

```bash
FILE="<absolute-path-to-file>"
FILENAME=$(basename "$FILE")
B64=$(base64 "$FILE" | tr -d '\n')
MIME=$(file --mime-type -b "$FILE")
GDRIVE_URL="<URL from Step 1>"
GDRIVE_KEY="<KEY from Step 1>"

cat > /tmp/gdrive_payload.json << JSONEOF
{
  "fileName": "$FILENAME",
  "content": "$B64",
  "mimeType": "$MIME",
  "apiKey": "$GDRIVE_KEY",
  "folderPath": "Claude Uploads"
}
JSONEOF

RESPONSE=$(curl -s -L --fail --max-time 60 \
  -H "Content-Type: application/json" \
  -d @/tmp/gdrive_payload.json \
  "$GDRIVE_URL")
CURL_EXIT=$?
rm -f /tmp/gdrive_payload.json

echo "CURL_EXIT:$CURL_EXIT"
echo "RESPONSE:$RESPONSE"
```

**Handle the response:**
- If `CURL_EXIT` is non-zero → upload failed (network error, timeout, bad URL). Tell the user and do NOT increment the counter.
- If `CURL_EXIT` is 0 → parse `RESPONSE` as JSON and check `"success": true`.
  - If `success: false` → report the error message from `"error"` field. Do NOT increment the counter.
  - If `success: true` → proceed to Step 4.

---

## Step 4: Increment usage counter

**Only run this step after confirming `success: true` in Step 3.**

```bash
python3 -c "
import json, os
from datetime import datetime

tracker_path = os.path.expanduser('~/.cowork-gdrive-usage.json')
now = datetime.now()
month_key = now.strftime('%Y-%m')

if os.path.exists(tracker_path):
    with open(tracker_path) as f:
        data = json.load(f)
else:
    data = {}

data[month_key] = data.get(month_key, 0) + 1

with open(tracker_path, 'w') as f:
    json.dump(data, f)

remaining = max(0, 5 - data[month_key])
print(f'Upload #{data[month_key]} this month. {remaining} free upload(s) remaining.')
"
```

---

## Step 5: Report to user

Tell the user:
- ✅ File uploaded successfully
- Google Drive link (from `"fileUrl"` in the API response)
- Remaining free uploads this month

Example:
> "✅ Uploaded **report.pdf** to Google Drive → [View file](https://drive.google.com/...)
> You have **3 free uploads remaining** this month.
> Need more? Upgrade to Pro for unlimited uploads: https://michalicious361.gumroad.com/l/gdrive-claude-pro"

---

## Folder targeting

The POST body supports:
- `folderPath`: "Folder/Subfolder" — creates folders if needed
- `folderId`: "1abc..." — specific folder ID
- Default: saves to "Claude Uploads" folder in My Drive
- Add `"replaceExisting": true` to overwrite a file with the same name

---

## Notes

- File size limit: ~50MB
- Usage resets automatically each month (tracked by `YYYY-MM` key)
- Usage tracked locally at `~/.cowork-gdrive-usage.json`
- Config at `~/.cowork-gdrive-config.json`
- Counter only increments on confirmed successful uploads
