---
name: board-refinement
description: "Prod-grade Trello board refinement routine. Use whenever the user says \"refine the board\", \"board refinement\", \"prod-grade refinement\", \"harden the board for prod\", \"PRD-gap audit\", \"refine cards before deploy\", \"is this board ready to ship\", \"audit the board before prod\", \"production-grade pass on this board\", or hands over a board with intent to harden it for production. Sister to /board-pipeline, /backend-pipeline, /blocked-pipeline — distinct from them: this routine assumes coding work is already drafted and the question is whether the board, the PRDs, the staging surface, the test coverage, and the pre-prod prerequisites are all production-grade. Four stages: (1) PM+CTO plan + PRD/gap audit, (2) CTO deploy-gate verdict + staging spin-up, (3) QA TDD audit-or-write + sanity test against PRD, (4) pre-prod readiness verification. Each stage either advances the card or bounces it back to a To Do column with a detailed brief authored by /opsagents-md-composer."
---

Board: $ARGUMENTS

You are running Michal's **board-refinement** routine against the Trello board above. The goal is **production-grade refinement** — by the end of this run, every card is either in ✅ Done, 🚧 Blocked, or has a detailed refinement brief explaining exactly what is missing and which skill is on the hook to fix it.

Per `~/CLAUDE.md` autonomy rule: make the call and ship — no confirmation prompts, no plan-mode previews. Hard stops only for spending real money, irreversible destructive prod ops, brand-new cold outreach, or policy violations.

## Input contract — `$ARGUMENTS` is a Trello board

Accepted forms:
- Full URL: `https://trello.com/b/SPiyDfU2/opsagents-recruiter`
- Short ID: `SPiyDfU2`
- Board short-name: `opsagents-recruiter`

If `$ARGUMENTS` is empty, ask **once** which board to operate on. **NEVER default to a built-in board** — cross-tenant-leak rule. Resolve the board via cli-gateway:
```
mcp__cli-gateway__trello_exec ["api","boards/<boardId>?fields=name,url"]
```
A non-error response confirms the board.

## How this differs from /board-pipeline, /backend-pipeline, /blocked-pipeline

- **/board-pipeline** — drives raw card-shaped work from To Do → Code Review. Ships PRs, stops at Code Review. **Does NOT drain Code Review** (isolation rule — see Stage 1.5 below). Assumes the work itself is reasonably understood; its job is to *move* cards into review.
- **/backend-pipeline** — wraps /board-pipeline with Notion PRD/STD/STR mirroring and bounce-counter QA, but still mostly trusts the cards as written.
- **/blocked-pipeline** — drains the Blocked column.
- **/board-refinement** (this skill) — assumes the cards exist but may be underspecified, missing PRDs, missing tests, missing staging surfaces, or missing pre-prod prerequisites. It is a **production-readiness audit**, not an execution pass. It can call /board-pipeline as a sub-step when an individual card needs the standard 7-stage walk, but its own outer loop is: plan → verdict → QA → pre-prod gate.

A board can be run through /board-refinement *before* /board-pipeline (to harden the spec) or *after* it (to verify everything actually shipped to prod-grade).

## Acceptance criteria

The pipeline does NOT exit while any card sits in **Deploy Prod** (transit only — must move to Done or bounce to To Do) or while any card sits in **To Do — Core**, **To Do — Front**, **In Progress** / **Doing**, **Code Review**, **Deploy Staging**, or **QA** without an explicit refinement brief attached.

Acceptance = for every card on the board, one of:
- ✅ **Done** — code shipped to prod, /opsagents-cto + /qa-tester verdicts both green, all 4 stages complete.
- 🚧 **Blocked** — operator-only step pending (cookie paste, paid spend, legal/ToS, brand-new cold outreach). The blocker must be named explicitly with the unblock command/step.
- 📋 **To Do — Core / Front with refinement brief** — bounced here by one of the 4 stages, with a Markdown comment authored by `/opsagents-md-composer` containing: which stage bounced it, why, what's missing, suggested fix, and which specialist skill should pick it up next round.

