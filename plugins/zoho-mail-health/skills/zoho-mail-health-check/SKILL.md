---
name: zoho-mail-health-check
description: >
  This skill should be used when the user asks to "run a Zoho Mail health check",
  "check if Zoho Mail is working", "test the mail accounts", "verify ${ACCOUNT1_EMAIL}
  and ${ACCOUNT2_EMAIL}", "run the mail health check", or any request to verify that
  the MSApps Zoho Mail accounts are operational. Also triggered automatically by the
  scheduled task named "zoho-mail-health-check".
metadata:
  version: "0.1.0"
  author: "MSApps"
---

## Zoho Mail Health Check

Run a full health check on both MSApps Zoho Mail accounts and save a structured report.

### Accounts to check

| Account | Inbox Folder ID |
|---------|----------------|
| ${ACCOUNT1_EMAIL} | `${ACCOUNT1_INBOX_FOLDER_ID}` |
| ${ACCOUNT2_EMAIL} | `${ACCOUNT2_INBOX_FOLDER_ID}` |

### Step 1 — List accounts

Call `zohomail_list_accounts`. Confirm both `${ACCOUNT1_EMAIL}` and `${ACCOUNT2_EMAIL}` appear. If either is missing, mark it ❌ and skip remaining steps for that account.

### Step 2 — Read 5 latest inbox messages (both accounts in parallel)

For each account call `zohomail_list_messages` with:
- `account_email`: the account address
- `folder_id`: the inbox folder ID from the table above
- `limit`: 5

Record each message's subject and sender. If the call fails, mark that account's Read column ❌.

### Step 3 — Send test emails (both accounts in parallel)

For each account call `zohomail_send_message` with:
- `account_email`: the sending account
- `to`: `${ACCOUNT1_EMAIL}`
- `subject`: `[Health Check] YYYY-MM-DD HH:MM` (current date/time in Israel time)
- `body`: `Automated health check from {account} at {datetime}. Zoho Mail MCP is operational.`

If the call fails, mark that account's Send column ❌.

### Step 4 — Save report

Save the report to the workspace Claude folder as `zoho-health-check-YYYY-MM-DD.md`.

Report structure:

```markdown
# Zoho Mail Health Check — YYYY-MM-DD HH:MM IL

**Method used:** zohomail_* MCP tools
**Config fix required:** No / Yes (describe if yes)

## ✅/❌ Summary Table

| Account | Connect | Read | Send |
|---------|:---:|:---:|:---:|
| ${ACCOUNT1_EMAIL} | ✅/❌ | ✅/❌ | ✅/❌ |
| ${ACCOUNT2_EMAIL} | ✅/❌ | ✅/❌ | ✅/❌ |

## 📬 ${ACCOUNT1_EMAIL} — Last 5 Messages
1. **Subject** — from sender (date)
...

## 📬 ${ACCOUNT2_EMAIL} — Last 5 Messages
1. **Subject** — from sender (date)
...

## Notes
- Any issues, anomalies, or observations
```

### Step 5 — Fallback (if zohomail_* MCP tools are unavailable)

If `zohomail_list_accounts` is not available in the session, fall back to the Python direct API method defined in the `references/python-fallback.md` file. Run the script via Bash and parse the output into the same report format. Note in the report that the fallback was used.

### Autonomy rules

- Read inbox messages: ✅ always allowed
- Send test emails: ✅ always allowed (these are health-check pings, not business comms)
- Save report to workspace: ✅ always allowed
- Modify any Zoho config: ❌ never without user confirmation
