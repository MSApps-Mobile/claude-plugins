---
name: gcloud-cli-health-check
description: >
  Run a Google Cloud CLI (gcloud) health check — verify installation, authentication, active
  project, enabled APIs (gmail, calendar, Cloud Run), API token, billing, and Cloud Run services.
  Use this skill when the user says "gcloud health check", "check gcloud", "is gcloud working",
  "GCP health check", "check Google Cloud", "gcloud CLI health check", "test gcloud auth",
  "check Cloud Run", or any request to verify that the gcloud CLI is installed and operational.
  Also triggered by the scheduled task named "gcloud-cli-health-check".
metadata:
  version: "1.0.0"
  updated: "2026-04-06"
  author: "MSApps"
---

This skill may run in an automated/scheduled context with no user present. Execute all steps autonomously without asking clarifying questions. For write actions (send, post, create, update, delete), only take them if explicitly requested. When in doubt, produce a report.

## Critical: Use Desktop Commander — Not the Bash Tool

All `gcloud` commands MUST run via `mcp__Desktop_Commander__start_process`. The Bash tool runs in a sandboxed Linux environment where gcloud is not installed. The user's Mac has Google Cloud SDK installed and accessible from Desktop Commander.

```
✅ mcp__Desktop_Commander__start_process  →  runs on user's Mac  →  gcloud found
❌ Bash tool                               →  runs in Linux sandbox →  gcloud not found
```

## Step 1 — Verify gcloud is installed

```bash
gcloud --version 2>/dev/null || ~/google-cloud-sdk/bin/gcloud --version 2>/dev/null || echo "NOT_FOUND"
```

If output contains "NOT_FOUND", mark Installation as ❌ and skip remaining steps.

## Step 2 — Check authentication

```bash
gcloud auth list 2>&1
```

Parse the output to identify:
- Which accounts are authenticated (look for `*` prefix = active account)
- Expected active account: `msmobileapps@gmail.com`
- If active account differs from expected, mark Auth as ⚠️ and note the mismatch
- If no accounts at all, mark Auth as ❌

## Step 3 — Check active project

```bash
gcloud config get-value project 2>&1
```

- Expected project: `opsagent-491114`
- If the output matches, mark ✅
- If it's a different project ID, mark ⚠️ and note the discrepancy
- If unset/empty, mark ❌

## Step 4 — Check enabled APIs

```bash
gcloud services list --enabled --format="value(config.name)" --limit=25 2>&1
```

Note: this runs against the currently active project. If the active project is wrong (Step 3), the API list may not reflect `opsagent-491114`.

Flag if any of these are missing:
- `gmail.googleapis.com`
- `calendar-json.googleapis.com`
- `run.googleapis.com` (needed for Cloud Run deployments)

## Step 5 — Test API connectivity (access token)

```bash
gcloud auth print-access-token 2>&1 | head -c 40 && echo "...[truncated]"
```

If a token is returned (starts with `ya29.`), mark API Access as ✅. If it fails, mark as ❌.

## Step 6 — Check billing

Use this command (avoids triggering beta component install prompts):
```bash
gcloud billing projects describe $(gcloud config get-value project 2>/dev/null) 2>&1
```

Parse the output:
- `billingEnabled: true` → mark ✅
- `billingEnabled: false` or error → mark ⚠️ (Cloud Run deployments require billing to be linked, though the free tier covers normal usage)

Do NOT run `gcloud alpha billing accounts list` — it prompts to install beta components interactively.

## Step 7 — Check Cloud Run services

```bash
gcloud run services list --platform=managed --format="table(SERVICE,REGION,URL,LAST_DEPLOYED_BY,LAST_DEPLOYED_AT)" 2>&1
```

- If services are listed: show table, mark ✅
- If no services yet: mark ⚠️ (not yet deployed — expected in early stage)
- If error about billing or permissions: mark ⚠️ and note reason

## Step 8 — Save report

Save as `gcloud-health-check-YYYY-MM-DD.md` in the workspace folder:

```markdown
# gcloud CLI Health Check — YYYY-MM-DD HH:MM

## Summary Table
| Check | Status |
|-------|:------:|
| Installation | ✅/❌ |
| Authentication | ✅/⚠️/❌ |
| Active Project | ✅/⚠️/❌ |
| Enabled APIs | ✅/⚠️/❌ |
| API Access (token) | ✅/❌ |
| Billing | ✅/⚠️/❌ |
| Cloud Run | ✅/⚠️/❌ |

## Details
### Installation
- SDK version: X.X.X

### Authentication
- Active account: <account>
- Expected: msmobileapps@gmail.com
- Status: matches / mismatch ⚠️

### Active Project
- Project: <project-id>
- Expected: opsagent-491114
- Status: matches / mismatch ⚠️

### Enabled APIs
- List of enabled APIs
- Missing: <list any missing critical APIs>

### API Access (token)
- Token: ya29.xxxx...[truncated]
- Status: valid / failed

### Billing
- billingAccountName: <account>
- billingEnabled: true/false

### Cloud Run Services
| Service | Region | URL |
|---------|--------|-----|
| <name> | <region> | <url> |

## Notes
(Any issues, mismatches, or action items)
```

## Account Architecture Reference

| Account | Project | Role |
|---------|---------|------|
| msmobileapps@gmail.com | opsagent-491114 | Core ops / MSApps infra — owns gcloud CLI, GCP projects |
| socialjetopsagents@gmail.com | socialjetopsagent | SocialJet ops — Gmail API, Calendar services |

## Cloud Run Free Tier (reference)
- 2 million requests/month free
- 360,000 GB-seconds of memory free
- 180,000 vCPU-seconds free
- Scales to zero when idle — no idle cost
- Billing account must be linked (free tier still applies)

## Autonomy Rules
- Read auth/project/APIs/token/billing/Cloud Run status: ✅ always allowed (read-only)
- Modify any GCP settings or create/delete resources: ❌ never without explicit user confirmation
