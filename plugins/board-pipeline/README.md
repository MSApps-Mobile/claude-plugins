# board-pipeline

Drain every `To Do` column on a Trello board by doing the work, pushing code, and moving each card to **Code Review**. Stops there. Does NOT review PRs, merge, deploy staging, run QA, or touch prod.

## What it does

Per-card workflow:
1. Read description + AC.
2. **Stale-bug pre-check** — if the card cites a specific file:line bug, fetch the current file at `?ref=main` and grep for the cited pattern. If the bug doesn't reproduce, close direct to **Done** with grep evidence.
3. Ask the project's PM if AC is ambiguous; ask the project's CTO which specialist skill should own the work.
4. Invoke the specialist; do the work.
5. Push every code change; comment on the card with commit SHA + branch + PR URL; move card → **Code Review**.
6. On blocker: move back to `To Do` with a Markdown blocker comment.

## v0.2 — adversarial-review dynamic-workflow opt-in

When the `To Do` column has 10+ cards and most carry file:line bug citations, the pipeline can fan out one subagent per card to verify the citation against `main`. Each subagent reports STALE (close direct to Done) or LIVE (continue to specialist dispatch). Token-spend per dynamic-workflow invocation is logged in the recap; if Trello returns 429, the parallel cap drops from 20 → 10.

Read the full architecture: [Dynamic Workflows in OpsAgents Pipelines](https://www.notion.so/Dynamic-Workflows-in-OpsAgents-Pipelines-Architecture-36f38b5dfb27815480cafb6011f94b0e).

## Skills

### `board-pipeline`

The core skill. Triggered when the user says "drain the board", "run board-pipeline", or hands over a Trello board URL with intent to move cards toward review.

## Trigger phrases

- "Run /board-pipeline against <board URL>"
- "Drain To Do on this board"
- "Move every To Do to Code Review"

## Required surface

- **Trello board** with at least `To Do`, `Code Review`, and an `info` column carrying the repo URL.
- **CLI gateway** with `trello_exec` and `gh_exec` tools (use `cli-gateway-mcp` from this marketplace, or wire your own).

## Sister plugins

- [`backend-pipeline`](../backend-pipeline) — sweeps `Blocked` + `In Progress` + `To Do` in one run, with the cli-dev safety stack pre-loaded for Cloud Run / Secret Manager work.
- [`blocked-pipeline`](../blocked-pipeline) — walks the `Blocked` column and decisions every card.
- [`board-refinement`](../board-refinement) — production-readiness audit, not an execution pass. Use when the cards exist but may be underspecified.

## Canonical home

Active development happens at [OpsAgentsAI/skills-and-plugins](https://github.com/OpsAgentsAI/skills-and-plugins/tree/main/skills/board-pipeline). This marketplace mirror tracks the public-release version.

## Install

```bash
/plugin marketplace add MSApps-Mobile/claude-plugins
/plugin install board-pipeline@msapps-plugins
```
