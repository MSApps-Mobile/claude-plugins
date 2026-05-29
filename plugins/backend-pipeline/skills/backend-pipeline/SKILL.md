---
name: backend-pipeline
description: "Backend pipeline — sweeps Blocked, In Progress, and every To Do column in one run. Drains Blocked via the /blocked-pipeline workflow (release / archive / rescope / route-to-Backlog), then finishes any In Progress / Doing work, then drains the To Do columns. Every shipped card ends in Code Review with commit SHA + branch + PR URL. Stops there. Backend-flavored wrapper around /board-pipeline + /blocked-pipeline with the rule-#20/#21/#23 backend safety stack pre-loaded for any cli-gateway / Cloud Run / secret-binding work. Does NOT review PRs, merge, deploy staging, run QA, or touch prod."
---

Board: $ARGUMENTS

You are running Michal's **backend** pipeline against the Trello board above. Scope this run: **sweep 🚧 Blocked, In Progress / Doing, and every To Do column** — left edge of the board to Code Review, in one pass. Combines `/blocked-pipeline` (for the Blocked sweep) with `/board-pipeline` (for the In Progress + To Do drain), with the backend-safety skill stack (cli-dev, gcloud-devops-expert, opsagents-cto) pre-loaded so any card touching `services/cli-gateway*/`, Cloud Run, or Secret Manager gets routed through the right specialist on the way to Code Review.

Per `~/CLAUDE.md` autonomy rule: make the call and ship — no confirmation prompts, no plan-mode previews. Hard stops only for spending real money, irreversible destructive prod ops, brand-new cold outreach, or policy violations.

## Input contract — `$ARGUMENTS` is a Trello board

Accepted forms (passed straight through to `/board-pipeline`):
- Full URL: `https://trello.com/b/SPiyDfU2/opsagents-recruiter`
- Short ID: `SPiyDfU2`
- Board short-name: `opsagents-recruiter`

If `$ARGUMENTS` is empty, ask once which board, then proceed. **NEVER default to a built-in board** — cross-tenant-leak rule: every run must be explicitly scoped to one board. Board resolution itself happens inside `/board-pipeline` step 2 via cli-gateway `trello_exec`; this command does not duplicate that work.

Required board layout (created by the sub-pipelines if missing): `🚧 Blocked`, `🧊 Backlog`, `To Do` (or split `To Do — Core` / `To Do — Front`), `In Progress` / `Doing`, `Code Review`, and an `info` column carrying the repo URL. Downstream columns (Deploy Staging / QA / Deploy Prod / Done) may exist but are out of scope for this command.

## Scope (this is the whole job)

This pipeline sweeps the **left edge** of the board in one run, in this order:

1. **🚧 Blocked** — every blocked card gets a decision (release / archive / rescope / route-to-Backlog). Acceptance: **Blocked is empty at end of run.** Still-gated cards route to 🧊 Backlog with a gate-state comment. "Leave in Blocked" is invalid (per `feedback_blocked_pipeline_must_drain`). The only exception is genuinely operator-blocked cards that the next pipeline run cannot re-evaluate — those stay in Blocked with an explicit unblock command and escalate to the "needs Michal" recap.
2. **In Progress / Doing** — every card with outstanding code work gets finished, pushed, commented (SHA + branch + PR URL), and moved → Code Review.
3. **To Do columns** — every card (across `To Do`, `To Do — Core`, `To Do — Front`, and any other `To Do — *` split) gets the same treatment: code, push, comment, → Code Review.

The pipeline does NOT exit while any card with this run's responsibility remains in Blocked, In Progress, or any To Do column. Acceptance = (a) Blocked is empty (modulo true-operator-gate exceptions called out in the recap), AND (b) every original In Progress / To Do card is in **Code Review**, **Doing** (parked per the Doing-park rule), **Done** (closed by the stale-bug pre-check), or **🚧 Blocked** (with a fresh unblock command from this run).

