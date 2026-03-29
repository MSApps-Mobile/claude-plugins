# Python Fallback — Direct Zoho API

Use this when `zohomail_*` MCP tools are unavailable in the session (e.g. MCP server failed to start).

## Setup

Before using the fallback script, configure your credentials as environment variables:

```bash
export ZOHO_ACCOUNT1_EMAIL="your-email@example.com"
export ZOHO_ACCOUNT1_CLIENT_ID="your-client-id"
export ZOHO_ACCOUNT1_CLIENT_SECRET="your-client-secret"
export ZOHO_ACCOUNT1_REFRESH_TOKEN="your-refresh-token"
export ZOHO_ACCOUNT1_INBOX_FOLDER_ID="your-folder-id"
```

## Script

```python
import requests, json, os
from datetime import datetime

def get_account_config():
    """Load account config from environment variables."""
    accounts = []
    i = 1
    while os.getenv(f"ZOHO_ACCOUNT{i}_EMAIL"):
        accounts.append({
            "email": os.getenv(f"ZOHO_ACCOUNT{i}_EMAIL"),
            "client_id": os.getenv(f"ZOHO_ACCOUNT{i}_CLIENT_ID"),
            "client_secret": os.getenv(f"ZOHO_ACCOUNT{i}_CLIENT_SECRET"),
            "refresh_token": os.getenv(f"ZOHO_ACCOUNT{i}_REFRESH_TOKEN"),
            "inbox_folder_id": os.getenv(f"ZOHO_ACCOUNT{i}_INBOX_FOLDER_ID"),
        })
        i += 1
    return accounts

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

now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
results = {}

for acct in get_account_config():
    email = acct["email"]
    result = {"token": "❌", "messages": "❌", "subjects": []}
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
    results[email] = result

print(json.dumps(results))
```

Parse the JSON output and use it to populate the health check report, adding a note:
`**Method used:** Python direct API (MCP fallback)`
