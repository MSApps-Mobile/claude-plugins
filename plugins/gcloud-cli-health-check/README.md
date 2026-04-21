# gcloud-cli-health-check

A read-only, configurable health check for your Google Cloud CLI (`gcloud`) setup. Runs inside Claude Code / Cowork as a skill — fully generic, works against any GCP project.

## What it does

Walks through 10+ checks against your own GCP environment:

1. `gcloud --version` — CLI presence and minimum version
2. `gcloud auth list` + ADC — authentication state (never prints tokens)
3. `gcloud config list` + `configurations list` — active configuration
4. `gcloud projects describe` + `organizations list` — project / org reachability
5. `gcloud billing projects describe` — billing linkage
6. `gcloud services list --enabled` — required APIs enabled
7. `gcloud artifacts repositories describe` — Artifact Registry (optional)
8. `gcloud run services list` — deployed Cloud Run services
9. `gcloud secrets list` — Secret Manager inventory (values never printed)
10. `gcloud billing budgets list` — budget sanity (optional)
11. Free trial expiry — days remaining warning (optional)

Produces a concise `✅ / ⚠️ / ❌` markdown report with per-check status, action items, and suggested next steps.


## Why you'd install this

If you've ever had a build fail because a service account lost a permission, a deploy fail because an API was disabled, or a surprise bill because a budget alert wasn't wired up — this is the 60-second "is my GCP project actually wired up right?" check.

Works great as:
- A manual reassurance check before a big deploy
- A scheduled daily/weekly run (pair with a GitHub Actions workflow + Workload Identity Federation)
- A diagnostic first step when something stops working

## Configuration

All environment-specific values are driven by env vars. See [`skills/gcloud-cli-health-check/SKILL.md`](skills/gcloud-cli-health-check/SKILL.md#configuration) for the full table. The minimum you need set to get value:

```bash
export GCLOUD_HC_PROJECT="my-project-id"
export GCLOUD_HC_REGION="us-central1"
```

Everything else is optional — uncaptured pieces are reported as informational rather than as failures.

## How it runs gcloud

Most Claude sandboxes don't have `gcloud` installed and can't reach Google endpoints. The skill tries, in order:

1. **Bash in the current environment**, if `gcloud` is on PATH
2. **A shell MCP** on the user's actual machine (e.g. Desktop Commander on macOS)
3. **A BLOCKED report** if neither works — with guidance, not silent failure

For truly headless scheduled runs, the cleanest setup is GitHub Actions + Workload Identity Federation (no stored SA keys). That's out of scope for this skill, but it's the recommended next step if you want this running on a cron.

## Usage

Say any of:

- "Run a gcloud health check"
- "Check gcloud"
- "Is GCP working?"
- "Verify my Google Cloud setup"
- "GCP health check"

…and Claude will invoke the skill, read your configured env vars, run the read-only commands, and produce the report.

## Safety

- **Read-only.** No resource is created, modified, or deleted.
- **Tokens and secret values are never printed**, only their presence/count.
- **No auto-fix.** Every remedial action is surfaced as a command for you to run, not executed by the skill.
- Timeouts on every command so a hanging call can't lock up the check.

## Components

| Component | Name | Purpose |
|---|---|---|
| Skill | `gcloud-cli-health-check` | Runs the full read-only check and produces the report |

## Contributing

Contributions welcome — open a PR on the [MSApps-Mobile/claude-plugins](https://github.com/MSApps-Mobile/claude-plugins) repo.
