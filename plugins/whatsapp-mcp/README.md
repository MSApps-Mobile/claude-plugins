# WhatsApp MCP Plugin

Connect Claude to WhatsApp — search messages, read conversations, send texts and media, and manage business outreach. **Includes a conversation memory system that learns from every interaction.**

## What It Does

This plugin gives Claude full access to your WhatsApp account through an MCP bridge:

- **Search & Read** — Find messages, contacts, and conversations. Search by name, date, keyword, or phone number.
- **Send Messages** — Send text, images, files, and voice messages to any contact or group.
- **Business Outreach** — Compose and send professional follow-ups, lead outreach, and client communications with templates and best practices.
- **Conversation Memory** — Claude remembers every contact's preferences, communication style, and conversation history across sessions — and gets better with every interaction.

## Conversation Memory — How Claude Learns

Unlike a typical chatbot that starts fresh every session, this plugin includes a **persistent memory system** that makes Claude smarter over time.
### How It Works

Every time Claude has a WhatsApp conversation, it follows a learn-adapt-improve loop:

1. **Before messaging someone** — Claude checks its memory (a private Notion database) for that contact's profile: what language they prefer, what tone works best, what topics they respond to, and what to avoid.

2. **During the conversation** — Claude adapts its messages based on the stored profile. If someone prefers short, direct messages in Hebrew — that's what they get. If another contact responds well to emojis and humor — Claude matches that energy.

3. **After the conversation** — Claude analyzes the interaction and updates the contact's profile:
   - Did they respond quickly or slowly?
   - What language and tone did they use?
   - Did they engage enthusiastically or give short replies?
   - What topics got the best reaction?
   - What fell flat?

4. **Next session** — Claude reads the updated profile and starts even better than last time.

### What Gets Stored (Per Contact)

| Field | Example |
|-------|---------|
| Preferred Language | Hebrew, English, or Mixed |
| Preferred Tone | Casual, Professional, Warm, Direct, or Playful |
| Relationship | Family, Friend, Client, Lead, Colleague |
| Responds Well To | Emojis, Short messages, Humor, Questions |
| Avoid | Long messages, Formal tone, Links in first message |
| Conversation Log | Running history of all interactions |
| Key Learnings | "Prefers voice messages over text", "Always responds after 6pm" |
| Success Score | 0-10 rating of how well conversations go |
### Learning Curve

- **1st interaction** — Baseline: record language, initial tone, context
- **2-3 interactions** — Patterns emerge: response speed, preferred message length, emoji usage
- **5+ interactions** — Deep understanding: what motivates them, communication style, best approach
- **Ongoing** — Continuous refinement as behavior changes over time

### Lead-Specific Memory

For business leads, the memory system goes further:

1. After each WhatsApp conversation with a lead, Claude generates a **Conversation History Document** (structured Markdown with full conversation, notes, and next steps)
2. Uploads it to **Google Drive** for permanent storage
3. Links the document to the lead's **Google Calendar event** (where leads are tracked as CRM entries)

This means every lead has a complete, searchable record of all WhatsApp interactions — automatically maintained.

### Privacy

All memory data is stored in your private Notion workspace. Nothing is shared externally or sent to any third party. Contact profiles are only used to improve conversation quality within your own Claude sessions.

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
| `conversation-memory` | Persistent memory that learns from every conversation and improves over time |

## Supported Languages

Works in any language. Includes Hebrew and English templates for business outreach. The conversation memory system automatically detects and adapts to each contact's preferred language.

## Architecture

The plugin connects to WhatsApp through a two-component bridge:

- **Go Bridge** (`whatsapp-bridge`) — Connects to WhatsApp Web via the whatsmeow library, stores messages in SQLite, exposes a REST API on port 8080.
- **Python MCP Server** (`whatsapp-mcp-server`) — FastMCP server that wraps the bridge API and provides tools to Claude via stdio transport.
- **Conversation Memory** — Private Notion database that stores contact profiles and learnings, queried before each conversation and updated after.

## Credits

Based on [whatsapp-mcp](https://github.com/lharries/whatsapp-mcp) by Luke Harries.

## License

MIT