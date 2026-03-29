# WhatsApp MCP

Connect Claude directly to WhatsApp for searching, reading, sending messages, and managing business outreach with persistent per-contact memory.

## Architecture

- **Go Bridge**: whatsmeow-based WhatsApp client with SQLite storage and REST API (port 8080)
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

**Setup Steps**:
1. Clone the WhatsApp MCP repository
2. Build the Go bridge
3. Scan QR code to authenticate WhatsApp
4. Set `WHATSAPP_MCP_PATH` environment variable
5. Start the MCP server

## Common Workflows

- **Analyze community before outreach**: Search similar contacts' conversations
- **Send personalized messages**: Leverage memory system for tailored tone
- **Multi-language support**: Hebrew, English, and any language WhatsApp supports

## Best Practices

- Start with business-neutral tone until relationship is established
