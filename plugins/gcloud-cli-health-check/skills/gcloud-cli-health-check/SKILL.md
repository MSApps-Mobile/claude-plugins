---
name: gcloud-cli-health-check
description: >
  Run a Google Cloud CLI (gcloud) health check — verify installation, authentication, active
  project, recommended region, enabled APIs (run, cloudbuild, artifactregistry, secretmanager,
  cloudresourcemanager, iam, plus gmail/calendar/monitoring/logging), API access token, billing,
  IAM bindings, service accounts, and Cloud Run services across both primary and secondary
  projects. Use this skill when the user says "gcloud health check", "check gcloud", "is gcloud
  working", "GCP health check", "check Google Cloud", "gcloud CLI health check", "test gcloud
  auth", "check Cloud Run", or any request to verify that the gcloud CLI is installed and
  operational. Also triggered by the scheduled task named "gcloud-cli-health-check" (or the
  legacy name "gcloud-health-check").
metadata:
  version: "1.1.0"
  updated: "2026-04-20"
  author: "MSApps"
---

This skill may run in an automated/scheduled context with no user present. Execute all steps autonomously without asking clarifying questions. For write actions (send, post, create, update, delete), only take them if explicitly requested. When in doubt, produce a report of what you found.

## Critical: Use Desktop Commander — Not the Bash Tool

All `gcloud` commands MUST run via `mcp__Desktop_Commander__start_process`. The Bash tool runs in a sandboxed Linux environment where gcloud is not installed AND the sandbox proxy returns `403 blocked-by-allowlist` for every Google endpoint (dl.google.com, sdk.cloud.google.com, oauth2.googleapis.com, www.googleapis.com, accounts.google.com). The user's Mac has Google Cloud SDK installed at `/opt/homebrew/bin/gcloud` with auth already configured.

```
✅ mcp__Desktop_Commander__start_process  →  runs on user's Mac  →  gcloud found, auth available
❌ Bash tool                               →  runs in Linux sandbox →  gcloud not found, Google blocked
```

If Desktop Commander is unavailable, do NOT try to install gcloud in the sandbox — it is impossible (no network access to Google, no sudo). Write a report documenting the block and stop.

## Expected State

| Thing | Expected value |
|---|---|
| gcloud binary | `/opt/homebrew/bin/gcloud` (macOS, Homebrew) |
| Active account | `michal@opsagents.agency` (primary) |
| Active project | `opsagent-491114` |
| Compute region | `me-west1` (Israeli prod) |
| Secondary project | `socialjetopsagent` (SocialJet Gmail/Calendar services) |

Legacy accepted account: `msmobileapps@gmail.com` (same billing family — flag as ⚠️ informational, not ❌).

## Step 1 — Verify gcloud is installed

```bash
/opt/homebrew/bin/gcloud --version
```

Fall back to `gcloud --version` if the explicit path is missing. If both fail → mark Installation ❌ and stop.

## Step 2 — Check authentication

```bash
/opt/homebrew/bin/gcloud auth list
/opt/homebrew/bin/gcloud auth print-access-token --account=michal@opsagents.agency | head -c 20
/opt/homebrew/bin/gcloud auth application-default print-access-token | head -c 20
```

Parse:
- Active account (line starting with `*`).
- `michal@opsagents.agency` present? User-token OK?
- ADC token OK?

If no accounts at all → mark Auth ❌. If wrong account active → mark ⚠️ and note. If ADC missing → mark ⚠️ (some SDKs need it).

## Step 3 — Check active project and region

```bash
/opt/homebrew/bin/gcloud config get-value project
/opt/homebrew/bin/gcloud config get-value compute/region
/opt/homebrew/bin/gcloud projects describe opsagent-491114 --format="value(lifecycleState,projectId,name)"
```

- Project must be `opsagent-491114` and `lifecycleState=ACTIVE` → ✅
- Region should be `me-west1` (warn ⚠️ if different, it still works)
- Mismatch on project → ⚠️

## Step 4 — Billing

```bash
/opt/homebrew/bin/gcloud billing projects describe opsagent-491114
```

- `billingEnabled: true` → ✅
- Missing / false → ⚠️ (Cloud Run free tier still applies but deploys require billing linked)

Do NOT run `gcloud alpha billing accounts list` — it triggers an interactive prompt to install beta components and hangs in automated runs.

## Step 5 — Enabled APIs (critical + optional)

```bash
/opt/homebrew/bin/gcloud services list --enabled --project=opsagent-491114 --format="value(config.name)"
```

Critical (must be enabled — flag ❌ if missing):
- `run.googleapis.com`
- `cloudbuild.googleapis.com`
- `artifactregistry.googleapis.com`
- `secretmanager.googleapis.com`
- `cloudresourcemanager.googleapis.com`
- `iam.googleapis.com`

