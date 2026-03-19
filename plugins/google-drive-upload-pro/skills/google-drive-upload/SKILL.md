---
name: google-drive-upload
description: >
  Upload files from Claude directly to Google Drive — Pro License (unlimited uploads).
  Use this skill whenever the user wants to upload, save, or send a file to Google Drive —
  including Word documents (.docx), PDFs, Excel files, presentations, or any other file.
  Trigger on phrases like "upload to Drive", "save to Drive", "send to Drive",
  "put this in Drive", "שמור בדרייב", "תעלה לדרייב", or any mention of saving a file to Google Drive.
  Also trigger proactively at the end of workflows when a file has just been created.
---

# Google Drive Upload — Pro License

Upload files directly to Google Drive via a deployed Google Apps Script web app.
**Unlimited uploads — no monthly limits.**

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
  "apiKey": "$GDRIVE_KEY"
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
- If `CURL_EXIT` is non-zero → upload failed (network error, timeout, bad URL). Report to user with the exit code.
- If `CURL_EXIT` is 0 → parse `RESPONSE` as JSON.
  - If `"success": false` → report the `"error"` field message to the user.
  - If `"success": true` → proceed to Step 4.

---

## Step 4: Report to user

Tell the user:
- ✅ File uploaded successfully
- Google Drive link (from `"fileUrl"` in the API response)
- Folder where it was saved (from `"folderName"`)

Example:
> "✅ Uploaded **report.pdf** to Google Drive → [View file](https://drive.google.com/...)"

---

## Folder targeting

The POST body supports:
- `folderPath`: "Clients/Acme" — creates folders if they don't exist
- `folderId`: "1abc..." — use a specific folder ID
- Neither: saves to root of My Drive
- Add `"replaceExisting": true` to overwrite a file with the same name

To list available folders:
```bash
curl -s -L --max-time 30 "$GDRIVE_URL?action=list_folders"
```

---

## Notes

- File size limit: ~50MB
- All file types supported: PDF, Word, Excel, images, video, zip, code, etc.
- Hebrew filenames work perfectly
- Config at `~/.cowork-gdrive-config.json`
- Rate limit: Google Apps Script allows ~20,000 calls/day
