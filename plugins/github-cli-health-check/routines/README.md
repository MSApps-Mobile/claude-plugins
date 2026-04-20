# GitHub CLI Health Check — Routine (cloud) setup

This directory packages the **cloud-side** half of the dual-path daily health
check. It runs on Anthropic-managed Claude Code cloud infrastructure
([docs](https://code.claude.com/docs/en/routines)) and is redundant with the
Cowork scheduled task that runs via Desktop Commander on the Mac.

Why both? The Cowork VM sandbox currently blocks `api.github.com`
([claude-code#37970](https://github.com/anthropics/claude-code/issues/37970)).
While that upstream issue is open:

- The **Routine** (this directory) runs on cloud infra that *has* GitHub access
  — this path works today.
- The **Cowork** scheduled task stays wired up via Desktop Commander (Mac gh) —
  this path also works today.
- Running both means a failure on either side still produces a usable report.

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
7. **Trigger**: **Schedule** → **Daily** → `08:00` local time.
   (The Cowork fallback runs later in the day so the two reports don't collide.)
8. Click **Create**, then **Run now** to verify on first go.

### Option B — Register from the CLI

From any Claude Code session on your Mac:

```bash
/schedule daily GitHub CLI health check at 08:00
```

Claude walks you through the form conversationally. Paste the prompt when
asked, select the `MSApps-Mobile/claude-plugins` repo, and either select an
existing `github-cli-health-check` environment or create one with the setup
script above.

To edit later: `/schedule list`, `/schedule update`, `/schedule run`.

## Verifying it works

After the first scheduled run:

1. Open <https://claude.ai/code/routines>, click the Routine, and open the
   latest session.
2. The last reply should be a single markdown code block titled
   `# GitHub CLI Health Check — YYYY-MM-DD (Routine / cloud)` with the
   summary table and all four checks green.
3. If any check is ❌, the report body explains why. Cross-reference against
   the Cowork report for the same day (on the Mac at
   `~/Claude/Scheduled/github-cli-health-check/` or similar, per the
   SKILL.md instructions).

## When #37970 closes

The Cowork VM path will be able to hit `api.github.com` directly and the
Desktop Commander fallback becomes optional. You'll have three viable paths
(Routine, Cowork VM, Cowork DC). Keep the Routine as primary — it's the
lowest-overhead path and doesn't depend on the Mac being awake.

## Troubleshooting

- **"Daily cap reached"**: Pro plan gives 5 runs/day, Max 15, Team/Enterprise
  up to 25. A single daily health check is well inside all tiers.
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
