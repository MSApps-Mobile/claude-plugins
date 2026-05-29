---
name: blocked-pipeline
description: "Walk the Blocked column on a Trello board — for each card, verify whether its gate has cleared and either release, leave, archive, or rescope. Loops until every blocked card has been decisioned."
---

Board: $ARGUMENTS

You are running Michal's on-demand **Blocked-column pipeline** against the board above. Goal: drain the 🚧 Blocked / 🚫 Blocked list by deciding each card — release the ones whose gates have cleared, archive the ones whose work is now obsolete, leave the ones that are still genuinely gated. Per `~/CLAUDE.md` autonomy rule: make the call and ship.

## Steps you must follow, in order

1. **Pre-load skills** via the Skill tool, in this order — read each SKILL.md end-to-end before acting:
   - `opsagent-pm`
   - `opsagents-cto`
   - `cli-gateway-mcp`

   (`pm-trello-flow` removed 2026-05-24 — it's not installed; board work runs directly via cli-gateway `trello_exec`. Inline the cross-tenant-leak guard below.)

2. **Resolve the board.** If `$ARGUMENTS` is non-empty, parse the shortLink from the URL (the `/b/<shortLink>/` segment) and enumerate lists via `mcp__plugin_cli-gateway_cli-gateway__trello_exec` `["api", "boards/<shortLink>/lists?fields=name,id"]`. If `$ARGUMENTS` is empty, ask the user **once** which board to operate on. **NEVER default to a built-in board** — cross-tenant-leak rule: every run must be explicitly scoped to one board.

3. **Locate the Blocked list.** Look for a list whose name matches `🚧 Blocked` / `🚫 Blocked` / `Blocked`. If none exists, recap that the board has no Blocked column and exit cleanly — there is nothing to drain.

4. **Pull every card in Blocked** via `mcp__plugin_cli-gateway_cli-gateway__trello_exec` `["api", "lists/<blockedListId>/cards?fields=name,shortUrl,desc,labels,due&limit=100"]`.

5. **Per-card decision — for every blocked card:**

   a. **Identify the gate.** Parse the description for `GATED on`, `BLOCKED by`, `Blocked by`, `Preconditions`, `Status: PARKED`, or similar. The gate is usually one of:
      - Another Trello card (look for `trello.com/c/<shortLink>` in the gate clause)
      - An open PR (look for `owner/repo#N` or a `github.com/.../pull/N` URL)
      - An external event (credit grant, lawyer review, ToS sign-off, partner approval)
      - An explicit `PARKED until <date>` marker

   b. **Verify gate state:**
      - Trello-card gate → `trello_exec ["api","cards/<shortLink>?fields=name,idList,closed"]`. Cleared if the card's list is named `Done` / `Deploy prod` / equivalent terminal state, or `closed=true`.
      - PR gate → `gh_exec ["pr","view","<n>","--repo","<owner/repo>","--json","state,merged"]`. Cleared if `merged=true`.
      - Date-park gate → cleared iff today ≥ the parked-until date.
      - External event → leave for human review unless memory or a sibling card explicitly confirms it landed.

      **Optional: dynamic-workflow gate-state fan-out.** If the Blocked column has 8+ cards, prompt Claude:
      > "Run a dynamic workflow: one subagent per blocked card. Each subagent parses the gate clause from the description and verifies state — Trello-card gates via `trello_exec`, PR gates via `gh_exec`, date-park gates against today, external-event gates left for human review. Output one row per card: `{cardId, gateType, gateState, recommendedAction}`. Persist progress per card."

      Honor rule #19 — each subagent prompt must include `ToolSearch select:gh_exec,trello_exec`. Cap at 20 parallel agents (Trello API budget). Then run step 5d (release/archive/rescope/route-to-Backlog) **serially** on the output — the decision step needs the `/opsagent-pm` + `/opsagents-cto` consult and the audit-trail comment must be one-at-a-time. Read-side parallelism only; write-side stays sequential.
      **Escalation:** if Trello returns 429, drop the parallel cap from 20 → 10 in this file.

   c. **Cross-check against memory.** Before releasing, search the session's persistent memory (e.g. `~/.claude/projects/<project>/memory/MEMORY.md` and the linked memory files) for any entry that says the card's work is obsolete, superseded, or already-shipped. If found → archive instead of release (prevents resurrecting retired work).

   d. **Decide and act:**
      - **Release** — gate cleared, work still relevant. Ask `opsagents-cto` (one line) which list to release into based on owner skill in the card body. Default mapping for split-To-Do boards (recruiter): `core-dev` / `opsagent-ai-dev` / `opsagent-core-dev` / `gcloud-devops-expert` / `openclaw-master` / `cli-dev` → To Do — Core; `opsagents-frontend-jedi` / `frontend-jedi` → To Do — Front; otherwise → To Do. Move via `["api","-X","PUT","--data","{\"idList\":\"<targetListId>\"}","cards/<cardId>"]`. Comment on the card naming the cleared gate.
      - **Archive** — gate cleared but work is moot (already shipped, retired, superseded). Move to Done list (or `closed=true` if the board has no Done) and comment with the reason + link to the superseding card/commit/memory.
      - **Rescope** — gate cleared but the original plan is wrong now. Ask `opsagent-pm` for the rewrite call. Close the existing card with a `SUPERSEDED by <newCardShortUrl>` comment, and file the replacement card on the right list.
      - **Route to Backlog** — gate still active but expected to clear eventually (time-based, partner approval, etc.). Move the card to `🧊 Backlog` (create the column via `["api","-X","POST","--data","{\"name\":\"🧊 Backlog\",\"idBoard\":\"<boardId>\",\"pos\":\"top\"}","lists"]` if it doesn't exist), comment with the current gate state (one line: "ToS card jSiJw3oQ still in Backlog as of <ts>"). Per `feedback_blocked_pipeline_must_drain`: **Blocked column empty at end of run is the acceptance criterion — "Leave in Blocked" is invalid.** Active operator gates (cred-mint, marketplace decision) that genuinely cannot be re-evaluated by the next pipeline run stay in Blocked with the explicit unblock command + escalate to the "needs Michal" recap section. Everything else routes to Backlog.
      - **Human review** — gate state genuinely unclear (not operator-blocked, just ambiguous). Move to Backlog with the `needs human review @michal` comment and add it to the recap's "needs Michal" section.

   e. **No skipping the LinkedIn ToS cluster.** If the gate references the LinkedIn ToS addendum card (recruiter `jSiJw3oQ` or any future equivalent), only release when that card is in Done — never on memory alone. ToS gates are legal-shaped; the lawyer signoff is the hard requirement.

6. **Recap.** Print a `🔀 BLOCKED PIPELINE` block listing every card touched, one line each, grouped by decision: Released / Archived / Rescoped / Left / Needs Michal. Include shortUrls. **Token spend per dynamic-workflow invocation** is logged in the recap (runtime-sourced — surfaces runaway fan-outs before they eat the day's budget). Mirror the recap to the board's Runner Log card if one exists; otherwise post once on the most-recently-touched card.

## Board-quirks to handle

- **Split To Do columns** (`To Do — Core` / `To Do — Front`): use the owner-skill mapping in step 5d above.
- **No Done column:** archive via `closed=true` instead of moving.
- **Hebrew boards:** all card comments and the recap go out in feminine Hebrew per `~/CLAUDE.md`.
- **Cards in `🚫 Blocked` on the DevOps board:** that list IS the Blocked surface for that board (`69e245a621c56aca22028e54`). Same treatment.

## Hard stops

- Don't auto-release a ToS / legal / lawyer-gated card on memory or sibling-card evidence alone — only on the gate card landing in Done.
- Don't archive a card whose body has unresolved acceptance criteria unless memory or a Done card explicitly supersedes it.
- Don't paste cleartext credentials into card comments (`feedback_no_creds_in_trello`).
