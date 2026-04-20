# gcloud-cli-health-check

Scheduled health check plugin for the Google Cloud CLI (`gcloud`) on MSApps machines.

## What it does

Verifies that `gcloud` is installed, authenticated with the expected account (`michal@opsagents.agency`), the active project is `opsagent-491114`, the region is `me-west1`, critical + optional APIs are enabled, billing is linked, IAM bindings are correct for the active user, service accounts are enumerated, and Cloud Run services are live across the primary (`opsagent-491114`) and secondary (`socialjetopsagent`) projects. Saves a structured `✅/⚠️/❌` report to the workspace.

## ⚠️ Important: Desktop Commander Required

All `gcloud` commands run via `mcp__Desktop_Commander__start_process` — **not** via the `Bash` tool. The Bash tool runs in a sandboxed Linux environment where:
- `gcloud` is not installed
- `apt install` has no sudo and no network to `packages.cloud.google.com`
- The sandbox proxy returns `403 blocked-by-allowlist` for every Google endpoint needed to bootstrap gcloud (`dl.google.com`, `sdk.cloud.google.com`, `oauth2.googleapis.com`, `www.googleapis.com`, `accounts.google.com`)

Desktop Commander runs on the user's real Mac where Google Cloud SDK is available at `/opt/homebrew/bin/gcloud` with auth already configured via the system keyring.

## Components

| Component | Name | Purpose |
|-----------|------|---------|
| Skill | `gcloud-cli-health-check` | Runs the full health check (10 steps) and saves a structured report |

## Setup

Requires Google Cloud SDK installed on the host Mac:
```bash
brew install --cask google-cloud-sdk
gcloud auth login michal@opsagents.agency
gcloud auth application-default login
gcloud config set project opsagent-491114
gcloud config set compute/region me-west1
```

No additional MCPs or environment variables are required. Desktop Commander must be enabled in Cowork.

## Usage

Trigger the skill by saying any of:
- "Run a gcloud health check"
- "Check if gcloud is working"
- "GCP health check"
- "Is Google Cloud authenticated?"
- "Check Cloud Run services"

Or run it via the scheduled task `gcloud-cli-health-check` (legacy name: `gcloud-health-check`).

## What it checks (10 steps)

| # | Step | What it validates |
|---|---|---|
| a | Installation | `gcloud --version` returns successfully |
| b | Authentication | `auth list` + user access token + ADC token |
| c | Project + region | Active project is `opsagent-491114`, region `me-west1`, lifecycle ACTIVE |
| d | Billing | `billingEnabled: true` on the project |
| e | Critical APIs | run, cloudbuild, artifactregistry, secretmanager, cloudresourcemanager, iam |
| f | Optional APIs | gmail, calendar-json, monitoring, logging |
| g | Cloud Run | Services in me-west1, us-central1, and socialjetopsagent |
| h | IAM | Roles granted to `michal@opsagents.agency` on `opsagent-491114` |
| i | Service accounts | Enumeration via `gcloud iam service-accounts list` |
| j | Configurations | `gcloud config configurations list` |

## Auto-fix loop

For any failing check, the skill attempts reversible fixes automatically:

| Failure | Fix |
|---|---|
| Wrong active account | `gcloud config set account michal@opsagents.agency` |
| Wrong project | `gcloud config set project opsagent-491114` |
| Region unset | `gcloud config set compute/region me-west1` |
| API disabled | `gcloud services enable <api>` |
| Billing unlinked | flagged as manual (requires billing admin) |
| ADC missing | flagged as manual (needs interactive browser) |

Max 3 attempts per step. Every attempt logged in the report.

## Output

A report saved to the workspace as `gcloud-health-check-YYYY-MM-DD.md` with:
- ✅/⚠️/❌ summary table for all 10 checks
- Raw command output per section
- Parsed findings vs expected state
- Auto-fix attempt log
- Notes + proposed manual fixes for anything the auto-loop couldn't handle

## Account Architecture

| Account | Project | Role |
|---------|---------|------|
| michal@opsagents.agency | opsagent-491114 | Primary — OpsAgent core infra, Cloud Run, IAM |
| msmobileapps@gmail.com | opsagent-491114 | Legacy billing owner — same project, org-level |
| socialjetopsagents@gmail.com | socialjetopsagent | SocialJet ops — separate project |

## Known Issues & Fixes

### Sandbox Bash cannot run gcloud (v1.0.0+)

**Problem:** The Cowork sandbox (Linux/aarch64) does not have gcloud, cannot install it (no sudo, no network to Google), and the proxy returns 403 for every Google endpoint.

**Fix:** All gcloud commands run via `mcp__Desktop_Commander__start_process` on the user's Mac. If Desktop Commander is unavailable, the skill writes a BLOCKED report and stops — it does NOT try to install gcloud in the sandbox.

### Billing check must use the right command (v1.0.0+)

**Problem:** `gcloud alpha billing accounts list` triggers an interactive install prompt for beta components, which hangs in automated contexts.

**Fix:** Use `gcloud billing projects describe opsagent-491114` — returns `billingEnabled: true/false` without any component installs.

### Scheduled task SKILL.md drift (v1.1.0)

**Problem:** Two consecutive scheduled runs (2026-04-19 and 2026-04-20) produced identical BLOCKED reports because the scheduled-task's local `SKILL.md` was still the old sandbox-Bash version, not this plugin's Desktop Commander skill.

**Fix:** Keep the scheduled-task file in sync with this plugin's SKILL.md, or install this plugin into the Cowork session so the scheduled task loads it directly.

### Primary account change (v1.1.0)

**Problem:** v1.0.0 expected `msmobileapps@gmail.com` as the active account. Michal now operates from `michal@opsagents.agency`.

**Fix:** v1.1.0 expects `michal@opsagents.agency`. `msmobileapps@gmail.com` is flagged ⚠️ (legacy billing owner) rather than ❌.
