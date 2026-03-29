---
name: lead-pipeline-daily
description: "Daily lead pipeline review — scan calendar, prioritize, email report via Zoho Mail, WhatsApp reminder, execute updates."
---

# Daily Lead Pipeline Review

Fully autonomous. Execute all steps without asking for confirmation.

## Lead Selection Filter
Only include leads with calendar event date within **last 14 days through today**. No future dates.

## How It Works
Michal manages leads as Google Calendar events (msmobileapps@gmail.com). Each event = a lead (not a real meeting). Dates = follow-up dates. Colors = priority (11=Red/hot, 10=Green/existing client, 8=Gray/cold).

## Steps

### 1. Scan Calendar
`gcal_list_events` from (today - 14 days) to end of today.

### 2. Filter & Prioritize
Identify leads (skip real meetings). Sort: Red → Green → Other → Gray. Select TOP 10. Extract: name, date, last status, recommended next step.

### 3. Send Review Email
Via **Zoho Mail MCP** (`zohomail_send_message`, from: michal@msapps.mobi, to: michal@msapps.mobi).Subject: `[MSApps-Lead-Review] סקירת לידים [DD/MM/YYYY]`
Body: each lead on its own numbered line:
```
[#]. [name] — [stage] | [date]
עדכון אחרון: [summary]
המלצה: [next step]
```
End with: "תגובה למייל הזה = הוראות לטיפול בלידים."

### 4. WhatsApp Reminder (after 5 minutes)
Wait 5 minutes after sending the email, then send a **WhatsApp message** to Michal (972544255549) with a short summary: how many leads, key deadlines today, and a prompt to reply to the email with instructions.

### 5. Check for Reply (once — do NOT loop)
After sending the WhatsApp, check Gmail (`gmail_search_messages`) **once** for a reply to the lead review email. If no reply found — **move directly to Step 7**. Do NOT keep polling or waiting.

### 6. Parse & Execute Instructions (only if reply received)
If Michal replies by lead number ("העבר לשבוע הבא", "תשנה לאדום", "סגור", "כמו 2", "תשלח מייל ל...", "תשלח ווטסאפ", etc.):
**Do the action first** (send email, check Trello, send WhatsApp, draft proposal), **then update calendar event**.
Always `gcal_get_event` first → prepend new status block at TOP → `gcal_update_event` with sendUpdates: "none".
Update format:
```
**סטטוס:** [status]
**עדכון [DD/MM/YYYY]:**
* [what was done]
**צעדים הבאים:**
1. [next step]
---
[existing description preserved]
```

### 7. Completion Summary
Send a summary email via **Zoho Mail** (`zohomail_send_message`, from: michal@msapps.mobi, to: michal@msapps.mobi) with:
- If reply was received: summary table of all actions taken
- If no reply: short reminder of today's urgent items (deadlines, meetings) and note that no changes were made

Then **stop**. Do not keep polling.

## Rules
See global rules: https://www.notion.so/33238b5dfb2781259b59e487a232f988
Always one lead per line. Never combine leads. Never delete calendar descriptions.