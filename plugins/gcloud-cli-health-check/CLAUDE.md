# gcloud-cli-health-check — Task Notes

## Purpose

Scheduled health check for the Google Cloud CLI (`gcloud`) on MSApps machines. Verifies installation, authentication, active project + region, billing, critical + optional APIs, IAM bindings for the active account, service accounts, and Cloud Run services across the primary (`opsagent-491114`) and secondary (`socialjetopsagent`) projects. Saves a structured report to the workspace outputs folder.

## Critical: Always Use Desktop Commander

The Bash tool runs in a Linux sandbox where gcloud is not installed AND the sandbox proxy returns `403 blocked-by-allowlist` for every Google endpoint needed to bootstrap it. There is no workaround inside the sandbox (no sudo, no network to Google). All gcloud commands must use `mcp__Desktop_Commander__start_process` to run on the user's real Mac where `gcloud` lives at `/opt/homebrew/bin/gcloud`.

```bash
# ✅ Correct
mcp__Desktop_Commander__start_process("/opt/homebrew/bin/gcloud auth list")

# ❌ Wrong — will always fail with "command not found" or 403 proxy block
Bash("gcloud auth list")
```

## Decision Flow

### Step 1 — Check Desktop Commander availability
If `mcp__Desktop_Commander__start_process` is available → use it for everything.

### Step 2 — If Desktop Commander unavailable
Do **not** try the Bash tool. It cannot work:
- `gcloud` is not in the sandbox image
- `apt install google-cloud-cli` fails — no sudo, no network to `packages.cloud.google.com`
- Direct tarball download from `dl.google.com` fails — 403 blocked-by-allowlist
- `pip install google-cloud-sdk` fails — the SDK is not on PyPI

Write a report documenting the block and stop. Flag for manual run or suggest migrating the check to a GitHub Action with Workload Identity Federation.

## Key Commands

All prefixed with `/opt/homebrew/bin/gcloud` when running via Desktop Commander.

```bash
gcloud --version
gcloud auth list
gcloud auth print-access-token --account=michal@opsagents.agency
gcloud auth application-default print-access-token
gcloud config get-value project
gcloud config get-value compute/region
gcloud projects describe opsagent-491114
gcloud billing projects describe opsagent-491114
gcloud services list --enabled --project=opsagent-491114
gcloud run services list --region=me-west1 --project=opsagent-491114
gcloud run services list --region=us-central1 --project=opsagent-491114
gcloud run services list --project=socialjetopsagent
gcloud projects get-iam-policy opsagent-491114 --flatten=bindings[].members --filter=bindings.members:michal@opsagents.agency
gcloud iam service-accounts list --project=opsagent-491114
gcloud config configurations list
```

## Expected State

| Check | Expected Value |
|-------|---------------|
| Binary | `/opt/homebrew/bin/gcloud` (macOS, Homebrew) |
| Active account | `michal@opsagents.agency` |
| Active project | `opsagent-491114` |
| Region | `me-west1` |
| Billing | enabled |
| `run.googleapis.com` | enabled |
| `cloudbuild.googleapis.com` | enabled |
| `artifactregistry.googleapis.com` | enabled |
| `secretmanager.googleapis.com` | enabled |
| `cloudresourcemanager.googleapis.com` | enabled |
| `iam.googleapis.com` | enabled |

## Output

Report file: `gcloud-health-check-YYYY-MM-DD.md`
Saved to workspace outputs folder. Overwrites any same-day BLOCKED report.

## Version History

| Version | Date | Change |
|---------|------|--------|
| 1.0.0 | 2026-04-06 | Initial — Desktop Commander only, correct billing command, account/project validation |
| 1.1.0 | 2026-04-20 | Updated primary account to `michal@opsagents.agency` (from `msmobileapps@gmail.com`). Added region check (`me-west1`). Added critical APIs (cloudbuild, artifactregistry, secretmanager, resourcemanager, iam). Added multi-region + multi-project Cloud Run checks (me-west1, us-central1, socialjetopsagent). Added IAM role lookup for active user. Added service account enumeration. Added configurations list. Added auto-fix loop with reversible `gcloud config set` calls. Explicit documentation that the sandbox is unusable — no more "try Bash first" dead-end. |

## Lessons Learned

### 2026-04-06 (v1.0.0)
- **Sandbox has no gcloud** — confirmed on first run. Always use Desktop Commander.
- **Wrong active account** — gcloud was set to `socialjetopsagents@gmail.com` instead of `msmobileapps@gmail.com`. Skill now flags account mismatches.
- **Wrong active project** — was set to an auto-named project instead of `opsagent-491114`. Skill now flags project mismatches.
- **`gcloud alpha billing accounts list` hangs** — prompts to install beta components. Use `gcloud billing projects describe` instead.
- **Cloud Run services confirmed live** — `opsagent-ai-runtime` and `opsagent-dashboard` in us-central1.

### 2026-04-20 (v1.1.0)
- **Two consecutive scheduled runs (2026-04-19, 2026-04-20) produced identical BLOCKED reports** — the scheduled task at `/sessions/<session>/mnt/gcloud-health-check/SKILL.md` had never been updated to match this plugin's Desktop Commander pattern. It was still calling gcloud via sandbox Bash. Fix: keep the scheduled-task SKILL.md in sync with this plugin's skill, or install this plugin directly into the Cowork session.
- **Sandbox proxy hard-blocks Google** — full allowlist probe (dl.google.com, sdk.cloud.google.com, oauth2.googleapis.com, www.googleapis.com, accounts.google.com, packages.cloud.google.com, cloud.google.com) all returned `X-Proxy-Error: blocked-by-allowlist`. Do not retry install paths — they are architecturally impossible.
- **Primary account is now `michal@opsagents.agency`**, not `msmobileapps@gmail.com`. `msmobileapps` remains the legacy billing owner but Michal operates from the opsagents.agency workspace.
- **Added IAM + service-account + configuration checks** per the scheduled-task spec — they were missing from v1.0.0.
