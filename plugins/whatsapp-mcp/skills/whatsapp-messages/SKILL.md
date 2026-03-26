---
name: whatsapp-messages
description: >
  Search and read WhatsApp messages, contacts, and chat history.
  Use when the user asks to "search WhatsApp", "find a message", "check my WhatsApp",
  "what did X say", "תחפש בוואטסאפ", "תבדוק הודעות", "מה כתבו לי",
  or any request to look up, search, or read WhatsApp messages and conversations.
metadata:
  version: "0.4.0"
---

# WhatsApp Messages — Search & Read

## ⚠️ CRITICAL: DO NOT USE CHROME OR BROWSER

**NEVER open WhatsApp Web in Chrome or any browser.**
All WhatsApp data is accessed via LOCAL SQLite databases on the user's Mac.
Use **Desktop Commander** (`mcp__Desktop_Commander__start_process`) for all commands.

---

## ⚠️ KNOWN ISSUES: WhatsApp MCP Tools Are Broken

**`search_contacts(query)`** — returns empty for ALL queries. Don't use.
**`list_chats(query=...)`** — returns nothing with any filter. Don't use.
**`list_messages(...)`** — may return "No messages" even when messages exist (bridge not synced).

**Go straight to SQLite.** Don't waste attempts on the MCP tools for reading/searching.

---

## ⚠️ CRITICAL: LID Contacts (Modern WhatsApp 2024+)

Modern WhatsApp assigns contacts a **LID** (Linked ID) like `228337658130642@lid` instead of phone-based JIDs like `972501234567@s.whatsapp.net`. The bridge DB may return a phone-based JID, but **the native ChatStorage.sqlite stores the same person as a LID**.

This means: **searching by JID in the native DB will find nothing**, even if the person exists.

**Always search by name first, never by JID:**

```bash
sqlite3 ~/Library/Group\ Containers/group.net.whatsapp.WhatsApp.shared/ChatStorage.sqlite \
  "SELECT ZCONTACTJID, ZPARTNERNAME, datetime(ZLASTMESSAGEDATE + 978307200, 'unixepoch') as last \
   FROM ZWACHATSESSION WHERE ZPARTNERNAME LIKE '%NAME%';"
```

The returned `ZCONTACTJID` may be in `@lid` format — that's fine, use it directly.

---

## Data Sources

### 1. Native WhatsApp DB (PRIMARY — full history)
`~/Library/Group Containers/group.net.whatsapp.WhatsApp.shared/ChatStorage.sqlite`

ALL chats, ALL messages, ALL group info. Always use this as the primary source.

### 2. Bridge DB (SECONDARY — only recent messages since bridge started)
`~/whatsapp-mcp/whatsapp-bridge/store/messages.db`

Limited — only messages seen since bridge started. Use for live/new message monitoring.

### 3. Bridge Contacts DB (for phone number lookup)
`~/whatsapp-mcp/whatsapp-bridge/store/whatsapp.db` — table `whatsmeow_contacts`

---

## How to Search Contacts

### Step 1: Search native WhatsApp DB by name (handles LID contacts too)
```bash
sqlite3 ~/Library/Group\ Containers/group.net.whatsapp.WhatsApp.shared/ChatStorage.sqlite \
  "SELECT ZCONTACTJID, ZPARTNERNAME, datetime(ZLASTMESSAGEDATE + 978307200, 'unixepoch') as last \
   FROM ZWACHATSESSION WHERE ZPARTNERNAME LIKE '%NAME%';"
```

### Step 2: Bridge whatsmeow contacts (for phone number lookup)
```bash
sqlite3 ~/whatsapp-mcp/whatsapp-bridge/store/whatsapp.db \
  "SELECT their_jid, full_name, push_name FROM whatsmeow_contacts \
   WHERE full_name LIKE '%NAME%' OR push_name LIKE '%NAME%' LIMIT 10;"
```

### Step 3: macOS Contacts database fallback
```bash
sqlite3 "/Users/michalshatz/Library/Application Support/AddressBook/Sources/*/AddressBook-v22.abcddb" \
  "SELECT c.ZFIRSTNAME, c.ZLASTNAME, p.ZFULLNUMBER FROM ZABCDRECORD c \
   JOIN ZABCDPHONENUMBER p ON c.Z_PK = p.ZOWNER \
   WHERE c.ZFIRSTNAME LIKE '%NAME%' OR c.ZLASTNAME LIKE '%NAME%';"
```
Note: If the glob path fails, find the exact path first:
```bash
ls ~/Library/Application\ Support/AddressBook/Sources/*/AddressBook-v22.abcddb
```

### Step 4: Ask user for the phone number
The bridge API can send to any phone number — no DB entry needed.

---

## How to Read Messages — Direct Chat

