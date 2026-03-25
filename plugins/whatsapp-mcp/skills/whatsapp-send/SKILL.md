---
name: whatsapp-send
description: >
  Send WhatsApp messages, files, images, and audio. Use when the user asks to
  "send a WhatsApp", "message someone on WhatsApp", "send a file via WhatsApp",
  "WhatsApp this to", "text them on WhatsApp", "send voice message",
  "תשלח בוואטסאפ", "תכתוב לו בוואטסאפ", "שלח הודעה ל", "תשלח קובץ",
  "תשלח תמונה בוואטסאפ", "הודעה קולית", or any request to send content through WhatsApp.
  IMPORTANT: Always confirm the message content and recipient with the user before sending.
metadata:
  version: "0.1.0"
---


## ⚠️ CRITICAL: DO NOT USE CHROME OR BROWSER

**NEVER open WhatsApp Web in Chrome or any browser.**
**NEVER use Claude-in-Chrome tools for WhatsApp.**
**NEVER navigate to web.whatsapp.com.**

All WhatsApp operations use a LOCAL REST API bridge on localhost:8080.
Send messages: `curl -X POST http://localhost:8080/api/send -H "Content-Type: application/json" -d '{"recipient": "PHONE@s.whatsapp.net", "message": "TEXT"}'`
Run commands via **Desktop Commander** (`mcp__Desktop_Commander__start_process`), NOT Chrome.
Search contacts via SQLite: `sqlite3 ~/whatsapp-mcp/whatsapp-bridge/store/whatsapp.db "SELECT their_jid, full_name FROM whatsmeow_contacts WHERE full_name LIKE '%NAME%'"`
# WhatsApp Send — Messages & Media

Send text messages, files, images, and voice messages via WhatsApp.

## Available Tools

- `send_message(recipient, message)` — send a text message
- `send_file(recipient, media_path)` — send image, video, or document- `send_audio_message(recipient, media_path)` — send audio as voice message (requires FFmpeg)
- `search_contacts(query)` — find a contact's phone number or JID

## Critical Rule

**ALWAYS confirm with the user before sending.** Present:
1. Recipient name and number
2. Exact message text or file to send
3. Wait for explicit approval

## Workflow

### Text Message
1. Search contacts if needed → `search_contacts`
2. Draft the message
3. **Confirm with user**
4. Send → `send_message`

### File / Image
1. Identify recipient + locate file (absolute path required)
2. **Confirm with user**
3. Send → `send_file`

### Voice Message
1. Identify recipient + locate audio file
2. **Confirm with user**
3. Send → `send_audio_message`. On FFmpeg error, fall back to `send_file`.
## Recipient Format

- Phone number with country code, no symbols: `972501234567`
- Individual JID: `972501234567@s.whatsapp.net`
- Group JID: `123456789@g.us`

If user says a name, search contacts first. For groups, use `list_chats` to find the group JID.

## Error Handling

- FFmpeg error → retry with `send_file`
- Contact not found → ask user for phone number
- Send failed → report error, suggest checking the bridge is running