Optional (flag ⚠️ if missing):
- `gmail.googleapis.com`
- `calendar-json.googleapis.com`
- `monitoring.googleapis.com`
- `logging.googleapis.com`

## Step 6 — Cloud Run services (multi-region, multi-project)

```bash
/opt/homebrew/bin/gcloud run services list --region=me-west1 --project=opsagent-491114
/opt/homebrew/bin/gcloud run services list --region=us-central1 --project=opsagent-491114
/opt/homebrew/bin/gcloud run services list --project=socialjetopsagent
```

Record: service name, region, URL, last deployed. If all three return zero services → ⚠️ (not yet deployed / expected in early stage). If any unexpected error → note it.

## Step 7 — IAM roles for michal@opsagents.agency

```bash
/opt/homebrew/bin/gcloud projects get-iam-policy opsagent-491114 \
  --flatten="bindings[].members" \
  --format="table(bindings.role)" \
  --filter="bindings.members:michal@opsagents.agency"
```

Record the roles. If `roles/owner` or `roles/editor` is present → ✅. If empty → ❌ (account has no access to project).

## Step 8 — Service accounts

```bash
/opt/homebrew/bin/gcloud iam service-accounts list --project=opsagent-491114
```

Record the list. Flag if the default Compute Engine SA still has broad permissions (security best practice: replace with scoped SAs + Workload Identity).

## Step 9 — Configurations

```bash
/opt/homebrew/bin/gcloud config configurations list
```

Record which configuration is active.

## Step 10 — Save report

Save as `gcloud-health-check-YYYY-MM-DD.md` in the workspace outputs folder (overwriting any prior `BLOCKED` report from the same day):

```markdown
# gcloud CLI Health Check — YYYY-MM-DD HH:MM

**Account:** michal@opsagents.agency
**Project:** opsagent-491114 (+ socialjetopsagent)
**Runner:** Desktop Commander (user's Mac)
**Overall:** ✅ / ⚠️ / ❌

## Summary Table
| Check | Status |
|-------|:------:|
| a. Installation | ✅/❌ |
| b. Authentication (user + ADC) | ✅/⚠️/❌ |
| c. Active Project + Region | ✅/⚠️/❌ |
| d. Billing | ✅/⚠️/❌ |
| e. Critical APIs | ✅/⚠️/❌ |
| f. Optional APIs | ✅/⚠️ |
| g. Cloud Run (me-west1 / us-central1 / socialjetopsagent) | ✅/⚠️/❌ |
| h. IAM roles for michal | ✅/❌ |
| i. Service accounts | ✅/⚠️ |
| j. Configurations | ✅ |

## Details
(Each section with raw output, parsed findings, diffs vs expected state.)

## Notes
(Mismatches, unexpected errors, proposed fixes.)
```

## AUTO-FIX LOOP

If any step fails, attempt these fixes via Desktop Commander before giving up (max 3 attempts per step):

1. **gcloud not found at `/opt/homebrew/bin/gcloud`**:
   - `which gcloud` to find an alternate path
   - `brew install --cask google-cloud-sdk` (may prompt for password — document if it does)
2. **Wrong active account**: `gcloud config set account michal@opsagents.agency`
3. **Wrong active project**: `gcloud config set project opsagent-491114`
4. **Region unset**: `gcloud config set compute/region me-west1`
5. **ADC missing**: `gcloud auth application-default login` (requires interactive browser — flag as manual)
6. **API disabled**: `gcloud services enable <api-name> --project=opsagent-491114`
7. **Billing not linked**: flag as manual (requires billing account admin)

Always save the final report regardless of pass/fail count. Document every fix attempt.

## Account Architecture Reference

| Account | Project | Role |
|---------|---------|------|
| michal@opsagents.agency | opsagent-491114 | Primary — OpsAgent core infra, Cloud Run, IAM |
| msmobileapps@gmail.com | opsagent-491114 | Legacy billing owner — same project, org-level |
| socialjetopsagents@gmail.com | socialjetopsagent | SocialJet ops — separate project |

## Cloud Run Free Tier (reference)
- 2M requests/month free
- 360,000 GB-seconds memory free
- 180,000 vCPU-seconds free
- Scales to zero — no idle cost
- Billing must be linked (free tier still applies)

## Autonomy Rules
- Read auth/project/APIs/token/billing/IAM/Cloud Run/service accounts/configs: ✅ always allowed (read-only)
- `gcloud config set` for account/project/region: ✅ allowed in auto-fix loop (reversible)
- `gcloud services enable`: ✅ allowed in auto-fix loop (no cost, already-billed project)
- Create/delete any resource, grant IAM, change billing: ❌ never without explicit user confirmation