**Any** card sitting in **Deploy Prod** at end of run is an invalid end state — Deploy Prod is transit only (card enters from QA, exits to Done on successful prod deploy or to To Do — Core/Front on bounce). Cards in QA without a /qa-tester verdict comment are also an invalid end state.

## Steps you must follow, in order

### Stage 0 — Pre-load skills

Pre-load via the Skill tool, in this order — read each SKILL.md end-to-end before acting:

1. `opsagent-pm` — outer-loop orchestrator (documents the run, dispatches further skills)
2. `opsagents-product-manager` — co-planner with /opsagent-pm in stage 1
3. `opsagents-cto` — verdicts in stage 1 and 2; "eval + dream for cwc" verdict in stage 3
4. `notion-spec-to-implementation` — PRD authoring in stage 1
5. `opsagents-md-composer` — gap-card filing throughout; bug-card filing in stage 3
6. `gcloud-devops-expert` — staging deploy in stage 2; pre-prod gate in stage 4
7. `firebase-basics` — staging URL spin-up in stage 2 when no staging exists
8. `qa-tester` — test audit/authoring in stage 3
9. `trello-qa-loop` — QA loop driver in stage 3
10. `opsagents-playwright-qa` — real-browser QA in stage 3
11. `claude-md-composer` — bounce-brief authoring in stage 2 (CTO-fail path)
12. `agents-md-optimizer` — sanity-test gap cards in stage 3
13. `cli-gateway-mcp` — all Trello / gcloud / firebase / gh calls

### Stage 1 — PM + CTO planning loop

`/opsagents-product-manager` and `/opsagent-pm` together review the board and plan with `/opsagents-cto`. For each card:

1. **PRD existence check.** Look in Notion under the tenant's parent page (or board-linked workspace) for an existing PRD covering this card / feature.
   - **Missing →** invoke `/notion-spec-to-implementation` to author one. Pull from card description, AC, linked epic, any referenced design docs. Link the new Notion page in the Trello card description under a `## PRD` heading.
   - **Exists but stale** (new AC, new endpoints, new env vars, materially expanded scope) → update via `/notion-spec-to-implementation` so the spec matches the current state of the world.
   - **Exists and current** → link it in the card description if not already linked, then proceed.

2. **Gap audit — "what is still missing?"** With `/opsagents-product-manager` + `/opsagent-pm` + `/opsagents-cto` in conversation: walk the card's PRD and identify what's missing for production-grade completion. Possible gaps:
   - Missing acceptance criteria
   - Missing test scenarios (positive, negative, edge)
   - Missing staging URL
   - Missing observability / error paths
   - Missing tenant-isolation guards
   - Missing rate-limit / abuse considerations
   - Missing rollback path
   - Missing docs (runbook, customer-facing changelog)
   - Missing pre-prod prerequisites (secrets, env vars, DNS, CI config)

   **Optional: dynamic-workflow adversarial gap audit.** For boards with 10+ cards or when prod risk is high, prompt Claude:
   > "Run a dynamic workflow on this card's PRD. Two adversarial agents: one argues this is production-grade as written, one tries to refute by surfacing missing AC / missing test scenarios / missing env-vars / missing staging URL / missing rollback path / missing observability / missing tenant-isolation guards. Iterate until they converge. Output: the converged gap list, with each gap tagged by which specialist skill should own the fix. A third agent files each gap card via `/opsagents-md-composer` in the standard refinement-brief format."

   This is the single highest-leverage application of dynamic workflows in the pipeline stack — adversarial review directly attacks rule-#20 / rule-#23 misses (missed env vars, wrong canonical name) before they reach deploy. Honor rule #19 — each subagent prompt must include `ToolSearch select:gh_exec,trello_exec`. Cap at 20 parallel agents.
   **Escalation:** if Trello returns 429, drop the parallel cap from 20 → 10 in this file.

3. **File gap cards via `/opsagents-md-composer`.** For each gap surfaced, file a new Trello card in the appropriate To Do column (Core for backend/AI/infra, Front for UI/UX) with the standard refinement-brief format:
   ```markdown
   ## Gap surfaced by /board-refinement stage 1
   **Parent card:** <shortLink>
   **PRD:** <Notion link>
   **What's missing:** <concrete description>
   **Why it matters for prod:** <one-line rationale>
   **Suggested owner skill:** <specialist skill name>
   **AC:** <bulleted, testable AC>
   ```

