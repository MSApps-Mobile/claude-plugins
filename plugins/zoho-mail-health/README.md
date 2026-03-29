# zoho-mail-health

Daily health check plugin for MSApps Zoho Mail accounts.

## What it does

Verifies that both Zoho Mail accounts (`michal@msapps.mobi` and `jobs@msapps.mobi`) are reachable, reads their 5 most recent inbox messages, sends a test email from each account, and saves a structured `✅/❌` report to the workspace.

## Components

| Component | Name | Purpose |
|-----------|------|---------|
| Skill | `zoho-mail-health-check` | Runs the full health check and saves a report |
| MCP | `zoho-mail` | Connects to Zoho Mail API for both accounts |

## Setup

The `.mcp.json` is pre-configured for MSApps accounts. No additional environment variables are required — credentials are embedded.

If the Zoho MCP server is not installed, build it first:
```bash
cd "/Users/michalshatz/Documents/Claude/mcps biz/zoho-mail-mcp-server"
npm install && npm run build
```

## Usage

Trigger the skill by saying any of:
- "Run the Zoho Mail health check"
- "Check if Zoho Mail is working"
- "Test the mail accounts"
- "Verify michal@msapps.mobi and jobs@msapps.mobi"

Or run it via the scheduled task `zoho-mail-health-check`.

## Output

A report saved to the workspace as `zoho-health-check-YYYY-MM-DD.md` with:
- ✅/❌ table for Connect / Read / Send per account
- Last 5 inbox subjects per account
- Notes on any anomalies

## Fallback

If the Zoho MCP server is unavailable, the skill automatically falls back to direct Python API calls using the credentials in `skills/zoho-mail-health-check/references/python-fallback.md`.

## Execution Model
**Impact Level:** Low (read-only health check)
**Plan:** Identify Zoho Mail accounts to verify (michal@msapps.mobi, jobs@msapps.mobi).
**Act:** Test authentication, send test email, verify delivery.
**Verify:** Report pass/fail status per account with latency metrics.
