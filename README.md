# MSApps Claude Plugins

Free plugins for Claude by [MSApps](https://msapps.mobi).

## Install

```shell
/plugin marketplace add MSApps-Mobile/claude-plugins
```

## Available Plugins

| Plugin | Description | Install |
|--------|-------------|---------|
| **google-drive-upload** | Upload files to Google Drive — unlimited, free | `/plugin install google-drive-upload@msapps-plugins` |
| **toggl-time-tracker** | Track time with Toggl — start/stop timers, reports | `/plugin install toggl-time-tracker@msapps-plugins` |

## Setup

### Google Drive Upload

One-time Google Apps Script deployment. After installing, save your config to `~/.cowork-gdrive-config.json`:

```json
{
  "url": "https://script.google.com/macros/s/YOUR_SCRIPT_ID/exec"
}
```

### Toggl Time Tracker

Save your Toggl API token to `~/.toggl-config.json`:

```json
{
  "apiToken": "your-toggl-api-token"
}
```

Full setup guide: [msapps.mobi/plugins](https://msapps.mobi/plugins)

## Support

- Email: michal@msapps.mobi
- Issues: [GitHub Issues](https://github.com/MSApps-Mobile/claude-plugins/issues)
