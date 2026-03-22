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
| **youtube-transcriber** | Transcribe YouTube videos & playlists — no API key needed | `/plugin install youtube-transcriber@msapps-plugins` |
| **session-backup** | Zero-config daily backups of sessions, skills & configs | `/plugin install session-backup@msapps-plugins` |
| **notion-memory** | Long-term memory for Claude across sessions via Notion | `/plugin install notion-memory@msapps-plugins` |
| **digital-presence** | Analyze & improve your online presence across all platforms — **private, contact for access** | [Contact us](mailto:michal@msapps.mobi) |

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

### YouTube Transcriber
No setup needed — just requires the **Claude in Chrome** extension. Paste any YouTube video or playlist URL and ask Claude to transcribe it.

### Session Backup
No setup needed — just run `/backup-now`. Auto-detects your environment (Cowork or Claude Code), generates a unique instance ID, and backs up your skills, sessions, and configs to cloud storage. Run `/backup-setup` to customize schedule, folders, or retention policy.

### Digital Presence (Private)
This plugin is currently private. Contact michal@msapps.mobi or [connect on LinkedIn](https://linkedin.com/in/michalmsapps) for access and inquiries.

### Notion Memory
Requires **Notion MCP** connected to Claude. In Cowork: Settings → Connectors → Notion. In Claude Code: add a Notion MCP server to your `.mcp.json`. On first use, Claude creates a "Claude Memory" page in your Notion workspace to store preferences, decisions, project context, and session summaries.

Full setup guide: [msapps.mobi/plugins](https://msapps.mobi/plugins)

## Support

- Email: michal@msapps.mobi
- - Issues: [GitHub Issues](https://github.com/MSApps-Mobile/claude-plugins/issues)