### Stage 1.5 — Code Review drain (fresh-context isolation)

**Why this stage exists (2026-05-29 lesson).** `/board-pipeline` ships cards INTO the Code Review column but cannot review them — the same Claude session that wrote the PR has confirmation bias on its own diff. `/board-refinement` runs in a separate session with no visibility into the authoring transcript, so it is the canonical surface for the independent review. The Code Review column drain belongs HERE, not in `/board-pipeline`.

For each card sitting in **Code Review**:

1. **Locate the PR** — read the most recent `Shipped — PR #<n>` comment (or `Open PR:` frontmatter on a handoff card) for the canonical PR URL. If missing → bounce to To Do with a `## Missing PR link` brief via `/opsagents-md-composer` (cannot review what you can't find).

2. **Dispatch fresh-context review via the `Task` tool** (NOT `Skill` — `Skill` is same-session). Pick the reviewer subagent by diff content:
   - **`feature-dev:code-reviewer`** (Sonnet) — default for application code, UI/UX, Liquid themes, Markdown/config edits.
   - **`pr-review-toolkit:code-reviewer`** (Opus) — when the diff touches auth, secrets, cross-tenant data, IAM/WIF bindings, or anything in `/opsagents-cto` Delivery Protocol §3's "auth/secrets/cross-tenant" carve-out.

   The Task prompt must hand the agent: PR URL + repo + base branch + the card body's AC + an explicit "review against the AC, not just the diff." Honor rule #19 — declare `ToolSearch select:gh_exec,trello_exec` in the prompt.

3. **Optional second pass: `/security-review` slash-command** — fixed-rubric checklist sweep. Run in addition to (never instead of) the Task-dispatched reviewer. Useful for the auth/secrets/cross-tenant carve-out.

4. **Apply the verdict:**
   - **APPROVE** (reviewer found no blocking issues + CI green on the exact head SHA per rule #22) → comment commit SHA + reviewer verdict link on the card → proceed to Stage 2 (CTO deploy-gate verdict + staging spin-up). Do NOT auto-merge here — Stage 2 owns the merge gate per the standard Trello → PR → merge flow.
   - **REQUEST CHANGES** → move card back to the relevant To Do column (Core vs Front per owner skill). Attach a Markdown bounce brief authored by `/opsagents-md-composer`:
     ```markdown
     ## Code Review bounce — stage 1.5
     **Verdict:** REQUEST CHANGES
     **PR:** <URL>
     **Reviewer:** Task → <subagent name> (verdict link)
     **Issues:** <list with file:line refs>
     **Suggested fix:** <concrete actions>
     **Re-entry criterion:** <what stage 1.5 needs to see on the next pass>
     ```

**Adversarial-review pattern (high-risk PRs).** For PRs touching auth, prod data migrations, IAM/WIF, or anything that triggered a recent postmortem (firestore-rules-shared, WIF-mapping, firebase-tools-WIF, npm-omit-optional), dispatch 2–3 Task reviewers in parallel with different lenses (`correctness`, `security`, `does-it-reproduce`). Approve only if ≥majority pass. This is the only adversarial application currently mandated at Stage 1.5 — applying it blanket is wasteful.

### Stage 2 — CTO deploy-gate verdict

`/opsagents-cto` reviews each card (and its gap cards from stage 1) and verdicts whether it is ready to deploy to staging.

- **PASS** → invoke `/gcloud-devops-expert` to deploy staging.
  - If the touched service has a known staging URL, deploy to it.
  - If **no staging URL exists**, invoke `/firebase-basics` to spin one up — typically a Firebase Hosting preview channel for static frontends, or a Cloud Run `--no-traffic`-tagged revision with a `staging---` tag for backend services. Confirm the staging URL responds (`200` on `/` or `/health`) before moving on.
  - Comment on the card: commit SHA + staging URL + timestamp.
  - Move card → **QA**.

- **FAIL** → move card back to the relevant To Do column (Core vs Front per owner skill). Attach a detailed Markdown bounce brief authored by `/claude-md-composer` containing:
  ```markdown
  ## CTO bounce — stage 2
  **Verdict:** REJECT — not ready for staging
  **Why:** <root cause, file:line refs where applicable>
  **What to change:** <concrete actions>
  **Suggested fix:** <code sketch / approach>
  **Recommended specialist skills:** <list, e.g. /opsagents-frontend-jedi, /opsagent-ai-dev>
  **Re-entry criterion:** <what /opsagents-cto needs to see on the next pass>
  ```
  Do not lose audit trail — the brief is the audit trail.

### Stage 3 — QA against staging URL

For each card in QA, invoke the QA trio: `/qa-tester` + `/trello-qa-loop` + `/opsagents-playwright-qa`.

**(a) Check for existing TDD tests.**

- **IF tests exist** → audit them:
  - **a1. Examine failures.** Read the last run's failure output if any. For each failing test, refine the test from the actual failure mode — tighten assertions, fix flaky selectors, narrow time-based race conditions. The goal is a test that genuinely reflects the AC, not a brittle one.
  - **b1. File bug cards for test failures via `/opsagents-md-composer`.** Use the 6-field bug-card format (`feedback_bug_filing_format`):
    ```markdown
    ## Bug surfaced by /board-refinement stage 3
    **Surface:** <staging URL + path + browser/viewport>
    **Version:** <commit SHA / deploy timestamp>
    **Observed:** <what happened, with screenshot/console URL>
    **Expected:** <what the PRD says should happen>
    **Why:** <root cause hypothesis>
    **AC:** <bulleted, testable AC for the fix>
    ```
    Refuse to file bug cards missing any field — surface the gap to `/opsagent-pm` instead.
  - **c1. Detailed error message — always.** Every failure log must carry the exact assertion that failed, the actual vs expected value, the request/response if network-related, and the stack frame. "Test failed" alone is invalid output.
  - **d1. Structured output.** Test output goes to JSON by default (one record per case: `id`, `name`, `status`, `duration_ms`, `error`, `evidence_urls`). QA may pick a different structured format (JUnit XML, NDJSON) if it fits the harness better — but free-text-only output is invalid.
  - **e1. Eval + dream for cwc.** If the card involves chat-with-context (cwc) — Vertex/Bedrock/openclaw-routed conversational flows — consider using the `claude-api` eval harness and the "dream" pattern (synthetic-conversation generation) for coverage. **`/opsagents-cto` verdicts whether this is worth the lift for the specific card** — don't apply blanket.

- **ELSE (no tests exist)** → write new tests, applying ALL the best practices from a1–e1 above. Detailed errors, structured output, eval+dream for cwc when CTO-approved.

**(b) Sanity test against PRD.** Independent of the TDD layer, walk the PRD's user-visible behaviors against the staging URL one-by-one (`/opsagents-playwright-qa` is the right tool — real browser, desktop + mobile, Hebrew + English per the QA skill's own canon). Any PRD behavior that isn't reflected in working staging → open a Trello gap card via `/agents-md-optimizer` (this is the agents-md-optimizer path because gap cards here are internal prompts/briefs, not user-delivered content).

**(c) Verdict.**

- **APPROVE** (all TDD tests pass + all PRD sanity behaviors verified) → move card → **Deploy Prod**.
- **OTHERWISE** → move card back to the relevant To Do column with a detailed brief authored by `/opsagents-md-composer`:
  ```markdown
  ## QA bounce — stage 3
  **Verdict:** REJECT — not ready for prod
  **TDD failures:** <list with test IDs + linked bug cards>
  **PRD-sanity gaps:** <list with PRD-section refs + linked gap cards>
  **Suggested specialist skills:** <list>
  **Re-entry criterion:** <what /qa-tester needs to see on the next pass>
  ```

### Stage 4 — Prod deploy + readiness gate

Cards reach this stage in the Deploy Prod column after stage 3 approved them. Stage 4 verifies pre-prod prerequisites, **then triggers the actual prod deploy**, then moves the card to its terminal state. Deploy Prod is a transit column — no card may sit here at end of run.

**Readiness checks** (run first):

- **Secrets/env vars present.** Per rule #20 (`feedback_describe_per_service_for_min_instances` + the merge-vs-replace semantics): `gcloud run services describe <svc>` for each secret + env var the new code expects. Per rule #23 (`feedback_secret_env_var_grep_first`): grep the consumer's runtime for the canonical env-var name BEFORE assuming a card's spec is correct.
- **DNS records / custom domains live.** For Firebase Hosting custom domains: confirm CNAME → site, not A → LB (`feedback_firebase_custom_domain_cname_not_a`).
- **CI config present.** `.github/workflows/deploy*.yml` (or Cloud Build trigger) carries the full canonical secret list (rule #20: `--set-*` is safe only when the list is complete).
- **Staging soak.** Staging has been live with the new code for whatever soak window the card's risk profile requires (defaults: trivial = 0, standard = 30 min, high-risk = 24 h).
- **Rollback path verified.** Previous revision exists and is reachable; for Cloud Run, `gcloud run services update-traffic --to-revisions=<prev>=100` works (don't actually run it — just confirm the previous rev is still in the keep-N retention window).

**Optional: dynamic-workflow adversarial readiness gate.** Before invoking `/gcloud-devops-expert` for the prod deploy, prompt Claude:
> "Run a dynamic workflow: one agent argues 'deploy this card to prod now', one tries to refute by checking secrets present (rule #20 — every env var named in the diff exists in `gcloud run services describe`), grep-before-spec (rule #23 — the canonical name in the consumer source matches the secret name in the deploy yaml), DNS live, CI workflow registry not desynced (`feedback_gha_workflow_registry_desync`), rollback revision reachable. Iterate until converged. If 'refute' wins, bounce per the Stage-4 failure branch with the surfaced reason."

Same rule-#19 ToolSearch hygiene — each agent prompt must declare `gcloud_exec,gh_exec`. Two reviewers per card minimum (Bun-precedent floor). Token-spend logged to the run-recap so a runaway loop doesn't eat the day's budget.
**Escalation:** if Trello returns 429 mid-fan-out, drop the parallel cap from 20 → 10 in this file.

**Branch logic** — exactly three terminal outcomes:

- **All prereqs green** → invoke `/gcloud-devops-expert` to **deploy to prod** via the canonical method for the touched service (merge prod-deploy workflow / dispatch `deploy-prod.yml` / `gcloud run deploy` with the full canonical secret list per rule #20). Wait for the deploy to go green on the exact head SHA (rule #22 applied to the prod deploy, not just the PR-gate). On success: comment commit SHA + prod URL + timestamp on the card → move card → **✅ Done**. On failure: bounce per the failure branch below.

- **Missing prereq, doable in current scope** (e.g. create a missing GCP secret from a value already in scope, add a missing env-var binding to deploy.yml) → do the prep, then re-run the readiness checks. If now green → run the prod deploy per the green-branch above. If still flagged → bounce per the failure branch below. **Never park in Deploy Prod.**

- **Missing prereq, out of scope** (paid spend, brand-new cold outreach, legal/ToS gate, operator-only OAuth ceremony, Mac-only firebase/gcloud step) → move card → **🚧 Blocked** with an explicit gate naming the unblock command/step.

- **Failure branch** — applies to: prod deploy fails on the head SHA, post-deploy smoke fails, rollback path not actually reachable, prereqs still flagged after in-scope prep, or any other reason the card cannot ship in this run. Move card back to **To Do — Core** or **To Do — Front** (by owner skill) with a detailed brief authored by `/opsagents-md-composer` in this format:

  ```markdown
  ## Stage-4 bounce — /board-refinement
  **Verdict:** REJECT — prod deploy or pre-prod gate failed
  **What failed:** <secret name / env-var name / deploy step / smoke check>
  **Observed:** <error message + file:line / Cloud Run revision / CI run URL>
  **Expected:** <what stage 4 needed to see>
  **Why it matters for prod:** <impact>
  **Suggested fix:** <concrete action>
  **Recommended specialist skills:** <e.g. /gcloud-devops-expert, /opsagent-ai-dev>
  **Re-entry criterion:** <what stage 4 needs to see next round>
  ```

### Stage 5 — /opsagent-pm documents the run and dispatches further skills

After all four stages: invoke `/opsagent-pm` to:

1. **Document the run.** Author a Markdown run-report and post it as a comment on the board's Runner Log card if one exists; otherwise post once on the most-recently-touched card. The report mirrors the `🔀 CARD MOVEMENTS` and `📋 GAP CARDS FILED` blocks below.
2. **Dispatch further skills as needed.** If the run surfaced patterns that aren't this skill's job (a missing skill, a CI config that needs an architecture review, a recurring secret-name-mismatch class of bug), invoke the relevant specialist skill and file a Trello card on the appropriate board (often `OpsAgents Skill` board `NFwBIATP` for skill-freshness work per `feedback_skill_freshness_pipeline_step`).

## Final recap — required output format

Print a recap with two sections, in this exact order:

```markdown
## 🔀 CARD MOVEMENTS
- <shortLink> "<card title>" — <from-column> → <to-column> — <one-line reason>
- ...

## 📋 GAP CARDS FILED
- <new shortLink> "<gap title>" → <To Do — Core | To Do — Front> — <stage that surfaced it> — <parent card shortLink>
- ...

## 💸 DYNAMIC-WORKFLOW TOKEN SPEND
- <invocation label> — <token count> (runtime-sourced; flag if >5× the baseline)
- ...
```

Then mirror this recap to the board's Runner Log card (or the most-recently-touched card if no Runner Log exists).

## Board-quirks to handle (same as /board-pipeline)

- **Split To Do columns** (`To Do — Core` / `To Do — Front`): route bounces by owner skill — backend/AI/infra → Core, UI/UX → Front. If the board has a single unified `To Do`, use it as-is — do not auto-split (invasive on non-recruiter boards).
- **No staging surface wired:** stage 2 spins one up via `/firebase-basics`. If even that isn't possible for the touched service (e.g., a service that only exists in prod with no staging variant possible), move the card → 🚧 Blocked with the gate `"no staging environment possible — needs <specialist-skill> to wire one"`. NEVER promote to prod without a staging QA pass.
- **Missing columns:** create any missing column directly via cli-gateway (see /board-pipeline for the canonical POST `/lists` call). The 4-stage refinement flow requires To Do, Code Review (optional but recommended), Deploy Staging, QA, Deploy Prod, Done, plus 🚧 Blocked.
- **Hebrew/feminine language:** if the board is Hebrew-language, all card comments and the recap go out in feminine Hebrew per `~/CLAUDE.md`.
- **Already-shipped cards in Done:** audit them on first scan per `feedback_audit_done_traversal_first_scan` — if a Done card is missing PRD, missing tests, or has visible PRD-sanity gaps in current prod, bounce it back to the appropriate stage. Done is not immune to refinement.

## Standing rules this skill inherits

- **Push every code change to remote** — every stage, every round (Cowork CLAUDE.md autonomy + push rules).
- **Log all output to the Trello card** — comment or description update (`feedback_push_and_notion`).
- **Approved code review with open PR → merge it** — but only after rule #22 merge-gate passes (latest CI green on the exact head SHA).
- **Subagent delegation must include explicit `ToolSearch select:` for every MCP tool needed** (rule #19, 2026-05-03).
- **Cloud Run secret/env-var ops — `--update-*` for partials, `--set-*` only with the complete canonical list** (rule #20, 2026-05-04).
- **Grep before you spec** — rule #23, 2026-05-07.
- **Merge gate = green CI on the exact head commit** — rule #22, 2026-05-06.
- **Operator-only steps go to 🚧 Blocked, never Done** (`feedback_recruiter_operator_only_is_blocked`).
- **No card may sit in Deploy Prod at end of run** (transit only — must move to Done on successful prod deploy or bounce to To Do — Core/Front with `/opsagents-md-composer` brief). Upstream columns also require a refinement brief before exit — see acceptance criteria above.
