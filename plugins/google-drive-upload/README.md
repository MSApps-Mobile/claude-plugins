# Google Drive Upload — Claude Plugin by MSApps

Upload any file from Claude directly to your Google Drive. Free and unlimited.

## What it does

- Upload Word docs, PDFs, spreadsheets, presentations, or any file
- Organize uploads into folders (auto-creates if needed)
- Replace existing files by name
- Works in Cowork and Claude Code

## Installation

**Claude Code (CLI):**
```bash
/plugin marketplace add MSApps-Mobile/claude-plugins
/plugin install google-drive-upload@msapps-plugins
```

**Cowork:**
1. Settings → Plugins → Marketplaces → Add → `MSApps-Mobile/claude-plugins`
2. Search "google-drive-upload" → Install

## Setup (one-time)

1. Deploy the Google Apps Script web app (accepts file uploads via POST)
2. Save your config:

```json
// ~/.cowork-gdrive-config.json
{
  "url": "https://script.google.com/macros/s/YOUR_SCRIPT_ID/exec",
  "apiKey": "your-api-key"
}
```

## Usage

Just ask Claude naturally:

- "Upload this to Drive"
- "Save the report to Google Drive"
- "Put this in my Drive folder"

## License

MIT — Free and open source.

## Author

**MSApps** — [msapps.mobi](https://msapps.mobi) | [michal@msapps.mobi](mailto:michal@msapps.mobi)