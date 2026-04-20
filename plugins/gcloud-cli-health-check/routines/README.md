# GCloud CLI Health Check — Routine (cloud) setup

This directory packages the **cloud-side** half of the dual-path health check.
It runs on Anthropic-managed Claude Code cloud infrastructure
([docs](https://code.claude.com/docs/en/routines)), triggered manually
(no schedule), and is redundant with the Cowork+Desktop Commander task that
runs via `michal@opsagents.agency` on the Mac.

Why both?

- The **Routine** (this directory) uses a service account key — no personal
  token expiry, no Mac required, no Desktop Commander dependency. Primary path.
- The **Cowork+DC** path uses Michal's personal `gcloud` login on the Mac.
  Works when the token is fresh and the Mac is on. Fallback path.

## Files

| File        | Purpose                                                            |
|-------------|--------------------------------------------------------------------|
| `prompt.md` | Prompt body to paste into the Routine creation form.               |
| `setup.sh`  | Cloud environment setup — installs gcloud, activates SA auth.      |
| `README.md` | This file — registration instructions and SA key setup.            |

## Prerequisites

### 1. Create a service account key

The Routine authenticates via a JSON key for
`opsagent-runtime-sa@opsagent-prod.iam.gserviceaccount.com`
(or a dedicated read-only SA — see "Minimal permissions" below).

```bash
# Create a new key for the existing runtime SA
gcloud iam service-accounts keys create /tmp/health-check-sa-key.json \
  --iam-account=opsagent-runtime-sa@opsagent-prod.iam.gserviceaccount.com

# Print the JSON to copy into the Routine env var
cat /tmp/health-check-sa-key.json

# Clean up locally
rm /tmp/health-check-sa-key.json
```

Store the full JSON (single-line or multi-line, both work) as the
`GCLOUD_SA_KEY` environment variable in the Routine's environment config.

### 2. Minimal permissions for a dedicated health-check SA (optional)

If you prefer a read-only SA instead of using `opsagent-runtime-sa`:

```bash
# Create dedicated SA
gcloud iam service-accounts create health-check-sa \
  --display-name="Health Check (read-only)" \
  --project=opsagent-prod

# Grant read-only roles
gcloud projects add-iam-policy-binding opsagent-prod \
  --member="serviceAccount:health-check-sa@opsagent-prod.iam.gserviceaccount.com" \
  --role="roles/viewer"

gcloud projects add-iam-policy-binding opsagent-prod \
  --member="serviceAccount:health-check-sa@opsagent-prod.iam.gserviceaccount.com" \
  --role="roles/run.viewer"

# Then create a key for it as above
```

## One-time setup

### Register from the web (recommended)

1. Open <https://claude.ai/code/routines> and click **New routine**.
2. **Name**: `GCloud CLI health check`
3. **Prompt**: paste the entire contents of `routines/prompt.md`.
4. **Repositories**: add `MSApps-Mobile/claude-plugins`. The setup script
   lives in this repo, so the environment needs it cloned.
5. **Environment**:
   - Create a custom environment named `gcloud-cli-health-check`.
   - **Network access**: unrestricted (or allow `dl.google.com`,
     `*.googleapis.com`, `oauth2.googleapis.com`, `storage.googleapis.com`).
   - **Setup script**: `bash ./plugins/gcloud-cli-health-check/routines/setup.sh`
   - **Environment variables**: add `GCLOUD_SA_KEY` → paste the full SA key JSON.
6. **Connectors**: leave empty (or add Slack/Notion if you want a mirrored copy).
7. **Trigger**: **API** — gives the Routine an on-demand `/fire` endpoint
   and the "Run now" button. **Do not add a Schedule trigger** — manual-only.
   - After saving, click **Generate token** and store it immediately in a
     password manager (shown once only).
8. Click **Create**, then **Run now** to verify.

## Triggering a run

Three ways:

1. **Web UI**: <https://claude.ai/code/routines> → click Routine → **Run now**.
2. **CLI**: `/schedule run gcloud-cli-health-check` from any Claude Code session.
3. **API**:
   ```bash
   curl -X POST "$ROUTINE_FIRE_URL" \
     -H "Authorization: Bearer $GCLOUD_HEALTH_CHECK_TOKEN" \
     -H "anthropic-beta: experimental-cc-routine-2026-04-01" \
     -H "anthropic-version: 2023-06-01" \
     -H "Content-Type: application/json" \
     -d '{"text": "ad-hoc health check"}'
   ```

## Verifying it works

After a run, the last reply should be a single markdown code block titled
`# GCloud CLI Health Check — YYYY-MM-DD (Routine / cloud)` with the summary
table showing all 10 checks.

## Troubleshooting

- **gcloud not on PATH after setup**: check setup script exit trace in the
  session log. The tarball download needs `dl.google.com` to be reachable —
  verify network policy allows it.
- **GCLOUD_SA_KEY missing**: auth step will be ❌. Add the env var to the
  Routine environment config and re-run.
- **403 on billing check**: `opsagent-runtime-sa` needs
  `roles/billing.viewer` or `roles/viewer` on the project. Add it:
  ```bash
  gcloud projects add-iam-policy-binding opsagent-prod \
    --member="serviceAccount:opsagent-runtime-sa@opsagent-prod.iam.gserviceaccount.com" \
    --role="roles/viewer"
  ```
- **SA key rotated / expired**: generate a new key, update the `GCLOUD_SA_KEY`
  env var in the Routine environment config, and delete the old key:
  ```bash
  gcloud iam service-accounts keys list \
    --iam-account=opsagent-runtime-sa@opsagent-prod.iam.gserviceaccount.com
  gcloud iam service-accounts keys delete KEY_ID \
    --iam-account=opsagent-runtime-sa@opsagent-prod.iam.gserviceaccount.com
  ```
