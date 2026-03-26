# MSApps Claude Plugins

Free plugins for Claude by [MSApps](https://msapps.mobi).

All plugins work in both **Claude Code** (CLI) and **Cowork** (desktop app).

## What are Claude plugins?

Plugins add new skills to Claude — things like uploading files to Google Drive, tracking time, transcribing YouTube videos, and more. Once installed, you don't need to learn any commands — just ask Claude naturally (e.g. "upload this to Drive" or "start a timer for client meeting") and the plugin kicks in automatically.

## Installation

### Claude Code (CLI)

Open your terminal where Claude Code is running and type these two commands:

**Step 1 — Add the MSApps marketplace (one-time):**
```
/plugin marketplace add MSApps-Mobile/claude-plugins
```
This tells Claude Code where to find MSApps plugins. You only need to do this once.

**Step 2 — Install a plugin:**
```
/plugin install <plugin-name>@msapps-plugins
```
Replace `<plugin-name>` with the plugin you want from the table below. For example:
```
/plugin install mac-disk-cleaner@msapps-plugins
```
That's it. The plugin is now active — just start talking to Claude and it will use the plugin when relevant.

### Cowork (Desktop App)

**Step 1 — Add the MSApps marketplace (one-time):**
Settings → Plugins → Marketplaces → Add → `MSApps-Mobile/claude-plugins`

**Step 2 — Install a plugin:**
Search for the plugin name (e.g. "mac-disk-cleaner") and click Install.

## Available Plugins

| Plugin | Description | Install |
|--------|-------------|---------|
| **google-drive-upload** | Upload files to Google Drive — unlimited, free | `/plugin install google-drive-upload@msapps-plugins` |
| **toggl-time-tracker** | Track time with Toggl — start/stop timers, reports | `/plugin install toggl-time-tracker@msapps-plugins` |
| **youtube-transcriber** | Transcribe YouTube videos & playlists — no API key needed | `/plugin install youtube-transcriber@msapps-plugins` |
| **session-backup** | Automated daily backups of sessions, skills & configs to Google Drive | `/plugin install session-backup@msapps-plugins` |
| **notion-memory** | Long-term memory for Claude across sessions via Notion | `/plugin install notion-memory@msapps-plugins` |
| **mac-disk-cleaner** | Reclaim disk space on macOS — clean caches, find large files | `/plugin install mac-disk-cleaner@msapps-plugins` |
| **whatsapp-mcp** | Connect Claude to WhatsApp — search, read, send messages & business outreach | `/plugin install whatsapp-mcp@msapps-plugins` |
| **linkedin-scraper** | Scrape LinkedIn profiles, companies & jobs — 5–10x cheaper than Chrome | `/plugin install linkedin-scraper@msapps-plugins` |
| **apify-scraper** | Full Apify web scraping platform — run Actors, manage datasets & schedules | `/plugin install apify-scraper@msapps-plugins` |
| **apollo** | Prospect leads, enrich contacts & load outreach sequences with Apollo.io | `/plugin install apollo@msapps-plugins` |
| **rtl-chat-fixer** | Fix jumbled RTL/LTR text mixing (Hebrew, Arabic, Persian) in chat | `/plugin install rtl-chat-fixer@msapps-plugins` |
| **vm-disk-cleanup** | Prevent and recover from disk-full errors in Cowork VMs & Claude Code sandboxes | `/plugin install vm-disk-cleanup@msapps-plugins` |
| **x-content-intelligence** | Scrape X/Twitter for insights & generate community-matched content | `/plugin install x-content-intelligence@msapps-plugins` |
| **wordpress-mcp** | Manage WordPress sites from Claude — posts, users, WooCommerce & more | `/plugin install wordpress-mcp@msapps-plugins` |
| **fix-chrome-connection** | Instantly fix stale Claude in Chrome connections caused by macOS user switching | `/plugin install fix-chrome-connection@msapps-plugins` |

## Setup

### Google Drive Upload
One-time Google Apps Script deployment. After installing, save your config to `~/.cowork-gdrive-config.json`:
```json
{
  "url": "https://script.google.com/macros/s/YOUR_SCRIPT_ID/exec",
  "apiKey": "your-api-key"
}
```

### Toggl Time Tracker
Save your Toggl API token to `~/.toggl-config.json`:
```json
{
  "apiToken": "your-toggl-api-token",
  "workspaceId": 1234567
}
```
Find your API token at https://track.toggl.com/profile. Find your workspace ID in the Toggl URL: `https://track.toggl.com/{workspaceId}/timer`.

### YouTube Transcriber
No config needed — just requires the **Claude in Chrome** extension (works in both Claude Code and Cowork). Paste any YouTube video or playlist URL and ask Claude to transcribe it.

### Session Backup
Requires the Google Drive Upload connector (see above). Backs up your skills, plugins, session data, and configs to a `Cowork-Backups` folder on Google Drive. Run `/backup-now` for an immediate backup, or set up a daily schedule.

### Mac Disk Cleaner
Requires macOS Ventura or later. No config needed — just ask Claude to "clean up my Mac" or "check disk space". Works with Claude Code's native Bash tool or Cowork's Desktop Commander. Only touches auto-regenerated caches — never deletes personal files.

### Notion Memory
Requires a Notion connector:
- **Claude Code:** Add a Notion MCP server to your `.mcp.json` config
- **Cowork:** Settings → Connectors → Notion

On first use, Claude creates a "Claude Memory" page in your Notion workspace to store preferences, decisions, project context, and session summaries.

### WhatsApp MCP
Requires the [WhatsApp MCP bridge](https://github.com/lharries/whatsapp-mcp) running locally:
1. Install Go, UV, and optionally FFmpeg (`brew install go uv ffmpeg`)
2. Clone and build the bridge: `git clone https://github.com/lharries/whatsapp-mcp.git ~/whatsapp-mcp && cd ~/whatsapp-mcp/whatsapp-bridge && go build -o whatsapp-bridge && ./whatsapp-bridge`
3. Scan the QR code with WhatsApp on first run
4. Set `WHATSAPP_MCP_PATH="$HOME/whatsapp-mcp"` in your shell profile

### LinkedIn Scraper
Requires Python 3.10+ with [uv](https://docs.astral.sh/uv/) installed. Run this once to authenticate:
```bash
uvx linkedin-scraper-mcp --login
```
A browser window opens — log in to LinkedIn, then close it. Your session is saved automatically.

### Apify Scraper
Set your Apify API token when installing the plugin:
```
APIFY_API_TOKEN=your_token_here
```
Get your token at [Apify Console](https://console.apify.com/) → Settings → Integrations.

### Apollo
No manual setup needed — the plugin automatically configures the Apollo MCP Server on install. Just authenticate with your Apollo account when prompted.

### RTL Chat Fixer
No config needed. Install and ask Claude to fix any RTL/LTR text mixing issues.

### VM Disk Cleanup
No config needed. Ask Claude to "clean up disk space" or "free up space in the VM" — works in both Cowork and Claude Code environments.

### X Content Intelligence
Requires the [Apify MCP connector](https://apify.com/) (free tier available). Uses the `apidojo/tweet-scraper` Actor for X scraping.

### WordPress MCP
Set these environment variables after installing:

| Variable | Description | Example |
|----------|-------------|---------|
| `WP_MCP_URL` | Your site's MCP Adapter HTTP endpoint | `https://yoursite.com/wp-json/mcp/v1` |
| `WP_MCP_AUTH` | Base64-encoded `username:application-password` | `bWljaGFsOnhX...` |

Requires the [WordPress MCP Adapter](https://developer.wordpress.org/news/2026/02/from-abilities-to-ai-agents-introducing-the-wordpress-mcp-adapter/) plugin installed on your WordPress 6.9+ site.

### Fix Chrome Connection
No config needed. Run it when your Claude in Chrome extension stops responding (common after switching macOS users).

## Support

- Email: michal@msapps.mobi
- Issues: [GitHub Issues](https://github.com/MSApps-Mobile/claude-plugins/issues)
