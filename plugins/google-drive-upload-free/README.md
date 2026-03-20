# Google Drive Upload Plugin

Upload files from Claude directly to your Google Drive. Just say "upload to Drive" or "save this to Drive" after any file is created.

**Completely free — unlimited uploads, no restrictions.**

## Features

- Unlimited uploads — no monthly cap
- All file types: PDF, Word, Excel, images, and more
- Files saved to a "Claude Uploads" folder in your Drive (customizable)
- Your credentials stay on your machine

---

## Setup

1. Deploy the Google Apps Script (one-time setup)
2. Save your config to `~/.cowork-gdrive-config.json`:

```json
{
  "url": "https://script.google.com/macros/s/YOUR_SCRIPT_ID/exec"
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

Built by [MSApps](https://msapps.mobi) · [michal@msapps.mobi](mailto:michal@msapps.mobi)
