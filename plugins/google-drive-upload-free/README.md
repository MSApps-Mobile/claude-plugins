# Google Drive Upload Plugin — Free Tier

Upload files from Claude directly to your Google Drive. Just say "upload to Drive" or "save this to Drive" after any file is created.

## Free Tier Limits

- **5 uploads per month** (resets on the 1st)
- Unlimited file types: PDF, Word, Excel, images, and more
- Files saved to a "Claude Uploads" folder in your Drive

## Upgrade to Pro

Need more uploads? Get the **Pro license** for **$9 (lifetime)**:
- Unlimited uploads
- Priority support
- All future updates included

👉 **[Get Pro →](https://michalicious361.gumroad.com/l/gdrive-claude-pro)**

---

## Setup

1. Deploy the Google Apps Script (one-time setup)
2. Save your config to `~/.cowork-gdrive-config.json`:

```json
{
  "url": "https://script.google.com/macros/s/YOUR_SCRIPT_ID/exec",
  "apiKey": "your-api-key"
}
```

Full setup guide: https://msapps.mobi/plugins

---

## How to Use

After any file is created, just say:
- "upload to Drive"
- "save this to my Google Drive"
- "send to Drive"

Claude will upload the file and give you a direct link.

---

Built by [MSApps](https://msapps.mobi)
