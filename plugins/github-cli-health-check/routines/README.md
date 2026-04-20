# GitHub CLI Health Check — Routine (cloud) setup

This directory packages the **cloud-side** half of the dual-path health check.
It runs on Anthropic-managed Claude Code cloud infrastructure
([docs](https://code.claude.com/docs/en/routines)), triggered manually
(no schedule), and is redundant with the Cowork manual task that runs via
Desktop Commander on the Mac.

Why both? The Cowork VM sandbox currently blocks `api.github.com`
([claude-code#37970](https://github.com/anthropics/claude-code/issues/37970)).
While that upstream issue is open:

- The **Routine** (this directory) runs on cloud infra that *has* GitHub access
  — this path works today.
- The **Cowork** task stays wired up via Desktop Commander (Mac gh) — also
  works today.
- Both are **manual-only** — invoke whichever is convenient. A failure on
  one side is still caught by the other when you run both.

## Files

| File        | Purpose                                                        |
|-------------|----------------------------------------------------------------|
| `prompt.md` | The prompt body you paste into the Routine creation form.      |
| `setup.sh`  | Cloud environment setup script — installs `gh`, wires auth.    |
| `README.md` | This file — registration instructions.                         |

## One-time setup

Prerequisite: Claude Code v2.1.111 or newer on your Mac (routines shipped
alongside this release). Run `claude --version` to check, or upgrade via
`claude upgrade`.

### Option A — Register from the web (recommended)

1. Open <https://claude.ai/code/routines> and click **New routine**.
2. **Name**: `GitHub CLI health check`
3. **Prompt**: paste the entire contents of `routines/prompt.md`.
4. **Repositories**: add `MSApps-Mobile/claude-plugins`. The setup script
   lives in this repo, so the environment needs it cloned.
5. **Environment**:
   - Create a custom environment named `github-cli-health-check` if you don't
     already have one. In the environment config:
     - **Network access**: unrestricted (or at minimum allow `api.github.com`,
       `github.com`, `raw.githubusercontent.com`, and the `gh` release host
       `objects.githubusercontent.com`).
     - **Setup script**: `bash ./plugins/github-cli-health-check/routines/setup.sh`
     - **Environment variables**: none required — the Claude GitHub App
       provides `GITHUB_TOKEN` at runtime, and `setup.sh` re-exports it as
       `GH_TOKEN` for `gh`.
6. **Connectors**: leave empty unless you want the report mirrored somewhere
   (e.g., Slack / Notion). The session transcript is the canonical report.
7. **Trigger**: **API** — gives the Routine an on-demand `/fire` endpoint
   *and* the "Run now" button in the web UI. **Do not add a Schedule trigger**
   — you want manual-only.
   - After saving, click **Generate token** in the API trigger modal and
     copy the token immediately (it's shown once). Store it somewhere safe —
     a password manager, your shell's secret store, or a local env var like
     `GITHUB_HEALTH_CHECK_TOKEN` in your `~/.zshrc`.
8. Click **Create**, then **Run now** on the Routine's detail page to verify
   it works. The "Run now" button doesn't need the API token — only external
   callers do.

### Option B — Register from the CLI

CLI `/schedule` is biased toward scheduled triggers, so the web UI is the
cleaner path for a manual-only Routine. If you prefer CLI anyway, create a
minimal Routine with `/schedule` and then edit it on the web to remove the
schedule and add an API trigger.

To interact with an existing Routine later: `/schedule list`,
`/schedule update`, `/schedule run <name>` (triggers a run without hitting
the API endpoint).

## Triggering a run

Three ways to run the Routine on-demand:

1. **Web UI**: open <https://claude.ai/code/routines>, click the Routine, hit
   **Run now**. Session appears in the sidebar.
2. **CLI**: `/schedule run github-cli-health-check` from any Claude Code
   session on your Mac.
3. **API** (curl / script / alerting tool):

   ```bash
   curl -X POST "$ROUTINE_FIRE_URL" \
     -H "Authorization: Bearer $GITHUB_HEALTH_CHECK_TOKEN" \
     -H "anthropic-beta: experimental-cc-routine-2026-04-01" \
     -H "anthropic-version: 2023-06-01" \
     -H "Content-Type: application/json" \
     -d '{"text": "ad-hoc health check"}'
   ```

   `$ROUTINE_FIRE_URL` is the URL shown in the API trigger modal; the token
   is the one you generated at registration time.

## Verifying it works

After a run:

1. Open the session (either from the response URL or the routine detail page).
2. The last reply should be a single markdown code block titled
   `# GitHub CLI Health Check — YYYY-MM-DD (Routine / cloud)` with the
   summary table and all four checks green.
3. If any check is ❌, the report body explains why. Cross-reference against
   a Cowork run of the same check on your Mac, which writes its report to
   `~/Claude/Scheduled/github-cli-health-check/` per SKILL.md.

## When #37970 closes

The Cowork VM path will be able to hit `api.github.com` directly and the
Desktop Commander fallback becomes optional. You'll have three viable paths
(Routine, Cowork VM, Cowork DC). Keep the Routine as primary — it's the
lowest-overhead path and doesn't depend on the Mac being awake.

## Troubleshooting

- **"Daily cap reached"**: Pro plan gives 5 runs/day, Max 15, Team/Enterprise
  up to 25. Manual-only usage is well inside all tiers — this only bites if
  you hammer the `/fire` endpoint.
- **gh not on PATH after setup**: the setup script tries system-wide install
  first (needs `sudo`), then user-local under `$HOME/.local/bin`. Check the
  setup script's stdout in the session log. If both failed, grant sudo in the
  environment config or switch to a Debian-based image with apt.
- **`gh auth status` says "not logged in"** even though `GITHUB_TOKEN` is set:
  the token scopes may be too narrow. The Claude GitHub App token is
  repo-scoped by default — fine for `repo list` and `rate_limit`, but
  `gh auth status` will show the token source as `GH_TOKEN env var` rather
  than OAuth. That's normal; all checks still work.
- **Rate limit shows 60/hr instead of 5000/hr**: the token wasn't picked up
  and `gh` is making unauthenticated calls. Verify `GH_TOKEN` export worked.
