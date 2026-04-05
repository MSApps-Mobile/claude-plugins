# gcloud-cli-health-check

Scheduled health check plugin for the Google Cloud CLI (`gcloud`) on MSApps machines.

## What it does

Verifies that `gcloud` is installed, authenticated with the correct account (`msmobileapps@gmail.com`), the active project is `opsagent-491114`, critical APIs are enabled, billing is linked, and Cloud Run services are live. Saves a structured `✅/❌` report to the workspace.

## ⚠️ Important: Desktop Commander Required

All `gcloud` commands run via `mcp__Desktop_Commander__start_process` — **not** via the `Bash` tool. The Bash tool runs in a sandboxed Linux environment where `gcloud` is not installed. Desktop Commander runs on the user's real Mac where Google Cloud SDK is available.

## Components

| Component | Name | Purpose |
|-----------|------|---------|
| Skill | `gcloud-cli-health-check` | Runs the full health check and saves a report |

## Setup

Requires Google Cloud SDK installed on the host Mac:
```bash
brew install --cask google-cloud-sdk
gcloud auth login
gcloud config set project opsagent-491114
```

No additional MCPs or environment variables are required.

## Usage

Trigger the skill by saying any of:
- "Run a gcloud health check"
- "Check if gcloud is working"
- "GCP health check"
- "Is Google Cloud authenticated?"
- "Check Cloud Run services"

Or run it via the scheduled task `gcloud-cli-health-check`.

## Output

A report saved to the workspace as `gcloud-health-check-YYYY-MM-DD.md` with:
- ✅/❌/⚠️ table for Installation / Authentication / Active Project / Enabled APIs / API Token / Billing / Cloud Run
- Active account and expected account comparison
- Active project and expected project comparison
- List of enabled APIs with flags for missing critical ones
- Billing status
- Cloud Run services table (name, region, URL)

## Account Architecture

| Account | Project | Role |
|---------|---------|------|
| msmobileapps@gmail.com | opsagent-491114 | Core ops / MSApps infra |
| socialjetopsagents@gmail.com | socialjetopsagent | SocialJet ops — Gmail/Calendar |

## Known Issues & Fixes

### Billing check: do not use `gcloud alpha billing accounts list`

**Problem:** Running `gcloud alpha billing accounts list` triggers an interactive prompt to install beta SDK components, which hangs in automated contexts.

**Fix (v1.0.0):** Use `gcloud billing projects describe $(gcloud config get-value project)` instead. Returns `billingEnabled: true/false` without any component installs.

### gcloud not found in Bash sandbox

**Problem:** The Cowork sandbox (Linux/aarch64) does not have gcloud installed. Running via the Bash tool always fails.

**Fix (v1.0.0):** All gcloud commands run via `mcp__Desktop_Commander__start_process` on the user's Mac where the SDK is installed.
