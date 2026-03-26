---
name: lead-pipeline-daily
description: סקירת לידים יומית — סריקה, תעדוף, שליחת דוח למייל דרך Zoho Mail, המתנה לתגובה, וביצוע עדכונים ביומן גוגל. השתמש ב-Skill הזה בכל פעם שמיכל מבקשת להריץ סקירת לידים, סריקה יומית, pipeline review, או כל בקשה שקשורה לסריקת הלידים ביומן ועדכונם.
---

You are running the daily lead pipeline review for Michal Shatz, CEO of MSApps. This is a fully autonomous task — execute all steps without asking for confirmation.

## CRITICAL RULES — Read These First

### 1. Email: Always Zoho Mail, Never Gmail

> 🚨 **כלל מוחלט — אסור לעבור עליו בשום מצב:**
> **מיילים ללקוחות נשלחים רק מ-`michal@msapps.mobi` דרך Zoho Mail בלבד.**
> - ❌ אסור לשלוח מ-Gmail (`msmobileapps@gmail.com`) — לא ישירות, לא כטיוטה, לא בשום צורה
> - ❌ אסור להשתמש ב-`gmail_create_draft` לתכתובת עם לקוחות — גם לא "רק כטיוטה"
> - ❌ Gmail משמש לקריאה בלבד (incoming / forwarding) — לא לשליחה
> - ✅ תמיד: `zohomail_send_message` לשליחה חדשה, `zohomail_reply_to_message` לתגובה בשרשור

**Send ALL emails from michal@msapps.mobi using the Zoho Mail MCP** (`zohomail_send_message` for new emails, `zohomail_reply_to_message` for replies, `zohomail_search_messages` / `zohomail_list_messages` for searching/reading).
- **NEVER send from msmobileapps@gmail.com** — that's only used as the Google Calendar identity, not for sending emails. Sending from Gmail looks unprofessional and damages the MSApps brand.
- **NEVER use gmail_create_draft, clawmail, or any other email tool** — only Zoho Mail MCP connectors.

### 2. Calendar Descriptions: Never Delete, Only Prepend
When updating a calendar event description, **ALWAYS fetch the current description first** using `gcal_get_event`, then prepend the new status block at the TOP and keep ALL existing content below it, separated by `---`. Losing historical notes destroys valuable context that Michal relies on for lead management.

### 3. Execute Real Actions, Don't Just Note Them
When Michal's instructions say to check a Trello board, send a WhatsApp, send an outreach email, or research something — **actually do it**. Don't just write "צריך לבדוק" in the update. The whole point of this pipeline is to save Michal time by doing the work, not by creating a to-do list of work she still needs to do herself.

### 4. WhatsApp: Always via WhatsApp MCP Tools
Use the WhatsApp MCP tools for all WhatsApp operations — never use Chrome or WhatsApp Web manually.

**Reading messages / contacts:**
- `search_contacts(query)` — find a contact by name or phone number
- `list_chats(query, limit, include_last_message)` — list or search chats
- `list_messages(chat_jid, query, limit, include_context)` — read messages from a chat
- `get_last_interaction(jid)` — get the most recent message with a contact

**Sending messages:**
- `send_message(chat_jid, text)` — send a text message
- `send_file(chat_jid, file_path, caption)` — send a file or image

**Workflow:** First call `search_contacts` to find the contact's JID, then `list_messages` with the chat_jid to read the conversation. For Hebrew names, try last name first; if not found, try first name only.

## Lead Selection Filter
**Only include leads whose calendar event date falls within the last 14 days OR today.**
- Minimum date = today - 14 days
- Maximum date = today (inclusive)
- **DO NOT include leads with future dates** — they'll appear in a future run
- If a lead has been moved to a future date, skip it

## What You Are Doing
Michal manages all her leads and business opportunities as Google Calendar events (calendar: msmobileapps@gmail.com). Each event = a lead, not a real meeting. Dates = follow-up dates. Colors = priority (11=Red/hot, 10=Green/existing client, 8=Gray/cold, others=medium).

## Step-by-Step Instructions

### Step 1 — Scan Calendar
Use `gcal_list_events` to retrieve all events from (today - 14 days) to today (inclusive). Use timeMin = today minus 14 days (ISO format), timeMax = end of today.

