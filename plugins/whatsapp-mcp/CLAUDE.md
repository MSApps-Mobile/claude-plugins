# WhatsApp MCP Plugin — Architecture & Setup Notes

## Architecture

Two-component bridge:
- **Go Bridge** (`whatsapp-bridge`) — Connects to WhatsApp Web via the `whatsmeow` library, stores messages in SQLite, exposes a REST API on port 8080.
- **Python MCP Server** (`whatsapp-mcp-server`) — FastMCP server that wraps the bridge API and provides tools to Claude via stdio transport.

## Bridge Location

```
~/whatsapp-mcp/
├── whatsapp-bridge/       # Go bridge source + binary
│   ├── main.go
│   ├── go.mod / go.sum
│   ├── whatsapp-bridge    # compiled binary
│   └── store/
│       ├── whatsapp.db    # device session + keys (tables: whatsmeow_contacts, whatsmeow_device, etc.)
│       └── messages.db    # message history (table: messages)
└── whatsapp-mcp-server/   # Python MCP server
```

## Prerequisites

```bash
brew install go             # Go 1.21+ required
brew install uv             # Python package manager
brew install ffmpeg         # Optional: voice messages
```

## Setup (First Time)

```bash
# 1. Clone the correct repo (note: lharries, not lharrak)
git clone https://github.com/lharries/whatsapp-mcp.git ~/whatsapp-mcp

# 2. Update to latest whatsmeow (REQUIRED — old version causes WS close 1006)
cd ~/whatsapp-mcp/whatsapp-bridge
go get go.mau.fi/whatsmeow@latest
go get go.mau.fi/util/dbutil
go mod vendor

# 3. Apply context API patches to main.go (required for whatsmeow post-2026):
#    client.Download(ctx, downloader)
#    sqlstore.New(ctx, driver, dsn, log)
#    container.GetFirstDevice(ctx)
#    whatsmeow.GetLatestVersion(ctx, nil)
#    client.GetGroupInfo(ctx, jid)
#    client.Store.Contacts.GetContact(ctx, jid)

# 4. Optionally patch vendor/go.mau.fi/whatsmeow/socket/framesocket.go
#    to add User-Agent header (helps avoid rejection):
#    HTTPHeaders: http.Header{"Origin": {Origin}, "User-Agent": {"Mozilla/5.0 ..."}}

# 5. Build
go build -o whatsapp-bridge .

# 6. Start bridge — will print QR code for phone scan
./whatsapp-bridge

# 7. Scan QR code with WhatsApp mobile app
# (Settings → Linked Devices → Link a Device)
```

## Known Issues & Fixes

### WebSocket Close 1006 — REAL ROOT CAUSE: Stale whatsmeow version
- **Symptom**: `websocket: close 1006 (abnormal closure): unexpected EOF` immediately after connect
- **Root cause**: whatsmeow library becomes incompatible with WhatsApp's protocol over time (WhatsApp updates frequently). A library version from 1+ year ago will fail to complete the Noise handshake.
- **Fix**: Update to latest whatsmeow: `go get go.mau.fi/whatsmeow@latest && go mod vendor`
- After updating, fix context API changes in main.go (all methods now take `context.Context` as first arg — see Setup step 3 above).
- **Confirmed working**: whatsmeow `v0.0.0-20260327181659-02ec817e7cf4` with libsignal `v0.2.1`

### 405 "Client Outdated" Error
- **Symptom**: `Client outdated (405) connect failure`
- **Root cause**: whatsmeow's hardcoded client version becomes stale
- **Fix**: Patch `main.go` to call `whatsmeow.GetLatestVersion(ctx, nil)` at startup:
  ```go
  // Add import: "go.mau.fi/whatsmeow/store"
  if latestVer, err := whatsmeow.GetLatestVersion(context.Background(), nil); err == nil {
      store.SetWAVersion(*latestVer)
  }
  ```
  This patch is already applied to `~/whatsapp-mcp/`.

### Context API Changes (whatsmeow post-2026)
- Newer whatsmeow requires `context.Context` as first argument to most methods
- Compile errors to fix in `main.go`:
  - `client.Download` → `client.Download(context.Background(), downloader)`
  - `sqlstore.New` → `sqlstore.New(context.Background(), driver, dsn, log)`
  - `container.GetFirstDevice` → `container.GetFirstDevice(context.Background())`
  - `whatsmeow.GetLatestVersion` → `whatsmeow.GetLatestVersion(context.Background(), nil)`
  - `client.GetGroupInfo` → `client.GetGroupInfo(context.Background(), jid)`
  - `client.Store.Contacts.GetContact` → `client.Store.Contacts.GetContact(context.Background(), jid)`

### Repo URL Typo in Old SKILL.md
- Correct: `https://github.com/lharries/whatsapp-mcp.git`
- Wrong (old): `https://github.com/lharrak/whatsapp-mcp.git`

### Multiple Bridge Instances
- If `ps aux | grep whatsapp-bridge` shows more than one process, duplicate instances may be running.
- This can happen when nohup/background starts are repeated without killing the old process.
- Safe to kill older instances: `pkill -f whatsapp-bridge && sleep 2 && cd ~/whatsapp-mcp/whatsapp-bridge && nohup ./whatsapp-bridge > /tmp/whatsapp-bridge.log 2>&1 &`

## Health Check

The bridge is healthy when:
- `ps aux | grep whatsapp-bridge` shows a running process
- `curl -s -X POST http://localhost:8080/api/send -H "Content-Type: application/json" -d '{}'` returns `Recipient is required` (not a connection error)
- `store/whatsapp.db` table `whatsmeow_device` contains a JID row (authenticated session)

> **Note**: The `/health` and `/` endpoints return 404. Use the POST /api/send probe above to confirm the bridge is responding correctly.

## Database Tables

**whatsapp.db** (device session + contacts):
- `whatsmeow_device` — authenticated device session (JID)
- `whatsmeow_contacts` — contact list (use this, NOT `contacts`)
- `whatsmeow_sessions`, `whatsmeow_identity_keys`, etc. — crypto state

**messages.db**:
- `messages` — full message history

Sample health queries:
```bash
# Contact count
sqlite3 ~/whatsapp-mcp/whatsapp-bridge/store/whatsapp.db \
  "SELECT COUNT(*) FROM whatsmeow_contacts;"

# Message count + latest
sqlite3 ~/whatsapp-mcp/whatsapp-bridge/store/messages.db \
  "SELECT COUNT(*) as total, MAX(timestamp) as latest FROM messages;"

# Device/auth check
sqlite3 ~/whatsapp-mcp/whatsapp-bridge/store/whatsapp.db \
  "SELECT jid FROM whatsmeow_device LIMIT 1;"
```

## Starting the Bridge

```bash
cd ~/whatsapp-mcp/whatsapp-bridge && nohup ./whatsapp-bridge > /tmp/whatsapp-bridge.log 2>&1 &
```

For QR scan (must be interactive — QR prints to stdout):
```bash
cd ~/whatsapp-mcp/whatsapp-bridge && ./whatsapp-bridge
```
