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
│       ├── whatsapp.db    # device session + keys
│       └── messages.db    # message history
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

# 2. Build bridge
cd ~/whatsapp-mcp/whatsapp-bridge
go build -o whatsapp-bridge .

# 3. Start bridge — will print QR code for phone scan
./whatsapp-bridge

# 4. Scan QR code with WhatsApp mobile app
# (Settings → Linked Devices → Link a Device)
```

## Known Issues & Fixes

### 405 "Client Outdated" Error
- **Symptom**: `Client outdated (405) connect failure`
- **Root cause**: whatsmeow's hardcoded client version becomes stale over time
- **Fix**: Patch `main.go` to call `whatsmeow.GetLatestVersion()` at startup:
  ```go
  // Add import: "go.mau.fi/whatsmeow/store"
  if latestVer, err := whatsmeow.GetLatestVersion(nil); err == nil {
      store.SetWAVersion(*latestVer)
  }
  ```
  This patch is already applied to the repo at `~/whatsapp-mcp/`.

### Dependency Version Pinning
- When running `go get -u`, `go.mau.fi/libsignal` may upgrade to v0.2.1 which breaks compilation.
- **Fix**: Pin it back: `go get go.mau.fi/libsignal@v0.1.2 && go mod tidy`
- Newer whatsmeow versions (post-2026) require context arguments — incompatible with existing `main.go`.

### WebSocket Close 1006 (abnormal closure)
- **Symptom**: `websocket: close 1006 (abnormal closure): unexpected EOF`
- **When**: On new/unauthenticated devices during initial QR pairing
- **Root cause**: WhatsApp server closes connection during initial handshake; may be transient rate-limiting after multiple reconnect attempts
- **Fix**: Wait 30–60 seconds between attempts. Run bridge in a terminal (not headless) so QR code displays. Once QR is scanned and device authenticated, this error goes away permanently.
- **Note**: Auto-reconnect only works for authenticated sessions (`Store.ID != nil`). New devices must successfully complete QR scan in one attempt.

### Repo URL Typo in Old SKILL.md
- Correct: `https://github.com/lharries/whatsapp-mcp.git`
- Wrong (old): `https://github.com/lharrak/whatsapp-mcp.git`

## Health Check

The bridge is healthy when:
- `ps aux | grep whatsapp-bridge` shows a running process
- `curl http://localhost:8080/health` returns 200
- `store/whatsapp.db` contains device keys (authenticated session)

## Starting the Bridge

```bash
cd ~/whatsapp-mcp/whatsapp-bridge && nohup ./whatsapp-bridge > /tmp/whatsapp-bridge.log 2>&1 &
```

For QR scan (must be interactive — QR prints to stdout):
```bash
cd ~/whatsapp-mcp/whatsapp-bridge && ./whatsapp-bridge
```