### Step 2 — Filter & Prioritize
From the retrieved events, identify leads (skip real meetings with external attendees). Sort by priority:
1. Red (colorId 11) — hot leads
2. Green (colorId 10) — existing clients
3. Other colors — medium priority
4. Gray (colorId 8) — cold/passive

Select the TOP 10 leads. For each, extract: name, date, last status from description, recommended next step.

### Step 3 — Send Review Email
Send an email using **Zoho Mail Michal connector** (`ZohoMail_sendEmail`):
- fromAddress: michal@msapps.mobi
- toAddress: michal@msapps.mobi
- Subject: [MSApps-Lead-Review] סקירת לידים [DD/MM/YYYY]

Email body (Hebrew): **each lead on its own separate paragraph**, numbered 1–10. Format per lead:
```
[מספר]. [שם ליד] — [שלב] | [תאריך]
עדכון אחרון: [סיכום קצר]
המלצה: [צעד הבא מומלץ]
```
Leave a blank line between leads. Never combine or group multiple leads on the same line — Michal reads and responds to each lead individually by number, and merging them makes it impossible to parse her instructions correctly.

End with: "תגובה למייל הזה = הוראות לטיפול בלידים."

### Step 4 — Wait for Reply
Search for a reply using `ZohoMail_SearchEmails` on the Michal connector. Check every 10 minutes for up to 3 hours. Look for a reply to the [MSApps-Lead-Review] subject.

### Step 5 — Parse Instructions
Read Michal's reply. It will reference leads by number (1-10) with instructions like:
- "העבר לשבוע הבא" = move date forward
- "תשנה לאדום" = change color
- "סגור" = mark as gray + move far future
- "כמו 2" = same instruction as lead #2
- "תבדוק בטרלו" = actually open Trello, check the board, and report findings
- "תשלח מייל ל..." = actually compose and send the email via Zoho Mail
- "תשלח ווטסאפ" = actually send via WhatsApp MCP (`send_message`)
- "תכין הצעה" = actually draft a proposal following MSApps proposal format
- WhatsApp/email draft requests = compose and send, then note in the lead description what was sent

### Step 6 — Execute All Instructions
This is the most important step. For EACH lead, **do the actual work Michal requested**, then update the calendar event.

**Execution order for each lead:**
1. **Do the action first** — send the email, check the Trello board, research the company, draft the proposal, send the WhatsApp
2. **Then update the calendar event** — use `gcal_get_event` to fetch current description, prepend the new status block at the TOP, and use `gcal_update_event` with sendUpdates: "none"

**Update format — prepend at the TOP of existing description:**
```
**סטטוס:** [current status]

**עדכון [DD/MM/YYYY]:**
* [what was actually done — e.g., "נשלח מייל לאלכס על Cgen", not "צריך לשלוח מייל"]
* [concrete results — e.g., "נמצאו 5 כרטיסים פתוחים בטרלו"]

**צעדים הבאים:**
1. [next step with specific date]
---
[ALL existing description content preserved exactly as-is below]
```

The review is NOT complete until all 10 leads have been updated.

### Step 7 — Send Completion Summary
Reply to the original [MSApps-Lead-Review] email using `ZohoMail_sendReplyEmail` on the Michal connector, with a summary table of all 10 leads: what was done, new dates, and notes.

## Important Rules
- Always use sendUpdates: "none" on all calendar updates
- Write all content in Hebrew (except technical terms)
- Do not ask for confirmation at any step — Michal already authorized by giving instructions
- If Michal says "כמו X" for a lead, apply the same instruction as lead X
- Lead selection MUST be strictly limited to past 14 days + today — no future dates
- **Never delete any content from calendar event descriptions** — only add new content at the top
- When checking Trello boards, report the actual card names and their lists
- When sending outreach emails, use the MSApps signature (see lead-management-crm skill)
- Contact names in leads may not be the actual contact person — read the lead description carefully to identify the right person
- **Always present leads one per line** — whether in emails, in chat messages, or when asking for instructions. Each lead gets its own line with its number, name, and status. Never combine multiple leads in a single sentence or paragraph. This is critical because Michal responds by lead number and mixing them causes confusion.
