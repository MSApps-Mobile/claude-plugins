# WhatsApp MCP Plugin

Connect Claude to WhatsApp — search messages, read conversations, send texts and media, and manage business outreach.

## What It Does

This plugin gives Claude full access to your WhatsApp account through an MCP bridge:

- **Search & Read** — Find messages, contacts, and conversations. Search by name, date, keyword, or phone number.
- **Send Messages** — Send text, images, files, and voice messages to any contact or group.
- **Business Outreach** — Compose and send professional follow-ups, lead outreach, and client communications with templates and best practices.

## Prerequisites

Before installing this plugin, you need to set up the WhatsApp MCP bridge on your machine:

1. **Go** (1.21+) — `brew install go`
2. **Python + UV** — `brew install uv`
3. **FFmpeg** (optional, for voice messages) — `brew install ffmpeg`
## Setup

### 1. Clone the WhatsApp MCP repo

```bash
git clone https://github.com/lharries/whatsapp-mcp.git ~/whatsapp-mcp
```

### 2. Build and run the Go bridge

```bash
cd ~/whatsapp-mcp/whatsapp-bridge
go build -o whatsapp-bridge
./whatsapp-bridge
```

On first run, scan the QR code with WhatsApp (Settings → Linked Devices → Link a Device).

### 3. Set the environment variable

```bash
export WHATSAPP_MCP_PATH="$HOME/whatsapp-mcp"
```

Add this to your `~/.zshrc` or `~/.bashrc` to persist it.
### 4. Install the plugin

Install via the Claude plugin marketplace, or manually copy to your plugins directory.

## Skills

| Skill | Description |
|-------|-------------|
| `whatsapp-messages` | Search and read WhatsApp messages, contacts, and chat history |
| `whatsapp-send` | Send text messages, files, images, and voice messages |
| `whatsapp-outreach` | Business outreach — follow-ups, lead messages, client check-ins |

## Supported Languages

Works in any language. Includes Hebrew and English templates for business outreach.

## Architecture

The plugin connects to WhatsApp through a two-component bridge:

- **Go Bridge** (`whatsapp-bridge`) — Connects to WhatsApp Web via the whatsmeow library, stores messages in SQLite, exposes a REST API on port 8080.
- **Python MCP Server** (`whatsapp-mcp-server`) — FastMCP server that wraps the bridge API and provides tools to Claude via stdio transport.

## Credits

Based on [whatsapp-mcp](https://github.com/lharries/whatsapp-mcp) by Luke Harries.

## License

MIT