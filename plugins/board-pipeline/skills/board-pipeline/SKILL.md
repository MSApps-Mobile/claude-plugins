---
name: board-pipeline
description: "Run the on-demand board pipeline — drains every To Do column AND the In Progress / Doing column by doing the work, pushing code, and moving each card to Code Review. Stops there. Does NOT review PRs, merge, deploy staging, run QA, or touch prod."
---

Board: $ARGUMENTS

You are running Michal's on-demand pipeline against the board above. Per
`~/CLAUDE.md` autonomy rule: make the call and ship — no
confirmation prompts, no plan-mode previews. Hard stops only for spending real
money, irreversible destructive prod ops, brand-new cold outreach, or policy
violations.

## Steps you must follow, in order

1. **Pre-load skills** via the Skill tool, in this order — read each SKILL.md end-to-end before acting:
   - `opsagent-pm`
   - `opsagents-cto`
   - `cli-gateway-mcp`
   - `agents-md-optimizer`

2. **Resolve the board.** Board access runs entirely through the cli-gateway Trello surface (`mcp__cli-gateway__trello_exec`) — there is no separate board-detection skill. If `$ARGUMENTS` is non-empty, parse the board ID from it directly:
   - Full URL `https://trello.com/b/<boardId>/<slug>` → take the `<boardId>` path segment.
   - A bare board ID or shortLink → use it as-is.
   - Verify the board resolves: `mcp__cli-gateway__trello_exec ["api","boards/<boardId>?fields=name,url"]`. A non-error response confirms the board.
   If `$ARGUMENTS` is empty, ask the user **once** which board to operate on. NEVER default to a built-in board (cross-tenant leak rule). All subsequent list/card reads and moves use `mcp__cli-gateway__trello_exec` (`["api", ...]` escape hatch, or the `cards`/`comment`/`move` subcommands).

3. **Confirm Info column has the repo URL** for the board. If missing, ask `opsagent-pm` for a best guess and proceed. Coding cards without a known repo are stuck — surface them at the end of the recap.

4. **Scope of this pipeline = To Do columns AND In Progress / Doing (always, 2026-05-29 rule).** Process every card in `To Do` (and any `To Do — *` splits like `To Do — Core` / `To Do — Front`) AND every card in `In Progress` / `Doing`. Skip 🚧 Blocked entirely. Do NOT touch Code Review, Deploy Staging, QA, Deploy Prod, or Done — cards already in those columns are out of scope and stay where they are. The pipeline's job is: drain To Do AND In Progress → Code Review.

   **Why In Progress is in scope (2026-05-29 rule).** Cards land in In Progress when a prior pipeline run parked them (Doing-park), when a human started work and stalled, or when a sister pipeline (like `/backend-pipeline`) bounced them out of one stage. Without an explicit In Progress drain, parked cards rot: the next pipeline run sees only the To Do column and skips them. Always drain both, every run. The Doing-park rule still applies — if a card is genuinely too big for THIS run, you may re-park it in In Progress with a fresh advisor note, but you must attempt it first.

   **Why Code Review is out of scope (isolation rule, 2026-05-29 lesson).** The Claude session that wrote a PR cannot independently review its own PR — same-context = confirmation bias. Fresh-context Task-dispatched review belongs to `/board-refinement` Stage 1.5, which runs in a separate session with no visibility into the authoring transcript. `/board-pipeline` ships cards INTO Code Review; `/board-refinement` drains Code Review OUT. Mixing the two collapses the isolation gap and re-introduces the same-session review failure mode (`/opsagents-cto` Delivery Protocol §3).

