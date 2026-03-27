# WhatsApp MCP

Connect Claude directly to WhatsApp for searching, reading, sending messages, and managing business outreach with persistent per-contact memory.

## Architecture

- **Go Bridge**: whatsmeow-based WhatsApp client with SQLite storage and REST API (port 8080)
- **Python MCP Server**: FastMCP-powered tool server
- **Conversation Memory**: Private Notion database storing learned contact preferences and history

## Available Tools/Skills

- **whatsapp-messages**: Search and read message history, retrieve contact conversations
- **whatsapp-send**: Send messages and media files (images, documents, audio)
- **whatsapp-outreach**: Business outreach templates and campaign management
- **conversation-memory**: Access persistent per-contact memory and learning database

## Memory System

Each contact has a learnable profile that improves over time:

- **Preferred language**: Auto-detected from interactions
- **Tone & style**: Business, casual, technical, creative
- **Relationship level**: Friend, client, colleague, prospect
- **Responds well to**: Communication patterns that get engagement
- **Avoid**: Topics or approaches that don't work
- **Conversation log**: Full history for context
- **Key learnings**: Important facts about the contact
- **Success score**: Engagement metrics

**Learning Curve**: 1st interaction (baseline) → 2-3 interactions (patterns emerge) → 5+ interactions (deep understanding)

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
- **Business outreach campaigns**: Use templates, track engagement
- **Lead followup**: Conversation memory tracks communication history
- **Multi-language support**: Hebrew, English, and any language WhatsApp supports

## Best Practices

- Use conversation memory to personalize messages and improve response rates
- Review success scores to identify which approaches work best per contact
- Start with business-neutral tone until relationship is established
- Log key learnings after important conversations
- Store lead/contact docs in Google Drive for team collaboration
- Link calendar availability for scheduling follow-ups
- Supports any language, but Hebrew and English have templated outreach flows
