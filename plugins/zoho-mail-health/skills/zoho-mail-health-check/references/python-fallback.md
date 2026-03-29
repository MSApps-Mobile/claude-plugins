# Python Fallback — Direct Zoho API

Use this when `zohomail_*` MCP tools are unavailable in the session (e.g. MCP server failed to start).

Run the script below via `Bash` tool using `python3`. It directly calls the Zoho OAuth and Mail APIs.

```python
import requests, json
from datetime import datetime

ACCOUNTS = [
    {
        "email": "michal@msapps.mobi",
        "client_id": "1000.9O2BOWZ45ICOS4AKYY66IX2DQNXJTR",
        "client_secret": "6866eac4c4d005e80c0f95a65fb04b4ffb04cc9c43",
        "refresh_token": "1000.02c3b4cdcb6684627dd5ecc514fd94e8.b64c1480a334f294819a9f7352f1cd2b",
        "inbox_folder_id": "4226009000000008013"
    },
    {
        "email": "jobs@msapps.mobi",
        "client_id": "1000.F1VIVIU9Q7XZYQLJNUJJJVF6SJK3EJ",
        "client_secret": "609778af70efce1aa284516ee604f94a7871b672dc",
        "refresh_token": "1000.96db7db43050e087ea17c232fbf44a8f.1b4c24666a2523a6672c4da0fedc81b5",
        "inbox_folder_id": "8368231000000008014"
    }
]

def get_access_token(acct):
    r = requests.post("https://accounts.zoho.com/oauth/v2/token", data={
        "refresh_token": acct["refresh_token"],
        "client_id": acct["client_id"],
        "client_secret": acct["client_secret"],
        "grant_type": "refresh_token"
    }, timeout=15)
    return r.json().get("access_token")

def get_account_id(token):
    r = requests.get("https://mail.zoho.com/api/accounts",
        headers={"Authorization": f"Zoho-oauthtoken {token}"}, timeout=15)
    data = r.json()
    if data.get("status", {}).get("code") == 200:
        return data["data"][0]["accountId"]
    return None

def list_messages(token, account_id, folder_id, limit=5):
    r = requests.get(f"https://mail.zoho.com/api/accounts/{account_id}/messages/view",
        headers={"Authorization": f"Zoho-oauthtoken {token}"},
        params={"folderId": folder_id, "limit": limit, "sortorder": "false"}, timeout=15)
    return r.json()

def send_message(token, account_id, from_email, to_email, subject, body):
    r = requests.post(f"https://mail.zoho.com/api/accounts/{account_id}/messages",
        headers={"Authorization": f"Zoho-oauthtoken {token}", "Content-Type": "application/json"},
        json={"fromAddress": from_email, "toAddress": to_email, "subject": subject,
              "content": body, "mailFormat": "plaintext"}, timeout=15)
    return r.json()

now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
results = {}

for acct in ACCOUNTS:
    email = acct["email"]
    result = {"token": "❌", "messages": "❌", "send": "❌", "subjects": []}
    token = get_access_token(acct)
    if not token:
        results[email] = result
        continue
    result["token"] = "✅"
    account_id = get_account_id(token)
    if not account_id:
        results[email] = result
        continue
    msgs = list_messages(token, account_id, acct["inbox_folder_id"])
    if msgs.get("status", {}).get("code") == 200:
        result["messages"] = "✅"
        for m in msgs.get("data", []):
            result["subjects"].append(f"{m.get('subject','(no subject)')} — {m.get('fromAddress','?')}")
    send = send_message(token, account_id, email, "michal@msapps.mobi",
                        f"[Health Check] {now}", f"Automated health check from {email} at {now}.")
    if send.get("status", {}).get("code") == 200:
        result["send"] = "✅"
    results[email] = result

print(json.dumps(results))
```

Parse the JSON output and use it to populate the health check report, adding a note:
`**Method used:** Python direct API (MCP fallback)`
