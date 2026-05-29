# board-refinement

**Production-grade Trello board refinement routine.** Assumes coding work is already drafted and the question is whether the board, the PRDs, the staging surface, the test coverage, and the pre-prod prerequisites are all production-grade.

Distinct from the sister pipelines: this is a **production-readiness audit**, not an execution pass.

## Four stages

1. **PM + CTO plan + PRD gap audit.** Read each card's PRD. Surface missing AC, missing test scenarios, missing staging URL, missing observability, missing tenant-isolation guards, missing rate-limit / abuse considerations, missing rollback path, missing pre-prod prerequisites.
2. **CTO deploy-gate verdict + staging spin-up.** Verdict each card PASS / REJECT for staging. If no staging URL exists, spin one up (Firebase Hosting preview channel for frontends, Cloud Run `--no-traffic`-tagged revision for backend).
3. **QA TDD audit-or-write + sanity test against PRD.** Check test coverage; if missing, write the tests. Sanity-test the staging surface against the PRD.
4. **Pre-prod readiness verification.** Confirm secrets present, env-var bindings correct (rule-#20 / rule-#23 compliance), DNS live, CI workflow registry not desynced, rollback revision reachable.

Each stage either advances the card or bounces it back to a To Do column with a detailed refinement brief.

## v0.2 — adversarial-review dynamic-workflows

This skill carries **two** dynamic-workflow opt-ins — the single highest-leverage application of dynamic workflows in the pipeline stack.

- **Stage 1 (PRD gap audit).** For boards with 10+ cards or when prod risk is high: two adversarial agents iterate on each card's PRD until they converge on a gap list. One argues "production-grade as written"; the other tries to refute by surfacing missing AC / env-vars / staging URL / observability / tenant-isolation / rollback. A third agent files each gap as a refinement-brief card. Adversarial review directly attacks rule-#20 / rule-#23 misses (missed env vars, wrong canonical name) before they reach deploy.

- **Stage 4 (pre-prod readiness gate).** Before invoking the deploy specialist: one agent argues "deploy this card to prod now", another tries to refute by checking secrets present, grep-before-spec, DNS live, CI workflow registry not desynced, rollback revision reachable. If "refute" wins, the card bounces per the failure branch.

Both opt-ins log token spend per invocation in the recap (dedicated `💸 DYNAMIC-WORKFLOW TOKEN SPEND` block). If Trello returns 429, the parallel cap drops from 20 → 10.

Read the full architecture: [Dynamic Workflows in OpsAgents Pipelines](https://www.notion.so/Dynamic-Workflows-in-OpsAgents-Pipelines-Architecture-36f38b5dfb27815480cafb6011f94b0e).

## Skills

### `board-refinement`

The core skill. Triggered when the user says "refine the board", "prod-grade refinement", "harden the board for prod", "PRD-gap audit", "is this board ready to ship", or hands over a board with intent to harden it for production.

## Trigger phrases

- "Run /board-refinement on <board URL>"
- "Production-grade pass on this board"
- "Is this board ready to ship?"
- "Audit PRDs against rule-#20 / rule-#23"

## Required surface

- **Trello board** with at least `To Do`, `Code Review`, `Deploy Staging`, `QA`, `Deploy Prod`, `Done`, and `🚧 Blocked`.
- **CLI gateway** with `trello_exec`, `gh_exec`, and `gcloud_exec` tools.

## Sister plugins

- [`board-pipeline`](../board-pipeline) — drives cards through the 7-stage flow. Use AFTER refinement if execution remains.
- [`backend-pipeline`](../backend-pipeline) — full left-edge sweep with backend safety stack.
- [`blocked-pipeline`](../blocked-pipeline) — walks the Blocked column.

## Canonical home

Active development happens at [OpsAgentsAI/skills-and-plugins](https://github.com/OpsAgentsAI/skills-and-plugins/tree/main/skills/board-refinement). This marketplace mirror tracks the public-release version.

## Install

```bash
/plugin marketplace add MSApps-Mobile/claude-plugins
/plugin install board-refinement@msapps-plugins
```
