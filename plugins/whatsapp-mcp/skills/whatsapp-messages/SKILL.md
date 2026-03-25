---
name: whatsapp-messages
description: >
  Search and read WhatsApp messages, contacts, and chat history.
  Use when the user asks to "search WhatsApp", "find a message", "check my WhatsApp",
  "what did X say", "תחפש בוואטסאפ", "תבדוק הודעות", "מה כתבו לי",
  or any request to look up, search, or read WhatsApp messages and conversations.
metadata:
  version: "0.3.0"
---

# WhatsApp Messages — Search & Read

## ⚠️ CRITICAL: DO NOT USE CHROME OR BROWSER

**NEVER open WhatsApp Web in Chrome or any browser.**
**NEVER use Claude-in-Chrome tools for WhatsApp.**
**NEVER navigate to web.whatsapp.com.**

All WhatsApp data is accessed via LOCAL SQLite databases and REST API on the user's Mac.
Use **Desktop Commander** (`mcp__Desktop_Commander__start_process`) to run all commands.

## Data Sources (Priority Order)

There are TWO SQLite databases available. Use the right one for each task:

### 1. Native WhatsApp DB (PRIMARY for reading — has FULL history)
Path: `~/Library/Group Containers/group.net.whatsapp.WhatsApp.shared/ChatStorage.sqlite`

This is the native macOS WhatsApp app database. It has ALL chats, ALL messages, ALL group info.
**Always use this as the primary source for reading messages and finding chats.**

### 2. Bridge DB (SECONDARY — only recent messages since bridge started)
Path: `~/whatsapp-mcp/whatsapp-bridge/store/messages.db`

This only has messages seen since the bridge process started. Very limited (may have only a few chats).
**Use this for checking very recent messages and for monitoring new incoming messages.**

## How to Search Contacts

### Step 1: Try the bridge whatsmeow contacts DB
```bash
sqlite3 ~/whatsapp-mcp/whatsapp-bridge/store/whatsapp.db \
  "SELECT their_jid, full_name, push_name FROM whatsmeow_contacts \
   WHERE full_name LIKE '%NAME%' OR push_name LIKE '%NAME%' LIMIT 10;"
```

### Step 2: If not found — search macOS Contacts database
The bridge DB is very limited. Fall back to the macOS Contacts database:
```bash
sqlite3 "/Users/michalshatz/Library/Application Support/AddressBook/Sources/*/AddressBook-v22.abcddb" \
  "SELECT c.ZFIRSTNAME, c.ZLASTNAME, p.ZFULLNUMBER FROM ZABCDRECORD c \
   JOIN ZABCDPHONENUMBER p ON c.Z_PK = p.ZOWNER \
   WHERE c.ZFIRSTNAME LIKE '%NAME%' OR c.ZLASTNAME LIKE '%NAME%';"
```
Note: If the glob path doesn't work, first find the exact path:
```bash
ls ~/Library/Application\ Support/AddressBook/Sources/*/AddressBook-v22.abcddb
```

### Step 3: If still not found — ask user for the phone number
The bridge API can send to ANY phone number. No need to have them in any database.

## How to Read Messages (from Native WhatsApp DB)

### Read recent messages from a specific chat
```bash
sqlite3 ~/Library/Group\ Containers/group.net.whatsapp.WhatsApp.shared/ChatStorage.sqlite \
  "SELECT ZFROMJID, ZTEXT, datetime(ZMESSAGEDATE + 978307200, 'unixepoch', 'localtime') as ts, ZISFROMME \
   FROM ZWAMESSAGE WHERE ZCHATSESSION IN \
   (SELECT Z_PK FROM ZWACHATSESSION WHERE ZCONTACTJID='JID') \
   ORDER BY ZMESSAGEDATE DESC LIMIT 20;"
```

### Search chats by contact name
```bash
sqlite3 ~/Library/Group\ Containers/group.net.whatsapp.WhatsApp.shared/ChatStorage.sqlite \
  "SELECT ZCONTACTJID, ZPARTNERNAME FROM ZWACHATSESSION \
   WHERE ZPARTNERNAME LIKE '%NAME%';"
```

### Read recent messages from bridge DB (for new/live messages only)
```bash
sqlite3 ~/whatsapp-mcp/whatsapp-bridge/store/messages.db \
  "SELECT sender, content, timestamp, is_from_me FROM messages \
   WHERE chat_jid='JID' ORDER BY timestamp DESC LIMIT 20;"
```

## How to List Recent Chats
```bash
sqlite3 ~/Library/Group\ Containers/group.net.whatsapp.WhatsApp.shared/ChatStorage.sqlite \
  "SELECT ZCONTACTJID, ZPARTNERNAME, datetime(ZLASTMESSAGEDATE + 978307200, 'unixepoch', 'localtime') as last_msg \
   FROM ZWACHATSESSION WHERE ZREMOVED=0 ORDER BY ZLASTMESSAGEDATE DESC LIMIT 30;"
```

## How to Search by Keyword
```bash
sqlite3 ~/Library/Group\ Containers/group.net.whatsapp.WhatsApp.shared/ChatStorage.sqlite \
  "SELECT m.ZFROMJID, m.ZTEXT, datetime(m.ZMESSAGEDATE + 978307200, 'unixepoch', 'localtime') as ts \
   FROM ZWAMESSAGE m WHERE m.ZTEXT LIKE '%KEYWORD%' ORDER BY m.ZMESSAGEDATE DESC LIMIT 20;"
```

## How to Find Group Members
```bash
sqlite3 ~/Library/Group\ Containers/group.net.whatsapp.WhatsApp.shared/ChatStorage.sqlite \
  "SELECT gm.ZMEMBERJID, pn.ZPUSHNAME FROM ZWAGROUPMEMBER gm \
   LEFT JOIN ZWAPROFILEPUSHNAME pn ON gm.ZMEMBERJID = pn.ZJID \
   WHERE gm.ZCHATSESSION IN \
   (SELECT Z_PK FROM ZWACHATSESSION WHERE ZCONTACTJID='GROUP_JID@g.us');"
```

## How to Monitor for New Messages (Polling)

For ongoing conversations, poll the bridge DB every 15-25 seconds:
```bash
sqlite3 ~/whatsapp-mcp/whatsapp-bridge/store/messages.db \
  "SELECT sender, content, timestamp, is_from_me FROM messages \
   WHERE chat_jid LIKE '%JID_PATTERN%' AND is_from_me=0 \
   ORDER BY timestamp DESC LIMIT 5;"
```

## JID Formats

- Individual (phone-based): `972501234567@s.whatsapp.net`
- Individual (LID format): `250538411192437@lid` — the bridge may use this format
- Group: `120363153818588902@g.us`
- When searching, use LIKE '%partial%' to handle both JID formats

## Also Available: WhatsApp MCP Tools (if connected)
- `search_contacts(query)` — find contacts
- `list_messages(query, chat_jid, limit)` — search messages
- `list_chats(query, limit)` — list chats
- `get_last_interaction(jid)` — most recent message

If MCP tools are available, prefer them. If not, use SQLite via Desktop Commander.

## REMEMBER
🚫 NO Chrome. NO browser. NO web.whatsapp.com.
✅ Native WhatsApp DB for full history (PRIMARY read source).
✅ Bridge DB for live/recent messages only.
✅ macOS Contacts DB as fallback for contact search.
✅ WhatsApp MCP tools if available in session.