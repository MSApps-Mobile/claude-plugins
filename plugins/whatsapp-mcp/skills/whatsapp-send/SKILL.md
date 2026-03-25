---
name: whatsapp-send
description: >
  Send WhatsApp messages, files, images, and audio. Use when the user asks to
  "send a WhatsApp", "message someone on WhatsApp", "תשלח בוואטסאפ",
  "תכתוב לו בוואטסאפ", "שלח הודעה ל", or any request to send content through WhatsApp.
  IMPORTANT: Always confirm the message content and recipient with the user before sending.
metadata:
  version: "0.3.0"
---

# WhatsApp Send — Messages & Media

## ⚠️ CRITICAL: DO NOT USE CHROME OR BROWSER

**NEVER open WhatsApp Web in Chrome or any browser.**
**NEVER use Claude-in-Chrome tools for WhatsApp.**
**NEVER navigate to web.whatsapp.com.**

WhatsApp messages are sent via a LOCAL REST API bridge running on the user's Mac.
The bridge is a Go process (whatsapp-bridge) that connects to WhatsApp Web internally.

## How to Send Messages

### Method 1: REST API (PRIMARY — always try this first)
```bash
curl -s -X POST http://localhost:8080/api/send \
  -H "Content-Type: application/json" \
  -d '{"recipient": "PHONE@s.whatsapp.net", "message": "TEXT"}'
```

For groups, use the group JID:
```bash
curl -s -X POST http://localhost:8080/api/send \
  -H "Content-Type: application/json" \
  -d '{"recipient": "GROUP_ID@g.us", "message": "TEXT"}'
```

Run this command via **Desktop Commander** (`mcp__Desktop_Commander__start_process`).

### Method 2: WhatsApp MCP Tools (if available in session)
- `send_message(recipient, message)`
- `send_file(recipient, media_path)`
- `send_audio_message(recipient, media_path)`

## How to Find Contacts (3-tier fallback)

### Tier 1: Bridge whatsmeow contacts DB
```bash
sqlite3 ~/whatsapp-mcp/whatsapp-bridge/store/whatsapp.db \
  "SELECT their_jid, full_name, push_name FROM whatsmeow_contacts \
   WHERE full_name LIKE '%NAME%' OR push_name LIKE '%NAME%';"
```

### Tier 2: macOS Contacts database (has ALL contacts)
The bridge DB only has contacts seen since bridge started. For full contact search:
```bash
sqlite3 "/Users/michalshatz/Library/Application Support/AddressBook/Sources/*/AddressBook-v22.abcddb" \
  "SELECT c.ZFIRSTNAME, c.ZLASTNAME, p.ZFULLNUMBER FROM ZABCDRECORD c \
   JOIN ZABCDPHONENUMBER p ON c.Z_PK = p.ZOWNER \
   WHERE c.ZFIRSTNAME LIKE '%NAME%' OR c.ZLASTNAME LIKE '%NAME%';"
```
Format the phone number: remove +, spaces, dashes → e.g., `972505633630@s.whatsapp.net`

### Tier 3: Ask user for phone number
The bridge API can send to ANY phone number. No contact DB entry needed.

## How to Find Group JIDs
```bash
sqlite3 ~/Library/Group\ Containers/group.net.whatsapp.WhatsApp.shared/ChatStorage.sqlite \
  "SELECT ZCONTACTJID, ZPARTNERNAME FROM ZWACHATSESSION \
   WHERE ZPARTNERNAME LIKE '%GROUP_NAME%' AND ZCONTACTJID LIKE '%@g.us';"
```

## Recipient Format
- Individual: `972501234567@s.whatsapp.net` (country code + number)
- Group: `120363153818588902@g.us`
- Always use `@s.whatsapp.net` suffix for individuals

## Workflow
1. **Find contact** — use 3-tier fallback: bridge DB → macOS Contacts → ask user
2. **Check Conversation Memory** — search Notion DB `collection://98f76167-3dc2-423a-9615-6e1470c608d2` for preferences
3. **Read recent history** — use Native WhatsApp DB for full conversation context
4. **Draft the message** — adapt to their preferred language and tone
5. **CONFIRM with user** — show recipient + message, wait for approval
6. **Send via REST API** — `curl -X POST http://localhost:8080/api/send`
7. **Update memory** — update Notion with new interaction data

## Checking if Bridge is Running
```bash
ps aux | grep whatsapp-bridge | grep -v grep
```
If not running:
```bash
cd ~/whatsapp-mcp/whatsapp-bridge && nohup ./whatsapp-bridge > /tmp/whatsapp-bridge.log 2>&1 &
```
Use `nohup` to prevent the bridge from dying when the terminal closes.

## Reading Messages / Checking Responses

### For full history — use Native WhatsApp DB:
```bash
sqlite3 ~/Library/Group\ Containers/group.net.whatsapp.WhatsApp.shared/ChatStorage.sqlite \
  "SELECT ZFROMJID, ZTEXT, datetime(ZMESSAGEDATE + 978307200, 'unixepoch', 'localtime') as ts, ZISFROMME \
   FROM ZWAMESSAGE WHERE ZCHATSESSION IN \
   (SELECT Z_PK FROM ZWACHATSESSION WHERE ZCONTACTJID='JID') \
   ORDER BY ZMESSAGEDATE DESC LIMIT 10;"
```

### For live monitoring — use Bridge DB:
```bash
sqlite3 ~/whatsapp-mcp/whatsapp-bridge/store/messages.db \
  "SELECT sender, content, timestamp, is_from_me FROM messages \
   WHERE chat_jid LIKE '%JID_PATTERN%' ORDER BY timestamp DESC LIMIT 5;"
```

## Error Handling
- **"Connection refused" on port 8080** → Bridge not running. Start it with `nohup`.
- **Contact not found in bridge DB** → Search macOS Contacts DB (Tier 2), then ask user (Tier 3).
- **Bridge crash** → The bridge can crash. Check `ps aux | grep whatsapp-bridge`. Restart with `nohup`.
- **Message sent but no confirmation** → Check bridge logs at `/tmp/whatsapp-bridge.log`
- **FFmpeg error for audio** → Fall back to `send_file`
- **sync-history fails** → Use Native WhatsApp DB instead. It requires at least one existing message.

## REMEMBER
🚫 NO Chrome. NO browser. NO web.whatsapp.com.
✅ REST API on localhost:8080 via Desktop Commander.
✅ 3-tier contact search: bridge DB → macOS Contacts → ask user.
✅ Native WhatsApp DB for full history, Bridge DB for live monitoring.
✅ Use `nohup` when starting the bridge to prevent crashes.