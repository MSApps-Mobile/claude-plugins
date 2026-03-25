---
name: whatsapp-messages
description: >
  Search and read WhatsApp messages, contacts, and chat history. Use when the user asks to
  "search WhatsApp", "find a message", "check my WhatsApp", "what did X say",
  "show me my chats", "find contact", "last message from", "WhatsApp history",
  "תחפש בוואטסאפ", "תבדוק הודעות", "מה כתבו לי", "תמצא את השיחה עם",
  "תראה לי את ההודעות", or any request to look up, search, or read WhatsApp conversations.
metadata:
  version: "0.1.0"
---

# WhatsApp Messages — Search & Read

Search and read WhatsApp messages, contacts, and chat history using the WhatsApp MCP tools.

## Available Tools

**Contacts:**
- `search_contacts(query)` — find contacts by name or phone number

**Messages:**
- `list_messages(after, before, sender_phone_number, chat_jid, query, limit, page, include_context, context_before, context_after)` — search with filters
- `get_message_context(message_id, before, after)` — get surrounding messages

**Chats:**
- `list_chats(query, limit, page, include_last_message, sort_by)` — list or filter chats
- `get_chat(chat_jid, include_last_message)` — chat metadata by JID
- `get_direct_chat_by_contact(sender_phone_number)` — find chat by phone number
- `get_contact_chats(jid, limit, page)` — all chats involving a contact
- `get_last_interaction(jid)` — most recent message with a contact

**Media:**
- `download_media(message_id, chat_jid)` — download attachment from a message

## Workflow

1. **Identify the contact** — use `search_contacts` to find their JID or phone number.
2. **Find the chat** — use `list_chats` or `get_direct_chat_by_contact`.
3. **Search messages** — use `list_messages` with appropriate filters (`query`, `after`/`before` in ISO-8601, `chat_jid`, `sender_phone_number`). Set `include_context: true` for surrounding messages.
4. **Get context** — use `get_message_context` with the message ID if needed.
5. **Download media** — use `download_media` for images, files, or voice messages.

## Format Notes

- Phone numbers: country code, no + or symbols (e.g., `972501234567`)
- Individual JID: `972501234567@s.whatsapp.net`
- Group JID: `123456789@g.us`
- Date filters: ISO-8601 format (`2026-03-25T00:00:00`)
- Default limit: 20 messages. Increase for larger searches. Use `page` for pagination.

## Response Guidelines

Present results in natural language. Show sender name, timestamp, and content. Summarize findings — never dump raw JSON.