```bash
# Step 1: Get the session Z_PK (use ZCONTACTJID from the search above)
sqlite3 ~/Library/Group\ Containers/group.net.whatsapp.WhatsApp.shared/ChatStorage.sqlite \
  "SELECT Z_PK FROM ZWACHATSESSION WHERE ZCONTACTJID='JID_OR_LID';"

# Step 2: Read messages (ZISFROMME=1 = sent by you, 0 = received)
sqlite3 ~/Library/Group\ Containers/group.net.whatsapp.WhatsApp.shared/ChatStorage.sqlite \
  "SELECT ZISFROMME, ZTEXT, datetime(ZMESSAGEDATE + 978307200, 'unixepoch') as ts \
   FROM ZWAMESSAGE WHERE ZCHATSESSION = SESSION_PK AND ZTEXT IS NOT NULL \
   ORDER BY ZMESSAGEDATE ASC LIMIT 50;"
```

---

## How to Read Group Messages — WITH Sender Identity

In group messages, `ZFROMJID` contains the **group's JID**, not the individual sender.
To know who said what, join with `ZWAGROUPMEMBER`:

```bash
sqlite3 ~/Library/Group\ Containers/group.net.whatsapp.WhatsApp.shared/ChatStorage.sqlite \
  "SELECT m.ZISFROMME, gm.ZMEMBERJID, m.ZTEXT, \
   datetime(m.ZMESSAGEDATE + 978307200, 'unixepoch') as ts \
   FROM ZWAMESSAGE m \
   LEFT JOIN ZWAGROUPMEMBER gm ON m.ZGROUPMEMBER = gm.Z_PK \
   WHERE m.ZCHATSESSION = SESSION_PK AND m.ZTEXT IS NOT NULL \
   ORDER BY m.ZMESSAGEDATE ASC LIMIT 50;"
```

- `ZISFROMME = 1` → sent by Michal
- `ZISFROMME = 0` → received from `ZMEMBERJID`
- `ZMEMBERJID` may be LID format — cross-reference with `ZWACHATSESSION` if you need the name

---

## How to List Recent Chats
```bash
sqlite3 ~/Library/Group\ Containers/group.net.whatsapp.WhatsApp.shared/ChatStorage.sqlite \
  "SELECT ZCONTACTJID, ZPARTNERNAME, datetime(ZLASTMESSAGEDATE + 978307200, 'unixepoch') as last_msg \
   FROM ZWACHATSESSION WHERE ZREMOVED=0 ORDER BY ZLASTMESSAGEDATE DESC LIMIT 30;"
```

## How to Search by Keyword
```bash
sqlite3 ~/Library/Group\ Containers/group.net.whatsapp.WhatsApp.shared/ChatStorage.sqlite \
  "SELECT m.ZTEXT, datetime(m.ZMESSAGEDATE + 978307200, 'unixepoch') as ts \
   FROM ZWAMESSAGE m WHERE m.ZTEXT LIKE '%KEYWORD%' ORDER BY m.ZMESSAGEDATE DESC LIMIT 20;"
```

## How to Find Group Members
```bash
sqlite3 ~/Library/Group\ Containers/group.net.whatsapp.WhatsApp.shared/ChatStorage.sqlite \
  "SELECT gm.ZMEMBERJID, gm.ZCONTACTNAME FROM ZWAGROUPMEMBER gm \
   WHERE gm.ZCHATSESSION = SESSION_PK;"
```

## How to Monitor for New Messages (Polling)
```bash
sqlite3 ~/whatsapp-mcp/whatsapp-bridge/store/messages.db \
  "SELECT sender, content, timestamp, is_from_me FROM messages \
   WHERE chat_jid LIKE '%JID_PATTERN%' AND is_from_me=0 \
   ORDER BY timestamp DESC LIMIT 5;"
```

---

## JID Formats

- Phone-based (older contacts): `972501234567@s.whatsapp.net`
- LID (modern contacts 2024+): `228337658130642@lid`
- Group: `120363153818588902@g.us`
- Timestamp: Apple CoreData epoch — add `978307200` to get Unix time

---

## Summary: What Works vs What Doesn't

| Tool | Status |
|------|--------|
| `search_contacts(query)` | ❌ Broken — always empty |
| `list_chats(query=...)` | ❌ Broken — always empty |
| `list_messages(...)` | ⚠️ Unreliable |
| Native DB search by name | ✅ Works reliably |
| Native DB search by JID | ⚠️ Only works for old contacts, fails for LID contacts |
| Bridge DB for new messages | ✅ Works for live monitoring |

🚫 NO Chrome. NO browser. NO web.whatsapp.com.
✅ Always search by **name** in native DB first.
✅ For groups — JOIN ZWAGROUPMEMBER to identify senders.
