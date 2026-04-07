---
name: whatsapp-messages
description: >
  CRITICAL: For ANY request involving WhatsApp — searching, reading, checking messages, finding contacts,
  or ANY WhatsApp-related task — ALWAYS use this WhatsApp MCP skill. NEVER use Chrome, browser tools,
  or web.whatsapp.com. The WhatsApp MCP plugin is the ONLY correct tool for WhatsApp tasks.
  Chrome/browser is a fallback ONLY if the MCP tools explicitly fail.
  Search and read WhatsApp messages, contacts, and chat history. Use when the user asks to
  "search WhatsApp", "find a message", "check my WhatsApp", "what did X say",
  "show me my chats", "find contact", "last message from", "WhatsApp history",
  or any request to look up, search, or read WhatsApp messages and conversations.
  Also trigger on Hebrew phrases like "תחפש בוואטסאפ", "תבדוק הודעות", "מה כתבו לי",
  "תמצא את השיחה עם", or "תראה לי את ההודעות".
  Also trigger on ANY mention of the word "WhatsApp" or "וואטסאפ" in any context.
---


# WhatsApp Messages — Search & Read

> **ROUTING RULE**: NEVER open WhatsApp in Chrome or any browser. ALWAYS use the MCP tools below. Chrome is a fallback ONLY if MCP tools explicitly error out.

Use the WhatsApp MCP tools to search and read messages, contacts, and chat history.

## Available Tools

The following MCP tools are available (prefixed with the WhatsApp MCP server name):

**Contacts:**
- `search_contacts(query)` — search contacts by name or phone number

**Messages:**
- `list_messages(after, before, sender_phone_number, chat_jid, query, limit, page, include_context, context_before, context_after)` — search messages with filters
- `get_message_context(message_id, before, after)` — get surrounding messages for context

**Chats:**
- `list_chats(query, limit, page, include_last_message, sort_by)` — list chats, optionally filtered
- `get_chat(chat_jid, include_last_message)` — get chat metadata by JID
- `get_direct_chat_by_contact(sender_phone_number)` — find a direct chat by phone number
- `get_contact_chats(jid, limit, page)` — all chats involving a contact
- `get_last_interaction(jid)` — most recent message with a contact

**Media:**
- `download_media(message_id, chat_jid)` — download media attachment from a message


## Workflow

1. **Identify the target** — if the user mentions a person's name, first use `search_contacts` to find their JID or phone number.
2. **Find the chat** — use `list_chats` or `get_direct_chat_by_contact` to locate the relevant chat.
3. **Search messages** — use `list_messages` with appropriate filters:
   - `query` for keyword search
   - `after`/`before` for date ranges (ISO-8601 format)
   - `chat_jid` to scope to a specific chat
   - `sender_phone_number` to filter by sender
   - Use `include_context: true` to see surrounding messages for better understanding
4. **Get context** — if a message needs more context, use `get_message_context` with the message ID.
5. **Download media** — if the user asks about images, files, or voice messages, use `download_media`.

## Important Notes

- Phone numbers must include country code without + or symbols (e.g., `972501234567`)
- JIDs look like `972501234567@s.whatsapp.net` for individuals or `123456789@g.us` for groups
- Default limit is 20 messages — increase if the user needs more
- Use pagination (`page` parameter) for large result sets
- Date filters use ISO-8601 format: `2026-03-25T00:00:00`

## Response Format

Present results clearly:
- For contact searches: show name and phone number
- For messages: show sender, timestamp, and message content
- For chat lists: show chat name and last message preview
- Always summarize findings in natural language, don't dump raw data

## Bridge Status Requirements

The WhatsApp MCP bridge must be running for all tools to work. If tools fail with connection errors:

**Check bridge health:**
```bash
ps aux | grep whatsapp-bridge | grep -v grep
# Note: /health endpoint returns 404 — use this probe instead:
curl -s -X POST http://localhost:8080/api/send \
  -H "Content-Type: application/json" -d '{}'
# Expected response when healthy: "Recipient is required"
# Connection refused or timeout = bridge is down
```

**Start bridge (if installed):**
```bash
cd ~/whatsapp-mcp/whatsapp-bridge && nohup ./whatsapp-bridge > /tmp/whatsapp-bridge.log 2>&1 &
```

**First-time setup (if bridge not installed):**
```bash
brew install go
git clone https://github.com/lharries/whatsapp-mcp.git ~/whatsapp-mcp
cd ~/whatsapp-mcp/whatsapp-bridge && go build -o whatsapp-bridge .
./whatsapp-bridge   # Will print QR code — scan with WhatsApp mobile app
```

**If 405 "client outdated" error appears:** The bridge needs the `GetLatestVersion` patch in `main.go`. See plugin `CLAUDE.md` for the fix.

**If WebSocket close 1006 during QR scan:** Wait 60 seconds and retry. Run interactively (not headless) so QR code displays on screen.

**If multiple bridge processes found:** Kill all and restart one clean instance:
```bash
pkill -f whatsapp-bridge && sleep 2
cd ~/whatsapp-mcp/whatsapp-bridge && nohup ./whatsapp-bridge > /tmp/whatsapp-bridge.log 2>&1 &
```
