---
name: whatsapp-send
description: >
  CRITICAL: For ANY request to send a WhatsApp message, file, image, or audio — ALWAYS use this
  WhatsApp MCP skill. NEVER use Chrome, browser tools, or web.whatsapp.com to send WhatsApp messages.
  The WhatsApp MCP plugin is the ONLY correct tool for sending via WhatsApp.
  Chrome/browser is a fallback ONLY if the MCP tools explicitly fail.
  Send WhatsApp messages, files, images, and audio. Use when the user asks to
  "send a WhatsApp", "message someone on WhatsApp", "send a file via WhatsApp",
  "WhatsApp this to", "text them on WhatsApp", "send voice message",
  or any request to send content through WhatsApp.
  Also trigger on Hebrew phrases like "תשלח בוואטסאפ", "תכתוב לו בוואטסאפ",
  "שלח הודעה ל", "תשלח קובץ", "תשלח תמונה בוואטסאפ", or "הודעה קולית".
  Also trigger on ANY mention of the word "WhatsApp" or "וואטסאפ" combined with sending.
  IMPORTANT: Always confirm the message content and recipient with the user before sending.
---

# WhatsApp Send — Messages & Media

> **ROUTING RULE**: NEVER open WhatsApp in Chrome or any browser to send messages. ALWAYS use the MCP tools below. Chrome is a fallback ONLY if MCP tools explicitly error out.

Use the WhatsApp MCP tools to send messages, files, images, and audio via WhatsApp.

## Available Tools

- `send_message(recipient, message)` — send a text message
- `send_file(recipient, media_path)` — send an image, video, or document
- `send_audio_message(recipient, media_path)` — send audio as a voice message (requires FFmpeg)
- `search_contacts(query)` — find a contact's phone number or JID


## Pre-Send Checklist

**CRITICAL: Always confirm with the user before sending any message.** Present:
1. The recipient (name and number)
2. The exact message text or file to send
3. Ask for explicit approval

## Workflow

### Sending a Text Message
1. **Identify the recipient** — search contacts if needed using `search_contacts`.
2. **Compose the message** — draft the message based on the user's request.
3. **Confirm with user** — show the recipient and message, ask for approval.
4. **Send** — use `send_message` with the recipient's phone number (no + prefix, with country code) or JID.

### Sending a File
1. **Identify the recipient** and **locate the file** — ensure the file path is absolute.
2. **Confirm with user** — show recipient and file name.
3. **Send** — use `send_file` with the recipient and absolute file path.

### Sending Audio/Voice Message
1. **Identify the recipient** and **locate the audio file**.
2. **Confirm with user**.
3. **Send** — use `send_audio_message`. If it fails due to FFmpeg, fall back to `send_file`.

## Recipient Format

- Phone number with country code, no + or symbols: `972501234567`
- Individual JID: `972501234567@s.whatsapp.net`
- Group JID: `123456789@g.us`

If the user says "send to Yossi" — first use `search_contacts("Yossi")` to find the number.


## Group Messages

For group chats, the recipient must be the group JID (ending in `@g.us`). Use `list_chats` to find group JIDs by name.

## Error Handling

- If `send_audio_message` fails with an FFmpeg error, retry with `send_file`
- If contact not found, ask the user for the phone number directly
- If send fails, report the error message and suggest checking the WhatsApp bridge is running

## Bridge Status Requirements

The WhatsApp bridge must be running and authenticated for sending to work.

**Check bridge:**
```bash
ps aux | grep whatsapp-bridge | grep -v grep
curl -s http://localhost:8080/health
```

**Start bridge (if installed and authenticated):**
```bash
cd ~/whatsapp-mcp/whatsapp-bridge && nohup ./whatsapp-bridge > /tmp/whatsapp-bridge.log 2>&1 &
```

**Not yet set up? Full setup:**
```bash
brew install go
git clone https://github.com/lharries/whatsapp-mcp.git ~/whatsapp-mcp
cd ~/whatsapp-mcp/whatsapp-bridge && go build -o whatsapp-bridge .
./whatsapp-bridge   # Run interactively — scan the QR code with WhatsApp on your phone
```

Once QR is scanned successfully, the bridge remembers the session. Future starts don't need QR.
