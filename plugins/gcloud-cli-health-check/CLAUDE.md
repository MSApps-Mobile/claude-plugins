# gcloud-cli-health-check — Task Notes

## Purpose

Health check for the Google Cloud CLI (`gcloud`) and the `opsagent-prod` GCP
project. Verifies installation, authentication, active project + region,
billing, critical + optional APIs, IAM bindings, service accounts, and Cloud
Run services across `me-west1` and `us-central1`. Saves a structured
`✅/⚠️/❌` report to the workspace.

## Three paths (two live, one blocked)

1. **GitHub Actions workflow (primary)** — runs on GitHub-hosted `ubuntu-latest`
   runners. Authenticates to `opsagent-prod` via Workload Identity Federation
   (WIF) — no SA keys, no personal tokens, no expiry. Triggered manually via
   **Actions → GCloud CLI Health Check → Run workflow** or `gh workflow run`.
   Report appears as a GitHub Actions workflow summary.

2. **Cowork + Desktop Commander (fallback)** — runs as a manual Cowork task on
   Michal's Mac. Routes every `gcloud` call through
   `mcp__Desktop_Commander__start_process` to `/opt/homebrew/bin/gcloud`,
   authenticated as `michal@opsagents.agency`. Requires Mac to be on and
   personal token to be fresh (`gcloud auth login` when it expires).

3. **VM Bash — NOT a live path** — the Cowork sandbox is fully blocked for all
   gcloud operations:

   ```
   ❌ VM Bash: gcloud install  — no network to dl.google.com
   ❌ VM Bash: gcloud auth     — no network to oauth2.googleapis.com / accounts.google.com
   ❌ VM Bash: gcloud API calls — no network to *.googleapis.com / sts.googleapis.com
   ```

   Unlike `gh` (where `github.com` git operations still work from the VM),
   gcloud requires Google endpoints at every step — install, auth, and API
   calls. The Cowork proxy blocks all of them with `403 blocked-by-allowlist`.

   **What would unblock it:** the Cowork proxy allowlist adding:
   `dl.google.com`, `sdk.cloud.google.com`, `oauth2.googleapis.com`,
   `accounts.google.com`, `*.googleapis.com`, `sts.googleapis.com`.
   If/when that happens, the VM Bash path becomes viable:
   install gcloud + `gcloud auth login --cred-file=wif-config.json` using
   the WIF credential config (the pool and provider are already set up).

## Critical: Desktop Commander for Cowork path

All `gcloud` commands on the Cowork path use `mcp__Desktop_Commander__start_process`:

```bash
# ✅ Correct (Cowork+DC path)
mcp__Desktop_Commander__start_process("/opt/homebrew/bin/gcloud auth list")

# ❌ Wrong — will always fail
Bash("gcloud auth list")
```

## Key Commands

Both live paths use these commands (GitHub Actions runs them natively;
Cowork+DC wraps them in Desktop Commander):

```bash
gcloud version
gcloud auth list
gcloud auth print-access-token --account=<active-account>
gcloud config list
gcloud config configurations list
gcloud config get-value project
gcloud config get-value compute/region
gcloud projects describe opsagent-prod
gcloud billing projects describe opsagent-prod
gcloud services list --enabled --project=opsagent-prod
gcloud run services list --region=me-west1 --project=opsagent-prod
gcloud run services list --region=us-central1 --project=opsagent-prod
gcloud projects get-iam-policy opsagent-prod \
  --flatten=bindings[].members \
  --filter=bindings.members:<active-account>
gcloud iam service-accounts list --project=opsagent-prod
```

## Expected State

