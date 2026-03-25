---
name: whatsapp-outreach
description: >
  Business outreach and follow-ups via WhatsApp for MSApps.
  Use when the user asks to "send a follow-up on WhatsApp", "WhatsApp outreach",
  "message a lead on WhatsApp", "תשלח פולואפ בוואטסאפ", "הודעת מעקב בוואטסאפ",
  "תכתוב ללקוח בוואטסאפ", or any request combining WhatsApp with business communication.
metadata:
  version: "0.3.0"
---

# WhatsApp Business Outreach

## ⚠️ CRITICAL: DO NOT USE CHROME OR BROWSER

**NEVER open WhatsApp Web in Chrome or any browser.**
**NEVER use Claude-in-Chrome tools for WhatsApp.**
**NEVER navigate to web.whatsapp.com.**

All messages are sent via REST API on localhost:8080 using Desktop Commander.

## Workflow

### 1. Find the contact (3-tier fallback)

**Tier 1:** Bridge whatsmeow DB
```bash
sqlite3 ~/whatsapp-mcp/whatsapp-bridge/store/whatsapp.db \
  "SELECT their_jid, full_name FROM whatsmeow_contacts WHERE full_name LIKE '%NAME%';"
```

**Tier 2:** macOS Contacts DB (if not found in bridge)
```bash
sqlite3 "/Users/michalshatz/Library/Application Support/AddressBook/Sources/*/AddressBook-v22.abcddb" \
  "SELECT c.ZFIRSTNAME, c.ZLASTNAME, p.ZFULLNUMBER FROM ZABCDRECORD c \
   JOIN ZABCDPHONENUMBER p ON c.Z_PK = p.ZOWNER \
   WHERE c.ZFIRSTNAME LIKE '%NAME%' OR c.ZLASTNAME LIKE '%NAME%';"
```

**Tier 3:** Ask user for phone number directly.

### 2. Check Conversation Memory (Notion)
Search `collection://98f76167-3dc2-423a-9615-6e1470c608d2` for contact profile. Adapt language, tone, and style based on stored preferences.

### 3. Review conversation history (Native WhatsApp DB — FULL history)
```bash
sqlite3 ~/Library/Group\ Containers/group.net.whatsapp.WhatsApp.shared/ChatStorage.sqlite \
  "SELECT ZFROMJID, ZTEXT, datetime(ZMESSAGEDATE + 978307200, 'unixepoch', 'localtime') as ts, ZISFROMME \
   FROM ZWAMESSAGE WHERE ZCHATSESSION IN \
   (SELECT Z_PK FROM ZWACHATSESSION WHERE ZCONTACTJID='JID') \
   ORDER BY ZMESSAGEDATE DESC LIMIT 15;"
```
This gives the FULL conversation history, not just what the bridge captured.

### 4. Compose the message
- Short and personal (2-4 lines max)
- Use first name
- Reference something specific from the conversation history
- Clear next step or question
- Match the language of previous conversation

### 5. CONFIRM with user
Show: recipient, context, drafted message. Wait for approval.

### 6. Ensure bridge is running
```bash
ps aux | grep whatsapp-bridge | grep -v grep
```
If not running:
```bash
cd ~/whatsapp-mcp/whatsapp-bridge && nohup ./whatsapp-bridge > /tmp/whatsapp-bridge.log 2>&1 &
```

### 7. Send via REST API
```bash
curl -s -X POST http://localhost:8080/api/send \
  -H "Content-Type: application/json" \
  -d '{"recipient": "PHONE@s.whatsapp.net", "message": "TEXT"}'
```

For groups:
```bash
curl -s -X POST http://localhost:8080/api/send \
  -H "Content-Type: application/json" \
  -d '{"recipient": "GROUP_ID@g.us", "message": "TEXT"}'
```

### 8. Update Conversation Memory in Notion
Update the contact's profile with new interaction data.

## Monitoring for Responses

After sending a message, poll for responses:
```bash
sqlite3 ~/whatsapp-mcp/whatsapp-bridge/store/messages.db \
  "SELECT sender, content, timestamp, is_from_me FROM messages \
   WHERE chat_jid LIKE '%JID_PATTERN%' AND is_from_me=0 \
   ORDER BY timestamp DESC LIMIT 5;"
```
Poll every 15-25 seconds using Desktop Commander.

## Finding Group Info
```bash
sqlite3 ~/Library/Group\ Containers/group.net.whatsapp.WhatsApp.shared/ChatStorage.sqlite \
  "SELECT ZCONTACTJID, ZPARTNERNAME FROM ZWACHATSESSION \
   WHERE ZPARTNERNAME LIKE '%GROUP_NAME%' AND ZCONTACTJID LIKE '%@g.us';"
```

Group members:
```bash
sqlite3 ~/Library/Group\ Containers/group.net.whatsapp.WhatsApp.shared/ChatStorage.sqlite \
  "SELECT gm.ZMEMBERJID, pn.ZPUSHNAME FROM ZWAGROUPMEMBER gm \
   LEFT JOIN ZWAPROFILEPUSHNAME pn ON gm.ZMEMBERJID = pn.ZJID \
   WHERE gm.ZCHATSESSION IN \
   (SELECT Z_PK FROM ZWACHATSESSION WHERE ZCONTACTJID='GROUP_JID@g.us');"
```

## REMEMBER
🚫 NO Chrome. NO browser. NO web.whatsapp.com.
✅ REST API on localhost:8080 via Desktop Commander.
✅ 3-tier contact search: bridge DB → macOS Contacts → ask user.
✅ Native WhatsApp DB for full conversation history.
✅ Bridge DB for live message monitoring.
✅ Use `nohup` when starting the bridge.