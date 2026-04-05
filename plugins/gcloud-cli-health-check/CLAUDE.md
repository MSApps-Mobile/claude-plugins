# gcloud-cli-health-check — Task Notes

## Purpose

Scheduled health check for the Google Cloud CLI (`gcloud`) on MSApps machines. Verifies installation, authentication, active project, enabled APIs, billing, and Cloud Run services. Saves a structured report to the workspace.

## Critical: Always Use Desktop Commander

The Bash tool runs in a Linux sandbox — gcloud is not installed there. All gcloud commands must use `mcp__Desktop_Commander__start_process`.

```bash
# ✅ Correct
mcp__Desktop_Commander__start_process("gcloud --version")

# ❌ Wrong — will always fail
Bash("gcloud --version")
```

## Key Commands

```bash
gcloud --version
gcloud auth list
gcloud config get-value project
gcloud services list --enabled --format="value(config.name)" --limit=25
gcloud auth print-access-token
gcloud billing projects describe $(gcloud config get-value project)
gcloud run services list --platform=managed --format="table(SERVICE,REGION,URL,LAST_DEPLOYED_BY,LAST_DEPLOYED_AT)"
```

## Expected State

| Check | Expected Value |
|-------|---------------|
| Active account | msmobileapps@gmail.com |
| Active project | opsagent-491114 |
| Billing | enabled |
| run.googleapis.com | enabled |
| gmail.googleapis.com | enabled |
| calendar-json.googleapis.com | enabled |

## Output

Report file: `gcloud-health-check-YYYY-MM-DD.md`  
Saved to workspace outputs folder.

## Version History

| Version | Date | Change |
|---------|------|--------|
| 1.0.0 | 2026-04-06 | Initial release — Desktop Commander only, correct billing command, account/project validation |

## Lessons Learned (2026-04-06)

- **Sandbox has no gcloud** — confirmed on first run. Always use Desktop Commander.
- **Wrong active account** — gcloud was set to `socialjetopsagents@gmail.com` instead of `msmobileapps@gmail.com`. Skill now flags account mismatches.
- **Wrong active project** — was set to an auto-named project instead of `opsagent-491114`. Skill now flags project mismatches.
- **`gcloud alpha billing accounts list` hangs** — prompts to install beta components. Use `gcloud billing projects describe` instead.
- **Cloud Run services confirmed live** — `opsagent-ai-runtime` and `opsagent-dashboard` in us-central1.
