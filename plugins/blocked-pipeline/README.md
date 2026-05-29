# blocked-pipeline

Walk the `🚧 Blocked` column on a Trello board — for each card, verify whether its gate has cleared and decision it: **release**, **archive**, **rescope**, or **route to Backlog**. Loops until every blocked card has been decisioned.

"Leave in Blocked" is invalid. The pipeline exits cleanly only when Blocked is empty (modulo true-operator-gate exceptions called out explicitly).

## Decisions

For each blocked card:

1. **Identify the gate.** Parse the description for `GATED on`, `Blocked by`, `Preconditions`, `PARKED until <date>`, or similar. The gate is usually another Trello card, an open PR, an external event, or a date-park.
2. **Verify gate state.** Trello-card gates via `trello_exec`, PR gates via `gh_exec`, date-park gates against today's date.
3. **Decide and act:**
   - **Release** — gate cleared, work still relevant. Move to the right To Do column.
   - **Archive** — gate cleared but work is moot. Close with a `superseded by <X>` comment.
   - **Rescope** — gate cleared but the original plan is wrong. Close + file a replacement card.
   - **Route to Backlog** — gate still active, expected to clear eventually.

## v0.2 — dynamic-workflow gate-state fan-out

When the Blocked column has 8+ cards, the pipeline can spin up a dynamic workflow: one subagent per blocked card, each parsing the gate clause and verifying state. Output is a verdict-per-card table; the decision step (release / archive / rescope / route-to-Backlog) then runs **serially** — read-side parallelism only, write-side stays sequential.

Token spend per dynamic-workflow invocation is logged in the recap. If Trello returns 429, the parallel cap drops from 20 → 10.

Read the full architecture: [Dynamic Workflows in OpsAgents Pipelines](https://www.notion.so/Dynamic-Workflows-in-OpsAgents-Pipelines-Architecture-36f38b5dfb27815480cafb6011f94b0e).

## Skills

### `blocked-pipeline`

The core skill. Triggered when the user says "drain Blocked", "walk the Blocked column", or hands over a Trello board with intent to clear gates.

## Trigger phrases

- "Run /blocked-pipeline against <board URL>"
- "Drain the Blocked column"
- "What's still gated on this board?"

## Required surface

- **Trello board** with `🚧 Blocked`, `🧊 Backlog`, and at least one `To Do` column.
- **CLI gateway** with `trello_exec` and `gh_exec` tools.

## Sister plugins

- [`board-pipeline`](../board-pipeline) — the To Do drain.
- [`backend-pipeline`](../backend-pipeline) — full left-edge sweep with backend safety stack.
- [`board-refinement`](../board-refinement) — production-readiness audit.

## Canonical home

Active development happens at [OpsAgentsAI/skills-and-plugins](https://github.com/OpsAgentsAI/skills-and-plugins/tree/main/skills/blocked-pipeline). This marketplace mirror tracks the public-release version.

## Install

```bash
/plugin marketplace add MSApps-Mobile/claude-plugins
/plugin install blocked-pipeline@msapps-plugins
```