5. **Per-card workflow — for each card in `To Do` (or `To Do — Core` / `To Do — Front`) AND every card in `In Progress` / `Doing`:**
   - Read description + AC.
   - **Stale-bug pre-check** — if the card cites a specific file:line bug or "fix X in Y", fetch the current file at `?ref=main` via `gh_exec` (or `git cat-file blob main:<path>` if the canonical checkout is on `main`) and grep for the cited pattern. If the bug doesn't reproduce in current `main`, close the card directly to **Done** with the grep evidence as a `STALE — already fixed on main` verdict. Skip the 7-stage walk — there is no code to ship. (Postmortem: 2026-05-24 msapps-website run found 4/4 sampled bug cards were stale; walking them through CR→DS→QA→DP→Done generates noise without value.)
   - **Shared-gate clustering** — if 5+ cards share an identical gate (same upstream PR, same admin-role unblock, same plugin install, same legal sign-off), post the full Markdown gate comment on the **first** card listing all sibling shortLinks, then post a 1-line `Same gate as <firstCardShortLink>` comment on each sibling. Saves API noise without losing audit trail. (Postmortem: 2026-05-24 msapps-website run posted the same 30-line gate comment on 11 portfolio cards.)
   - Ask `opsagent-pm` if AC is ambiguous.
   - Ask `opsagents-cto` which specialist skill should own the work (e.g. `shopify-dev`, `opsagents-frontend-jedi`, `opsagent-ai-dev`, `gcloud-devops-expert`, `netlify-expert`, `wp-plugin-development`).
   - Invoke that specialist via the Skill tool and do the work.
   - Push every code change immediately. If local `git push` fails in the sandbox, fall back to the `gh api` Contents API path documented in `<your-project>/CLAUDE.md` ("Local git is broken in scheduled-task sandboxes").
   - Comment on the card: commit SHA + branch + deploy URL + 1-line summary (`mcp__cli-gateway__trello_exec ["comment","<cardId>","<text>"]`).
   - Move card → **Code Review** (`mcp__cli-gateway__trello_exec ["move","<cardId>","<codeReviewListId>"]`).
   - On blocker: move card back to To Do with a Markdown blocker comment and continue to the next card.
   - **Optional: dynamic-workflow stale-bug fan-out.** If the To Do column has 10+ cards and most carry file:line bug citations, prompt Claude to spin up a dynamic workflow:
     > "Run a dynamic workflow: one subagent per card in `To Do`. Each subagent fetches the cited file at `?ref=main` via `gh_exec` and greps for the cited pattern. Converge on a verdict per card: STALE (close direct to Done with grep evidence) or LIVE (continue to specialist dispatch). Persist progress per card so an interrupted run resumes from the last verified card."
     Honor rule #19 — each subagent prompt must include `ToolSearch select:gh_exec,trello_exec`. Cap at 20 parallel agents (Trello API budget; cli-gateway proxies through one shared token and 429s above ~30 concurrent). Adversarial reviewer required when the fan-out writes (Done-close), not just reads.
     **Escalation:** if Trello returns 429, drop the parallel cap from 20 → 10 in this file.

6. **Loop step 5** until every To Do column (and any `To Do — *` splits) AND the In Progress / Doing column are empty. The pipeline ends when every card originally in a To Do or In Progress column has either landed in Code Review, been pushed back to To Do with a blocker comment, been re-parked in In Progress per the Doing-park rule below (with a fresh advisor note), or been closed directly to Done by the stale-bug pre-check. **Do not** touch Code Review, Deploy Staging, QA, Deploy Prod, or Done — they are out of scope.

7. **Final recap** — print a `🔀 CARD MOVEMENTS` block listing every To Do card touched and where it ended up (one line per card). Include:
   - Cards moved → Code Review (with commit SHA + branch + PR URL)
   - Cards parked in Doing (with reason + next-pipeline advisor recommendation)
   - Cards closed directly to Done by the stale-bug pre-check (with grep evidence)
   - Cards left in To Do with a blocker comment (with one-line reason)
   - Token spend per dynamic-workflow invocation (runtime-sourced — surfaces runaway loops before they eat the day's budget)
   - Blockers needing Michal

   Mirror the recap to the board's Runner Log card if one exists; otherwise post once on the most-recently-touched card.

## Board-quirks to handle

- **Split To Do columns** (`To Do — Core` / `To Do — Front`): process Core first, then Front. The recruiter board uses this pattern.
- **No Code Review column yet?** Create the missing Code Review column directly via `mcp__cli-gateway__trello_exec ["api","-X","POST","--data","{\"name\":\"Code Review\",\"idBoard\":\"<boardId>\",\"pos\":\"bottom\"}","lists"]`. Do NOT create downstream columns (Deploy Staging / QA / Deploy Prod) — they are out of scope for this pipeline. If the board's owner wants the full flow, that's a different command.
- **Card already in Doing / In Progress when you arrive:** finish whatever code work is outstanding, push, comment SHA + branch + PR URL, then move it → Code Review (same workflow as a To Do card).
- **Doing-park (acceptable terminal outcome):** if a To Do card is genuine green-field work no advisor in this run can ship within the run, park it in Doing with an implementation plan + a next-pipeline advisor recommendation as a card comment. This is an acceptable end state — do NOT push a half-built skeleton into Code Review (`feedback_never_bypass_pipeline`). Call the acceptance gap out honestly in the recap rather than forcing a fake completion.
- **Hebrew/feminine language:** if the board is Hebrew-language, all card comments and the recap go out in feminine Hebrew per `~/CLAUDE.md`.
