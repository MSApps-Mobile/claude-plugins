# WhatsApp MCP

Connect Claude directly to WhatsApp for searching, reading, sending messages, and managing business outreach with persistent per-contact memory.

## Health Check Loop

This plugin includes an automated **check → fix → update → push → repeat** health check cycle:

1. **Check** — verify bridge process, REST API (:8080), and SQLite databases
2. **Fix** — attempt bridge restart, rebuild, or fresh clone if not running
3. **Update** — improve task and skill files based on what was found
4. **Push** — commit generic improvements to this repo (no private data)
5. **Repeat** — loop until healthy or manual action required (QR scan, install)

## Architecture

- **Go Bridge**: whatsmeow-based WhatsApp client with SQLite storage and REST API (port 8080)
  - Bridge directory: `~/whatsapp-mcp/whatsapp-bridge/`
  - Messages DB: `store/messages.db`
  - Contacts DB: `store/whatsapp.db`
- **Python MCP Server**: FastMCP-powered tool server
- **Conversation Memory**: Private Notion database storing learned contact preferences and history

## Available Tools/Skills

- **whatsapp-messages**: Search and read message history, retrieve contact conversations
- **whatsapp-send**: Send messages and media files (images, documents, audio)

## Configuration

**Prerequisites**:
- Go 1.21 or later
- Python with UV package manager
- FFmpeg (optional, for voice message processing)
- WhatsApp mobile app for QR scan authentication

**Setup Steps**:
1. Clone the WhatsApp MCP repository: `git clone https://github.com/lharrak/whatsapp-mcp.git ~/whatsapp-mcp`
2. Build the Go bridge: `cd ~/whatsapp-mcp/whatsapp-bridge && go build -o whatsapp-bridge .`
3. Start the bridge: `./whatsapp-bridge &`
4. Scan QR code to authenticate WhatsApp
5. Set `WHATSAPP_MCP_PATH` environment variable
6. Start the Python MCP server

**Verify connection**:
```bash
ps aux | grep whatsapp-bridge | grep -v grep
curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/api/send
```

## Known Issues & Fixes

| Symptom | Fix |
|---------|-----|
| Port 8080 connection refused | Bridge not running — restart it |
| `~/whatsapp-mcp/` missing | Bridge never installed — run setup from scratch |
| Bridge exits immediately | Check Go version, missing dependencies |
| QR code loop | Previous session expired — rescan QR |
| macOS Contacts: "Operation not permitted" | Grant Full Disk Access to Terminal in System Settings |

## Common Workflows

- **Analyze community before outreach**: Search similar contacts' conversations
- **Send personalized messages**: Leverage memory system for tailored tone
- **Multi-language support**: Hebrew, English, and any language WhatsApp supports

## Best Practices

- Start with business-neutral tone until relationship is established
- Always verify bridge is running before attempting MCP tool calls
- Bridge must be authenticated (QR scanned) before any data is accessible
