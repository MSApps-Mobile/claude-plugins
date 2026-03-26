---
name: whatsapp-outreach
description: >
  CRITICAL: For ANY WhatsApp business outreach, follow-ups, or client communication — ALWAYS use this
  WhatsApp MCP skill. NEVER use Chrome, browser tools, or web.whatsapp.com for WhatsApp outreach.
  The WhatsApp MCP plugin is the ONLY correct tool for WhatsApp tasks.
  Chrome/browser is a fallback ONLY if the MCP tools explicitly fail.
  Business outreach and follow-ups via WhatsApp for MSApps. Use when the user asks to
  "send a follow-up on WhatsApp", "WhatsApp outreach", "message a lead on WhatsApp",
  "follow up with client via WhatsApp", "send WhatsApp to lead",
  "business message on WhatsApp", "client follow-up WhatsApp",
  or any request combining WhatsApp with business communication, leads, or clients.
  Also trigger on Hebrew phrases like "תשלח פולואפ בוואטסאפ", "הודעת מעקב בוואטסאפ",
  "תכתוב ללקוח בוואטסאפ", "תשלח הודעה עסקית", "פולואפ ללידים בוואטסאפ",
  "מעקב לקוחות בוואטסאפ", or "הודעת מכירות".
  Also trigger on ANY mention of the word "WhatsApp" or "וואטסאפ" combined with business/leads/clients.
---

# WhatsApp Business Outreach

> **ROUTING RULE**: NEVER open WhatsApp in Chrome or any browser for outreach. ALWAYS use the MCP tools below. Chrome is a fallback ONLY if MCP tools explicitly error out.

Compose and send professional business messages via WhatsApp — follow-ups, lead outreach, client updates, and sales communication for MSApps.

## Workflow

### Step 1: Understand the Context
Before composing a message, gather:
- **Who** — the recipient's name, role, company
- **What** — the purpose (follow-up, introduction, proposal, update, check-in)
- **History** — check previous WhatsApp conversations for context

Use `search_contacts` to find the contact, then `list_messages` or `get_last_interaction` to review recent conversation history.

### Step 2: Check Conversation History
Always check the last interaction before sending:
1. Search for the contact: `search_contacts(name)`
2. Get last interaction: `get_last_interaction(jid)`
3. If needed, get more context: `list_messages(chat_jid=jid, limit=10)`

This prevents embarrassing duplicate messages or missed replies.

### Step 3: Compose the Message
Read the guidelines in `references/outreach-templates.md` for tone and structure.

Key principles:
- Keep messages short and personal — WhatsApp is not email
- Use the contact's first name
- Reference something specific (previous conversation, their project, a meeting)
- Include a clear next step or question
- Write in the language of the previous conversation (Hebrew or English)
- No corporate jargon — keep it warm and human
- Use one or two lines max for follow-ups

### Step 4: Confirm and Send
**CRITICAL: Always show the drafted message to the user and get explicit approval before sending.**

Present:
1. Recipient name and number
2. Previous conversation summary (if any)
3. The drafted message
4. Ask: "Want me to send this, or would you like to adjust it?"


Only after approval, use `send_message` to send.

### Step 5: Log the Outreach
After sending, summarize what was sent and to whom. If the lead-management-crm skill is available, suggest updating the lead record in Google Calendar.

## Message Types

- **Follow-Up After Meeting** — Short, reference the meeting, propose next step.
- **Cold Outreach** — Warm introduction, mention a mutual connection or specific reason for reaching out.
- **Proposal Follow-Up** — Check if they reviewed the proposal, offer to clarify.
- **Check-In with Existing Client** — Casual, ask how things are going, mention relevant updates.
- **Payment/Invoice Reminder** — Polite, reference the invoice number/date, offer help if there's an issue.

See `references/outreach-templates.md` for specific templates in Hebrew and English.
