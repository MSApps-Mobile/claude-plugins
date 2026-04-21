---
name: gcloud-cli-health-check
description: Read-only health check of a gcloud CLI setup — verify install, auth, active project, billing, enabled APIs, Artifact Registry, Cloud Run, Secret Manager, and budget. Use when the user says "run a gcloud health check", "check gcloud", "is GCP working", "verify my Google Cloud setup", "GCP health check", or any request to confirm the Google Cloud CLI is operational. Works against any GCP account — configure via env vars or the Configuration block below.
---

# gcloud-cli-health-check

Run a read-only, configurable health check of a `gcloud` CLI setup. Every check is parameterized — fill in the Configuration block (or export env vars) with your own GCP project, account, region, etc., and the skill adapts. Nothing is created, modified, or deleted.

---

## Configuration

Before the first run, provide your environment. Precedence: **env vars** (`GCLOUD_HC_*`) take priority; if unset, fall back to the **inline defaults below**; if neither is set, read the current value from `gcloud config` where possible; otherwise skip the check and mark it `—` in the report.

| Variable | Env var | Example | Notes |
|---|---|---|---|
| Active account | `GCLOUD_HC_ACCOUNT` | `you@example.com` | Leave blank to accept whatever `gcloud config get account` returns. |
| Project ID | `GCLOUD_HC_PROJECT` | `my-project-prod` | Required for most checks; default = `gcloud config get project`. |
| Project Number | `GCLOUD_HC_PROJECT_NUMBER` | `123456789012` | Optional — only used for verification. |
| Organization ID | `GCLOUD_HC_ORG_ID` | `987654321098` | Optional — skip org check if absent. |
| Billing Account | `GCLOUD_HC_BILLING_ACCOUNT` | `012345-ABCDEF-123456` | Optional — skip billing-account verification if absent. |
| Region | `GCLOUD_HC_REGION` | `us-central1` | Default for Cloud Run + Artifact Registry. |
| Artifact Registry repo | `GCLOUD_HC_AR_REPO` | `my-docker-repo` | Optional — skip AR check if absent. |
| Required APIs | `GCLOUD_HC_REQUIRED_APIS` | comma-separated list | See default list below. |
| Budget display name | `GCLOUD_HC_BUDGET_NAME` | `Monthly-Budget` | Optional — skip budget check if absent. |
| Budget amount | `GCLOUD_HC_BUDGET_AMOUNT` | `50` | Match the value configured in GCP. |
| Budget currency | `GCLOUD_HC_BUDGET_CURRENCY` | `USD` | Currency is usually dictated by the billing account's locale — **do not flag a mismatch here as drift**; only flag if the user explicitly asked for a specific currency. |
| Min gcloud version | `GCLOUD_HC_MIN_VERSION` | `450.0.0` | Default `450.0.0`. |
| Trial expiry | `GCLOUD_HC_TRIAL_EXPIRY` | `2026-12-31` | Optional — warn if < 30 days. |
| Expected Cloud Run services | `GCLOUD_HC_EXPECTED_SERVICES` | `svc-a,svc-b` | Optional — list of expected services. Missing ones flagged ⚠️. |

**Default required APIs** (used when `GCLOUD_HC_REQUIRED_APIS` is unset):
`run.googleapis.com, cloudbuild.googleapis.com, artifactregistry.googleapis.com, secretmanager.googleapis.com, iam.googleapis.com, compute.googleapis.com, monitoring.googleapis.com, logging.googleapis.com, billingbudgets.googleapis.com, cloudresourcemanager.googleapis.com`.

**If required config for a check is missing**, skip it and mark the row `—` (N/A). Don't fail the whole run because the user hasn't configured an optional feature.

---

## Where to run `gcloud`

Most Claude runtimes (including the Cowork/Claude Code sandbox) don't have `gcloud` installed and can't reach Google APIs (`dl.google.com`, `oauth2.googleapis.com`, `*.googleapis.com`) — any install or auth attempt from inside the sandbox will fail.

Pick the first available path:

1. **Direct Bash** — if `which gcloud` returns a path and `gcloud auth list` succeeds, just use Bash.
2. **Shell MCP to the host** — route every command through a shell MCP that runs on the user's actual machine (e.g. Desktop Commander on macOS, or any other shell tool that has `gcloud` on PATH and a valid credential).
3. **GitHub Actions via Workload Identity Federation** — for truly headless/scheduled runs, set up a workflow that uses `google-github-actions/auth@v2` with WIF. This avoids storing service-account keys. (Out of scope for this skill; flag as a next step if you find yourself running this on a schedule.)

If none are available, write a short BLOCKED report explaining why and stop. **Do not try to bootstrap gcloud inside a sandbox** — it will burn minutes and silently fail.

Typical gcloud paths:
- macOS (Apple Silicon): `/opt/homebrew/bin/gcloud`
- macOS (Intel) / Linux (brew): `/usr/local/bin/gcloud`
- Linux (snap): `/snap/bin/gcloud`
- Linux (apt, Google SDK package): `/usr/bin/gcloud`

---

## Steps to execute

Run these read-only commands in order. For each, record what was returned and compare to the configured expectation.

### 1. CLI presence & version

```bash
gcloud --version
```

Confirm the version is ≥ the configured minimum (default `450.0.0`). Note the installed components (core, bq, gsutil).

