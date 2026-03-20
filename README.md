# MSApps Claude Plugins

A plugin marketplace for Claude Code by [MSApps](https://msapps.mobi).

## Install

```shell
/plugin marketplace add msmobileapps/claude-plugins
```

## Available Plugins

| Plugin | Description | Install |
|--------|-------------|---------|
| **google-drive-upload-free** | Upload files to Google Drive — 5 uploads/month | `/plugin install google-drive-upload-free@msapps-plugins` |
| **google-drive-upload-pro** | Upload files to Google Drive — unlimited uploads | `/plugin install google-drive-upload-pro@msapps-plugins` |

## Setup

Both plugins require a one-time Google Apps Script deployment. After installing a plugin, save your config to `~/.cowork-gdrive-config.json`:

```json
{
  "url": "https://script.google.com/macros/s/YOUR_SCRIPT_ID/exec",
  "apiKey": "your-api-key"
}
```

Full setup guide: [msapps.mobi/plugins](https://msapps.mobi/plugins)

## Support

- Email: michal@msapps.mobi
- Pro license: [Get Pro ($9 lifetime)](https://michalicious361.gumroad.com/l/gdrive-claude-pro)
