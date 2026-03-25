---
name: whatsapp-outreach
description: >
  Business outreach and follow-ups via WhatsApp. Use when the user asks to
  "send a follow-up on WhatsApp", "WhatsApp outreach", "message a lead on WhatsApp",
  "follow up with client via WhatsApp", "send WhatsApp to lead",
  "business message on WhatsApp", "client follow-up WhatsApp",
  "תשלח פולואפ בוואטסאפ", "הודעת מעקב בוואטסאפ", "תכתוב ללקוח בוואטסאפ",
  "תשלח הודעה עסקית", "פולואפ ללידים בוואטסאפ", "מעקב לקוחות בוואטסאפ",
  "הודעת מכירות", or any request combining WhatsApp with business communication.
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
# WhatsApp Business Outreach

Compose and send professional business messages via WhatsApp — follow-ups, lead outreach, client updates, and sales communication.

## Workflow

### Step 1: Understand the Context
Gather: who (name, role, company), what (follow-up, intro, proposal, update), and history.

Use `search_contacts` to find the contact, then `list_messages` or `get_last_interaction` to review recent conversation.
### Step 2: Check Conversation History
Always check before sending:
1. `search_contacts(name)`
2. `get_last_interaction(jid)`
3. If needed: `list_messages(chat_jid=jid, limit=10)`

This prevents duplicate messages or missed replies.

### Step 3: Compose the Message
Read `references/outreach-templates.md` for tone and templates.

Key principles:
- Short and personal — WhatsApp is not email (2-4 lines max)
- Use first name
- Reference something specific (previous conversation, project, meeting)
- Clear next step or question
- Match the language of previous conversation (Hebrew or English)
- Warm and human — no corporate jargon

### Step 4: Confirm and Send
**CRITICAL: Show the drafted message and get explicit approval.**

Present: recipient, conversation summary, drafted message. Ask: "Want me to send this, or adjust?"

Only after approval → `send_message`.
### Step 5: Log the Outreach
Summarize what was sent and to whom. If a CRM skill is available, suggest updating the lead record.

## Message Types

- **Follow-up after meeting** — short, reference the meeting, propose next step
- **Cold outreach** — warm intro, mutual connection or specific reason
- **Proposal follow-up** — check if reviewed, offer to clarify
- **Client check-in** — casual, ask how things are going
- **Payment reminder** — polite, reference invoice, offer help

See `references/outreach-templates.md` for specific templates in Hebrew and English.