Code Review and downstream columns are NOT processed — no PR review, no merge, no staging, no QA, no prod.

If a To Do / In Progress card cannot ship to Code Review without operator action — captcha cookie operator step pending, Mac-only firebase/gcloud command outstanding, paid-spend not pre-authorized, brand-new cold outreach, manual approval — **move the card to 🚧 Blocked** with a Markdown comment naming the exact blocker and the unblock command/step. Do not park such cards in To Do or In Progress indefinitely.

## Steps you must follow, in order

1. **Pre-load skills** via the Skill tool, in this order — read each SKILL.md end-to-end before acting:
   - `opsagent-pm`
   - `opsagents-cto`
   - `opsagents-cli-dev` (co-owner of rule #20 for cards touching `services/cli-gateway*/`)
   - `gcloud-devops-expert`
   - `agents-md-optimizer`
   - `cli-gateway-mcp`

2. **Run /board-pipeline.** Invoke `/board-pipeline $ARGUMENTS`. That command does the actual drain: per-card stale-bug pre-check, shared-gate clustering, specialist dispatch, code push, comment with SHA + branch + PR URL, move → Code Review. Wait for its `🔀 CARD MOVEMENTS` recap.

3. **Backend safety stack — applies to every coding card before it moves to Code Review.** When `/board-pipeline` step 5 dispatches a coding card whose work touches Cloud Run, Secret Manager, env-var bindings, or `services/cli-gateway*/`, the spawned specialist MUST honor:
   - **Rule #20** (cloud secrets) — always `--update-secrets` / `--update-env-vars`, never `--set-*`. Never `gcloud run services replace`. Runner is `cli-gateway-sa@opsagent-prod`; only `gha-deployer@opsagent-prod` (CI) ever runs `--set-*`. A single `--set-*` from this runner once wiped 5/6 prod secrets (~5h prod degrade).
   - **Rule #21** (captcha-walled boards) — for sites behind reCAPTCHA / Cloudflare Turnstile / similar (jobninja, homeless, LinkedIn, future tenants), wire `chrome-runner`'s `withAuthedPage` cookie injection path. Cookie capture is an operator step; the runner only verifies via `/board/health` returning `{cookies:'present'}`. Do not ship captcha-solver SaaS or stealth-plugin code.
   - **Rule #23** (grep before spec) — before writing a card or PR that introduces a new env var or secret, grep the consumer service's source for the canonical name (`rg -F 'process.env.' src/`). Do not infer from the secret's logical name — a mismatched name deploys cleanly and 503s at runtime.
   - **Path-grep on cli-gateway diffs.** If the PR being prepared touches `services/cli-gateway/` or `services/cli-gateway-mcp/`, route the implementation through `/opsagents-cli-dev` *before* finalizing the push. cli-dev encodes the `(\s|$)` regex bypass fix, the pre-create empty Secret Manager secret + IAM bind pattern, and the fetch-main-first-never-push-from-stale-local rule that has cost ~445 lines historically.
   - **Dynamic-workflow guard for cli-gateway / Cloud Run / Secret Manager work.** When a To Do or In Progress card whose diff touches `services/cli-gateway*/`, Cloud Run env-var bindings, or Secret Manager writes is part of a multi-card fan-out (e.g. a board-pipeline dynamic-workflow run is fanning out a stale-bug pre-check or specialist dispatch), **exclude that card from the parallel batch** and route it serially through `/opsagents-cli-dev`. Rule-#20 ordering is invariant against parallel writes — concurrent `--set-secrets` would deterministically wipe whatever secrets each parallel agent hasn't read yet (postmortem 2026-05-04: a single `--set-*` once wiped 5/6 prod secrets → ~5h prod degrade). Parallelism is fine for reads (diff inspection, grep against main, gh API GETs) but writes through the cli-gateway must remain one-at-a-time.
     **Escalation:** if Trello returns 429 inside any nested /board-pipeline or /blocked-pipeline fan-out, drop the parallel cap from 20 → 10 in *that* file (backend-pipeline doesn't spawn its own dynamic workflow; it inherits from the wrapped pipelines).

4. **Loop trigger.** If `/board-pipeline` reports new cards landed in To Do mid-run (e.g. a stale-bug pre-check spawned a follow-up, or a blocker comment was filed as a new card), re-invoke `/board-pipeline $ARGUMENTS` and re-enter step 3. **Repeat until every To Do column (and any split `To Do — *`) is empty** and every card touched this run is in Code Review, Doing (parked), Done (stale-bug close), or 🚧 Blocked. That is the only acceptable exit.

5. **Final recap.** Print a `🔀 BACKEND PIPELINE` block:
   - Cards promoted: To Do → Code Review (with commit SHA + branch + PR URL).
   - Cards parked in Doing per the Doing-park rule (with reason + next-pipeline advisor recommendation).
   - Cards closed directly to Done by the stale-bug pre-check (with grep evidence).
   - Cards moved to 🚧 Blocked (with the exact unblock command/step).
   - Cards left in To Do with a blocker comment (with one-line reason).
   - cli-gateway / Cloud Run / Secret Manager work routed through cli-dev (with the rule applied).
   - **Token spend per dynamic-workflow invocation** rolled up from the wrapped /board-pipeline + /blocked-pipeline recaps (runtime-sourced — surfaces runaway fan-outs before they eat the day's budget).
   - **Acceptance check** (mandatory, last line of the recap): list every non-empty To Do column. If any To Do column still has cards that were not parked, closed, or blocked, the pipeline did not finish — call this out explicitly with the card IDs and re-enter the loop. Only when the check shows every original-To-Do card has reached Code Review / Doing-parked / Done-via-stale-bug / 🚧 Blocked may the pipeline exit.
   - Blockers needing Michal (credentials, billing, brand-new cold outreach).

   Mirror the recap to the board's Runner Log card if one exists; otherwise post once on the most-recently-touched card. If the board is Hebrew-language, the recap goes out in feminine Hebrew per `~/CLAUDE.md`.

## Standing rules to enforce inside this pipeline

- **Rule #19** (subagent ToolSearch select) — when this command (or `/board-pipeline` inside it) spawns subagents (`gcloud-devops-expert`, `agents-md-optimizer`, `opsagents-cli-dev`, any specialist `opsagents-cto` dispatches), each subagent prompt MUST include explicit `ToolSearch select:<tool>[,<tool>...]` lines for every MCP tool it needs (`gh_exec`, `gcloud_exec`, `trello_exec`). Without this, subagents fail with `InputValidationError` on the first MCP call because deferred tool schemas aren't loaded.
- **Rule #20 / #21 / #23** — see step 3 above. These bite at the coding stage (before move to Code Review), not just at deploy time, because the card body and PR diff both ship the future env-var/secret name.
- **Autonomy** — never use `AskUserQuestion` except the one-time board prompt in the input contract; pick the most likely interpretation otherwise, proceed, flag the assumption in the recap.

## Out of scope (intentional)

This command does NOT do any of the following — these belonged to the old end-to-end backend pipeline and have been removed per Michal's 2026-05-25 directive that the pipeline stops at Code Review:

- PR review (`/opsagents-cto` for code review)
- Merge-gate check (rule #22) / `gh pr merge`
- Deploy Staging (any `gh_exec` GHA dispatch / `gcloud run deploy` / `firebase deploy` / `netlify deploy`)
- PRD / STD / STR Notion docs (those tracked the staging+prod QA cycle)
- `/qa-tester` runs against staging or prod
- Deploy Prod
- Sweep Deploy Prod to empty / acceptance-check on Done + Blocked

If you need any of the above, run them as separate commands AFTER this pipeline lands the cards in Code Review.
