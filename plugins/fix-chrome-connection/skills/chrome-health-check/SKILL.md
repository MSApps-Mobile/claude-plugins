---
name: chrome-health-check
description: >
  Quickly checks whether the Claude in Chrome MCP connection is working and reports the status.
  Use when the user says "is chrome connected?", "check chrome", "chrome status", "test chrome
  connection", "is the chrome extension working?", or any variation of wanting to know if Chrome
  is reachable before starting browser-based work. Also use proactively before running Chrome
  automation tasks if there's any doubt the connection is live.
---

# Chrome Connection Health Check

Run a quick connection test. If broken, diagnose the root cause and fix it.

---

## Step 1: Test the connection

Call `tabs_context_mcp` with `createIfEmpty: false`.

**If successful** (returns tab info or "no tab group exists"):
→ Report: "✅ Chrome is connected and ready." Stop here.

**If it returns "No Chrome extension connected after discovery":**
→ Report: "❌ Chrome extension not connected — diagnosing now…"
→ Before assuming Chrome is closed, run Step 1b to distinguish "Chrome closed" from "extension not paired".
→ Then proceed to Step 2.

---

## Step 1b: Distinguish closed vs. unpaired Chrome

Even when `tabs_context_mcp` fails, Chrome may be running — the extension just isn't paired to this session. Run these two checks before escalating.

### Check A: Control_Chrome tab list
Call `mcp__Control_Chrome__list_tabs` (no args needed).

- **Returns a list of tabs** → Chrome IS running. The extension is simply not paired to this session. Tell the user: "Chrome is open but the Claude extension isn't connected — please click the Claude extension icon in your Chrome toolbar and hit **Connect**." Stop here unless they need more help.
- **Returns error or empty** → Chrome may actually be closed → proceed to Step 2.

> ⚠️ **Important (observed 2026-05-03):** `Control_Chrome.list_tabs` and `open_url` succeed even with no Claude-in-Chrome connection. However, `get_page_content` and `execute_javascript` will still fail with "Google Chrome is not running." This is a known limitation of Control_Chrome's DOM layer — it does NOT mean Chrome is closed. Trust `list_tabs` for the liveness check.

### Check B: Computer-use screenshot (visual backup)
If computer-use is available, call `mcp__computer-use__request_access` for Google Chrome, then take a screenshot. Chrome will be granted as **read-tier** (visible but not clickable). A screenshot showing the Chrome window with tabs confirms Chrome is running regardless of tool errors.

> Chrome is always read-only via computer-use (tier "read") — you can see the screen but cannot click or type. For actual browser interaction, the Claude-in-Chrome extension must be connected.

---

## Step 2: Diagnose — Account Mismatch (most common cause)

The #1 root cause is an **account mismatch** between the Desktop App and the Chrome extension. The bridge WebSocket is namespaced per user UUID — if the two sides use different accounts, they can never find each other.

### Check Desktop App account

```bash
python3 -c "
import glob, re
pattern = '/Users/*/Library/Application Support/Claude/Local Storage/leveldb/*.ldb'
for f in glob.glob(pattern):
    try:
        data = open(f,'rb').read().decode('utf-8','ignore')
        email = re.search(r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}', data)
        uid = re.search(r'[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}', data)
        if email: print('Desktop email:', email.group())
        if uid: print('Desktop UUID:', uid.group())
    except: pass
"
```

Also check the bridge URL in the log:
```bash
grep "Connecting to bridge" ~/Library/Logs/Claude/main.log | tail -3
```

### Check extension account

Navigate to: `chrome-extension://fcoeoabgfenejglbffodgkkbkcdhcgfn/options.html`

The top-right shows the logged-in email. Compare it with the Desktop App account.

**If they match** → accounts are correct, skip to Step 3b.
**If they differ** → account mismatch confirmed → go to Step 3a.

---

## Step 3a: Fix Account Mismatch

### 3a-1: Log out the extension
On the extension options page (`chrome-extension://fcoeoabgfenejglbffodgkkbkcdhcgfn/options.html`), click **"Log out"**.

### 3a-2: Switch Claude.ai browser session to the correct account

1. Navigate to `https://claude.ai/logout`
2. On the login page, click **"Continue with email"**
3. Enter the correct email (same as Desktop App — e.g. `ms.apps@msapps.mobi`)
4. Claude.ai sends a **magic link** to that email
5. Open the email inbox for that address and click the magic link:
   - For `ms.apps@msapps.mobi` (Zoho Workplace): `https://workplace.zoho.com/#mail_app/mail/folder/inbox`
   - The magic link email arrives within ~1 minute from `noreply@...mail.anthropic.com`
   - Subject: "Secure link to log in to Claude.ai | {timestamp}"
   - **Note:** `ms.apps@msapps.mobi` magic link emails are delivered to the `michal@msapps.mobi` Zoho inbox (same org)
6. Clicking the link logs Claude.ai into the correct account in this browser

### 3a-3: Re-authenticate the extension
After Claude.ai is signed in with the correct account:
- Reload `chrome-extension://fcoeoabgfenejglbffodgkkbkcdhcgfn/options.html`
- Click **"Log in"** — the extension OAuth uses the active Claude.ai session automatically
- Confirm the options page now shows the correct email in the top-right

### 3a-4: Restart the Claude Desktop App
`discoverAndSelectExtension()` runs once at startup and sets `discoveryComplete=true`. Every subsequent tool call throws the error permanently until the app restarts.

```bash
osascript -e 'quit app "Claude"'
sleep 3
open -a Claude
sleep 5
```

Then retest with `tabs_context_mcp`.

---

## Step 3b: Other fixes (non-account-mismatch)

If accounts match but still broken:

**Extension not installed/enabled:**
- Go to `chrome://extensions/` → confirm `fcoeoabgfenejglbffodgkkbkcdhcgfn` is enabled

**Extension token expired:**
- Log out and back in on the extension options page

**Bridge WebSocket down or Chrome not focused:**
```bash
osascript -e 'quit app "Google Chrome"'
sleep 2
open -a "Google Chrome"
sleep 3
osascript -e 'quit app "Claude"'
sleep 2
open -a Claude
```

---

## Quick Reference: MSApps Account Mapping

| Side | Account | UUID |
|------|---------|------|
| Claude Desktop App (correct) | ms.apps@msapps.mobi | `da5d00b9-5ca9-40ea-a8b5-5052603ff35b` |
| Chrome extension (correct) | ms.apps@msapps.mobi | `da5d00b9-5ca9-40ea-a8b5-5052603ff35b` |
| Chrome extension (**wrong/old**) | msmobileapps@gmail.com | `22a74de5-a2af-47b2-b30e-eab1eb168f03` |

Bridge URL: `wss://bridge.claudeusercontent.com/chrome/{UUID}` — both sides must share the same UUID.

---

## Root Cause Summary (diagnosed April 2026)

Desktop App switched accounts (Apr 2) to `ms.apps@msapps.mobi`. Chrome extension kept old credentials (`msmobileapps@gmail.com`). Bridge namespaces don't overlap → discovery found nothing → `discoveryComplete=true` got permanently stuck. Fix: log out extension → sign Claude.ai into correct account via magic link → extension re-authenticates via OAuth → restart Desktop App.
