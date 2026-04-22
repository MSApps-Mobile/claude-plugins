# gcloud-cli-health-check — Plugin Notes

Purpose: a read-only health check for any user's `gcloud` CLI setup. Fully generic — all environment values are driven by `GCLOUD_HC_*` env vars (or inline defaults the user edits in their own fork).

## Runtime paths (in order of preference)

1. **Direct Bash** — if `which gcloud` succeeds in the current environment, just use it.
2. **Shell MCP to the host** — route commands through a shell tool that runs on the user's actual machine (Desktop Commander on macOS, or any equivalent). This is the most common path when the skill runs inside a sandboxed Claude runtime.
3. **GitHub Actions + Workload Identity Federation** — for true headless scheduled runs. Out of scope for the skill itself; recommended as a "next step" when the user wants to run this on a cron.

## What's intentionally NOT in this skill

- No auto-fix. Every remedial action is surfaced as a command the user can run — never executed by the skill itself. This keeps the skill strictly read-only and safe to run in any context.
- No account- or project-specific defaults. If the user hasn't configured something, the check is skipped (`—` in the report), not failed.
- No bootstrapping. If `gcloud` isn't available and can't be routed to a host shell, the skill writes a BLOCKED report and stops — it does not try to install gcloud.

## Key commands used

```bash
gcloud --version
gcloud auth list
gcloud auth application-default print-access-token   # output redirected — token never printed
gcloud config list
gcloud config configurations list
gcloud projects describe <project>
gcloud organizations list
gcloud billing projects describe <project>
gcloud services list --enabled --project=<project>
gcloud artifacts repositories describe <repo> --location=<region> --project=<project>
gcloud run services list --project=<project> --region=<region>
gcloud secrets list --project=<project> --limit=50
gcloud billing budgets list --billing-account=<billing-account>
```

All are read-only.

## Known pitfalls (recorded so reviewers and users don't re-hit them)

- **`gcloud alpha billing accounts list` can prompt to install beta components** and hangs non-interactive runs. Use `gcloud billing projects describe` instead to get `billingEnabled: true/false`.
- **Sandbox environments typically block all Google endpoints** (`dl.google.com`, `oauth2.googleapis.com`, `*.googleapis.com`). Installing or authenticating `gcloud` from inside such a sandbox will not work — route to a host shell or GitHub Actions.
- **ADC (Application Default Credentials) and user auth are separate.** `gcloud auth list` shows user auth; ADC is checked separately via `gcloud auth application-default print-access-token`. Missing ADC is a common source of confusing "it works in CLI but not in my code" issues.
- **Budget currency is locale-driven.** A budget in ILS, EUR, BRL, etc. isn't drift — it reflects the billing account's country. Don't flag a currency mismatch unless the user explicitly configured an expected currency.

## Output

Report printed to chat (and optionally saved to the workspace as
`gcloud-health-check-YYYY-MM-DD.md`):

- One-line ✅/⚠️/❌ summary
- Per-check table (Check | Expected | Actual | Status)
- Action items (with exact commands to run — not executed by the skill)
- Watchlist (non-blocking concerns like growing Artifact Registry size)
- Suggested next steps (WIF for CI, lifecycle rules, budget alerts, etc.)
