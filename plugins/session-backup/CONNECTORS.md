# Connectors

## Required: Google Drive Upload

This plugin requires a Google Apps Script web app that receives file uploads via HTTP POST.

### POST payload format

```json
{
  "fileName": "cowork-skills-backup.zip",
  "content": "<base64-encoded file>",
  "mimeType": "application/zip",
  "apiKey": "<REDACTED — stored in ~/.cowork-gdrive-config.json>",
  "folderPath": "Cowork-Backups",
  "replaceExisting": true
}
```

### Expected response

```json
{
  "success": true,
  "fileId": "...",
  "fileName": "cowork-skills-backup.zip",
  "fileUrl": "https://drive.google.com/file/d/.../view",
  "folderName": "Cowork-Backups",
  "size": 3415966
}
```

### Optional: GET download endpoint

For merge strategy (preserving old backup content):

```
GET ?action=download&fileName=cowork-full-backup-latest.zip&apiKey=YOUR_KEY
```

If unavailable, backup proceeds with new content only (no merge).

### Config file

```json
// ~/.cowork-gdrive-config.json
{
  "url": "https://script.google.com/macros/s/YOUR_SCRIPT_ID/exec",
  "apiKey": "<REDACTED — stored in ~/.cowork-gdrive-config.json>"
}
```