| Check | Expected Value |
|-------|---------------|
| Binary (Mac) | `/opt/homebrew/bin/gcloud` |
| Binary (GitHub Actions) | installed by `google-github-actions/setup-gcloud@v2` |
| Active account (Mac path) | `michal@opsagents.agency` |
| Active account (GHA path) | WIF principal (no SA email) |
| Active project | `opsagent-prod` |
| Region | `me-west1` |
| Billing | enabled |
| `run.googleapis.com` | enabled |
| `cloudbuild.googleapis.com` | enabled |
| `artifactregistry.googleapis.com` | enabled |
| `secretmanager.googleapis.com` | enabled |
| `cloudresourcemanager.googleapis.com` | enabled |
| `iam.googleapis.com` | enabled |
| `iamcredentials.googleapis.com` | enabled |

## WIF Setup (already configured)

| Resource | Value |
|---|---|
| Pool | `claude-routines` (ACTIVE) |
| Provider | `github` (ACTIVE, issuer: `token.actions.githubusercontent.com`) |
| Attribute condition | `assertion.repository=='MSApps-Mobile/claude-plugins'` |
| IAM binding | `roles/viewer` on `opsagent-prod` for the WIF principal |

The WIF pool is scoped to GitHub Actions workflows running from
`MSApps-Mobile/claude-plugins`. It cannot be used from the Cowork VM (no
OIDC token available there) or from Claude Code Routines (not GitHub Actions).

## Output

Report:
- **GitHub Actions path**: workflow summary at
  `github.com/MSApps-Mobile/claude-plugins/actions/workflows/gcloud-health-check.yml`
- **Cowork+DC path**: `gcloud-health-check-YYYY-MM-DD.md` saved to workspace

## Version History

| Version | Date | Change |
|---------|------|--------|
| 1.0.0 | 2026-04-06 | Initial — Desktop Commander only |
| 1.1.0 | 2026-04-20 | Updated primary account to `michal@opsagents.agency`. Added region, critical APIs, multi-region Cloud Run, IAM, service accounts, configurations. Documented sandbox impossibility. |
| 2.0.0 | 2026-04-20 | **Dual-path**: cloud Routine (primary) + Cowork+DC (fallback). New `routines/` directory. Updated primary project to `opsagent-prod` (migrated from `opsagent-491114`). SA key auth for Routine path (no personal token expiry). |
| 3.0.0 | 2026-04-20 | **GitHub Actions as primary** — SA key approach replaced with WIF. New `.github/workflows/gcloud-health-check.yml`. WIF pool `claude-routines` + `roles/viewer` binding on `opsagent-prod`. Three-path documentation (GHA / Cowork+DC / VM Bash blocked). |

## Lessons Learned

### 2026-04-06 (v1.0.0)
- **Sandbox has no gcloud** — always use Desktop Commander on Cowork path.
- **Wrong active account** — skill now flags account mismatches.
- **`gcloud alpha billing accounts list` hangs** — use `gcloud billing projects describe` instead.

### 2026-04-20 (v1.1.0)
- **Scheduled task SKILL.md drift** — two runs produced BLOCKED reports because the task SKILL.md was never updated. Keep task files in sync with the plugin.
- **Primary account changed** to `michal@opsagents.agency` (from `msmobileapps@gmail.com`).
- **Personal token expiry** — non-interactive scheduled runs fail silently when the personal gcloud token expires mid-session.

### 2026-04-20 (v2.0.0 → v3.0.0)
- **SA key creation blocked by org policy** (`constraints/iam.disableServiceAccountKeyCreation`) — correct security posture, do not disable.
- **WIF for Routines doesn't work** — Claude Code Routines are not GitHub Actions and don't receive OIDC tokens from `token.actions.githubusercontent.com`.
- **GitHub Actions IS the right runtime** — WIF pool was already configured, `roles/viewer` binding added, workflow pushed. GitHub Actions runners get OIDC tokens natively.
- **New primary project `opsagent-prod`** — created 2026-04-15 under `opsagents.agency` org. `opsagent-491114` is now legacy (inaccessible from `michal@opsagents.agency`).
- **VM Bash fully blocked** — unlike GitHub where git works from the VM, gcloud requires Google endpoints at every step (install + auth + API). All blocked by proxy.
