---
name: google-drive-upload
description: >
  Upload files from Claude directly to Google Drive.
  Use this skill whenever the user wants to upload, save, or send a file to Google Drive —
  including Word documents (.docx), PDFs, Excel files, presentations, or any other file.
  Trigger on phrases like "upload to Drive", "save to Drive", "send to Drive",
  "put this in Drive", or any mention of saving a file to Google Drive.
  Completely free — unlimited uploads, no restrictions.
---

# Google Drive Upload

Upload files directly to Google Drive via a deployed Google Apps Script web app.

**Completely free — unlimited uploads, no restrictions.**

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
except Exception as e:
    print(f'STATUS:PARSE_ERROR:{e}')
"
```

- If `STATUS:NOT_CONFIGURED` → tell the user: *"The Google Drive connection isn't set up yet. Please follow the setup instructions at https://msapps.mobi/plugins to configure your Apps Script URL."* Stop here.
- If `STATUS:PARSE_ERROR` → tell the user the config file is malformed and ask them to check `~/.cowork-gdrive-config.json`.
- If `STATUS:OK` → extract URL from output. Continue.

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

cat > /tmp/gdrive_payload.json << JSONEOF
{
  "fileName": "$FILENAME",
  "content": "$B64",
  "mimeType": "$MIME",
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
- If `CURL_EXIT` is non-zero → upload failed (network error, timeout, bad URL). Tell the user.
- If `CURL_EXIT` is 0 → parse `RESPONSE` as JSON and check `"success": true`.
  - If `success: false` → report the error message from `"error"` field.
  - If `success: true` → proceed to Step 4.

---

## Step 4: Report to user

Tell the user:
- File uploaded successfully
- Google Drive link (from `"fileUrl"` in the API response)

Example:
> "Uploaded **report.pdf** to Google Drive → [View file](https://drive.google.com/...)"

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
- Config at `~/.cowork-gdrive-config.json`
- No upload limits — completely free