### 2. Auth state

```bash
gcloud auth list
gcloud auth application-default print-access-token >/dev/null 2>&1 && echo OK || echo FAIL
```

- Confirm the configured account is `ACTIVE`. Other accounts are ⚠️ (not ❌) unless the user asked for them to be removed.
- The ADC check should succeed. **Never print the token** — only report OK / FAIL.

### 3. Active configuration

```bash
gcloud config list
gcloud config configurations list
```

Verify `account` and `project` match config. Note any additional named configurations so the user knows they exist.

### 4. Project & org reachability

```bash
gcloud projects describe "$PROJECT" --format="value(projectNumber,lifecycleState,labels)"
# If an org ID is configured:
gcloud organizations list
```

- Project lifecycle must be `ACTIVE`.
- If a project number is configured, verify it matches.
- If an org ID is configured, confirm it appears in the org list.

### 5. Billing linkage

```bash
gcloud billing projects describe "$PROJECT"
```

Confirm `billingEnabled: true`. If a billing account ID is configured, confirm the linked account matches.

> ⚠️ Do **not** use `gcloud alpha billing accounts list` — it can prompt to install beta components, which hangs non-interactive runs.

### 6. Enabled APIs

```bash
gcloud services list --enabled --project="$PROJECT" --format="value(config.name)"
```

Confirm every API in the required list is enabled. Each missing one is ❌ with a one-line fix: `gcloud services enable <api> --project="$PROJECT"` (report it — do not execute it; this skill is read-only).

### 7. Artifact Registry repo (skip if not configured)

```bash
gcloud artifacts repositories describe "$AR_REPO" --location="$REGION" --project="$PROJECT"
```

- Confirm `format` (usually `DOCKER`) and `location`.
- Note the repo size. If it has grown significantly since the previous run, surface a watchlist item suggesting a lifecycle policy (e.g. delete untagged images older than 14 days, keep the last N tagged versions).

### 8. Cloud Run services

```bash
gcloud run services list --project="$PROJECT" --region="$REGION"
```

- Report every service found (name, URL, last deployed at, last deployed by).
- If `GCLOUD_HC_EXPECTED_SERVICES` is set, any missing expected service is ⚠️.
- Do **not** invent expectations — only flag based on what the user configured.

### 9. Secret Manager

```bash
gcloud secrets list --project="$PROJECT" --limit=50
```

Report count and names. **Never print values.** If the count is unexpectedly different from a previous run and the user keeps history, surface it; otherwise just report.

### 10. Budget (skip if not configured)

```bash
gcloud billing budgets list --billing-account="$BILLING_ACCOUNT"
```

- Find the budget whose `displayName` matches `GCLOUD_HC_BUDGET_NAME`.
- Confirm `amount.specifiedAmount.units == GCLOUD_HC_BUDGET_AMOUNT`.
- Confirm `thresholdRules` at 50%, 80%, 100% (or whatever the user has configured — if they've set custom thresholds, respect those).
- **Currency**: a currency other than expected is usually set by the billing account's locale and is by design. Do not flag currency mismatch unless the user explicitly configured a currency.

### 11. Free trial / credits (optional)

If `GCLOUD_HC_TRIAL_EXPIRY` is set, compute days remaining and warn if < 30. Otherwise skip.

---

## Output format

Produce a concise markdown report:

1. **One-line header**: `✅` (all green), `⚠️` (non-critical drift / watchlist), or `❌` (at least one critical failure), followed by a one-sentence summary.
2. **Per-check table**:

   ```
   | # | Check | Expected | Actual | Status |
   ```

3. **Action items** — one bullet per real problem. Include the exact command the user should run to fix it (but do not run it).
4. **Watchlist** — non-blocking things to keep an eye on (growing Artifact Registry, secret count changes, expiring trial, etc.).
5. **Suggested next steps** *(only if relevant)*: Workload Identity Federation for CI, Artifact Registry lifecycle rules, Secret Manager consolidation, deletion of stale/unused projects, budget alerts if none exist.

Keep it under ~40 lines unless there are real problems to expand on.

---

## Constraints

- **Read-only.** Never create, modify, or delete GCP resources. Every suggestion is reported as a command the user can run themselves.
- **Never print** access tokens, ADC tokens, secret values, service-account keys, or billing account digits beyond what the user already configured.
- **Skip, don't fail**, when optional config is missing — mark the row `—`.
- **Don't bootstrap gcloud** inside a sandbox that blocks Google endpoints. Write a BLOCKED report and stop.
- **Stay under budget**: the whole check should finish in a minute or two. If a command hangs, time it out and mark that row ⚠️ with the stderr.

---

## Common setup commands (reference for new users)

```bash
# Install (macOS / Homebrew)
brew install --cask google-cloud-sdk

# Install (Linux / Debian-based)
# See https://cloud.google.com/sdk/docs/install

# Authenticate (opens browser)
gcloud auth login

# Set ADC (opens browser; used by SDKs)
gcloud auth application-default login

# Pick a default project
gcloud config set project <PROJECT_ID>

# Pick a default region
gcloud config set compute/region <REGION>
```

These are reference — the skill itself never runs them. If a user's `gcloud` isn't set up, the skill reports the gap and points them at the commands above.
