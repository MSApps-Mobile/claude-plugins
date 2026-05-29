# backend-pipeline

Backend-flavored Trello sweep — drains `🚧 Blocked` + `In Progress` / `Doing` + every `To Do` column to **Code Review** in one run. Wraps [`blocked-pipeline`](../blocked-pipeline) (for the Blocked decision tree) and [`board-pipeline`](../board-pipeline) (for the In Progress + To Do drain), with the cli-dev + gcloud-devops-expert safety stack pre-loaded for any card touching Cloud Run, Secret Manager, or `services/cli-gateway*`.

Does NOT review PRs, merge, deploy staging, run QA, or touch prod.

## Why "backend-flavored"

Cards that touch backend infra carry three sharp landmines this pipeline pre-loads guards for:

- **Cloud Run secret semantics** — `--set-secrets` REPLACES the entire list; `--update-secrets` MERGES. A single misuse can wipe production secrets. Pipeline ensures every coding card touching env-var bindings goes through cli-dev with merge-only semantics.
- **Captcha-walled boards** — sites behind reCAPTCHA / Cloudflare Turnstile use an operator cookie-injection path, NOT a captcha-solver SaaS. Pipeline rejects cards that propose the wrong path before the PR opens.
- **Grep before spec** — before introducing a new env var, grep the consumer service's source for the canonical name. Mismatched names deploy cleanly and 503 at runtime.

## v0.2 — dynamic-workflow guard

If a card touching `services/cli-gateway*`, Cloud Run env-var bindings, or Secret Manager writes is part of a multi-card dynamic-workflow fan-out, the pipeline **excludes that card from the parallel batch** and routes it serially. Concurrent writes against the same canonical-secret list deterministically wipe whatever each parallel agent hasn't read yet. Parallelism is fine for reads; writes through the cli-gateway stay one-at-a-time.

Token spend per dynamic-workflow invocation is rolled up from the wrapped pipelines' recaps so a runaway loop is caught before it eats the day's budget.

Read the full architecture: [Dynamic Workflows in OpsAgents Pipelines](https://www.notion.so/Dynamic-Workflows-in-OpsAgents-Pipelines-Architecture-36f38b5dfb27815480cafb6011f94b0e).

## Skills

### `backend-pipeline`

The wrapper skill. Triggered when the user says "run backend-pipeline" or hands over a Trello board with backend / infra / cli-gateway work and asks for a full left-edge sweep.

## Trigger phrases

- "Run /backend-pipeline against <board URL>"
- "Sweep Blocked + In Progress + To Do on this backend board"
- "Drain the board, watch out for Cloud Run secrets"

## Required surface

- **Trello board** with at least `🚧 Blocked`, `🧊 Backlog`, `To Do`, `Code Review`, and an `info` column.
- **CLI gateway** with `trello_exec`, `gh_exec`, and `gcloud_exec` tools.

## Sister plugins

- [`board-pipeline`](../board-pipeline) — the To Do drain. Called by this plugin.
- [`blocked-pipeline`](../blocked-pipeline) — the Blocked decision tree. Called by this plugin.
- [`board-refinement`](../board-refinement) — production-readiness audit, not an execution pass.

## Canonical home

Active development happens at [OpsAgentsAI/skills-and-plugins](https://github.com/OpsAgentsAI/skills-and-plugins/tree/main/skills/backend-pipeline). This marketplace mirror tracks the public-release version.

## Install

```bash
/plugin marketplace add MSApps-Mobile/claude-plugins
/plugin install backend-pipeline@msapps-plugins
```
