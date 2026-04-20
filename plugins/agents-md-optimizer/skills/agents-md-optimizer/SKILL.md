---
name: agents-md-optimizer
description: Audit bloated agent-instruction files (CLAUDE.md, AGENTS.md, and their local/user-level variants) and rewrite them lean, or author a new one from scratch following the 200-line "recipe book" principle. Use this skill whenever the user mentions CLAUDE.md, AGENTS.md, agent instruction file, project memory file, context file, token budget, context bloat, "my CLAUDE.md is too big", trimming CLAUDE.md, auditing AGENTS.md, writing AGENTS.md for a new project, or any discussion of what belongs in the agent-instruction-file hierarchy (enterprise, project, user-level, project-local). Also trigger when such a file is shown in context and is visibly long (over 200 lines) or contains anti-patterns like embedded API docs, negative "Don't do X" rules, step-by-step tutorials, or preemptive file-preload instructions — even if the user doesn't explicitly ask for optimization, proactively offer to use it.
---

# agents-md-optimizer

## What this skill does

`CLAUDE.md` is loaded into every Claude session for the project it belongs to. That means every line is a recurring tax on the context window — paid before any real work starts, across every session, forever. Most `CLAUDE.md` files drift into bloat: people copy-paste API docs, write step-by-step tutorials, hoard historical state, stack negative "don't do X" rules. The result is a ~2,000-token baseline cost that degrades focus and wastes budget.

The fix is to treat `CLAUDE.md` like a focused recipe book: essential guidance only, everything else extracted to a location that loads on-demand. This skill does two things:

1. **Audit mode** — read an existing `CLAUDE.md`, diagnose what's bloat, and produce a slimmed rewrite plus an extraction plan (what moves where).
2. **Author mode** — interview about a new project and write a lean `CLAUDE.md` from scratch using the template.

## When to pick a mode

Detect mode from input:

- **The user points at an existing file, or one is visible in context** → audit mode.
- **The user wants a fresh `CLAUDE.md` for a new or undocumented project** → author mode.
- **Both** (they showed a file but also want a rewrite philosophy applied to a second project) → run audit first, carry the principles into the author pass.

If it's ambiguous, ask one clarifying question: "Are we trimming an existing one, or writing a new one?"

## The four-layer hierarchy — know where things actually belong

Every recommendation in this skill depends on understanding that `CLAUDE.md` isn't monolithic. Claude loads four layers in precedence order:

1. **Enterprise policy** — organization-wide, set by admins.
2. **`./CLAUDE.md`** — project-level, committed to the repo. This is what most people mean by "CLAUDE.md." Shared with every collaborator.
3. **`~/.claude/CLAUDE.md`** — user-level, personal defaults that apply across every project. Communication prefs, your own account info, your shell aliases.
4. **`./CLAUDE.local.md`** — project-local overrides, gitignored. Personal notes about this specific repo that shouldn't be shared with collaborators.

When you find content that doesn't belong in the project `CLAUDE.md`, the right extraction target is usually one of these other layers, not just "delete it."

**Rule of thumb for extraction:**
- Personal communication style, cross-project aliases, "I prefer X" → `~/.claude/CLAUDE.md`
- Ephemeral state (gcloud auth status, current sprint number, active branch) → `./CLAUDE.local.md`
- Team-shared conventions, tech stack, boundaries → stays in `./CLAUDE.md`
- Deep reference material (API docs, architecture deep-dives, runbooks) → `docs/`, referenced by path
- Repeatable multi-step workflows → extract into a Skill

## What belongs in project CLAUDE.md (the lean template)

A good project `CLAUDE.md` fits on roughly one screen (~200 lines max). See `references/template.md` for the full skeleton. The essential sections:

- **Project identity** — 2–3 sentences: what this codebase does and who it's for.
- **Tech stack** — language, framework, key APIs, deploy target, testing tool. One line each.
- **Code conventions** — the 3–7 house rules a new contributor would genuinely need on day one. Written as positive directives, not prohibitions.
- **Output preferences** — how Claude should present solutions in this repo (diff format, code-block length, explanation style).
- **Boundaries** — hard stops: files that should never be modified, secrets that should never be committed, commands that must run before finishing (lint/typecheck/test).
- **Quick reference** — pointers to main entry files, test locations, and `docs/` for anything deeper.

Everything else is bloat. If it's not needed on *every* interaction with this repo, it belongs somewhere that loads on demand.

## Audit mode — how to run it

### Step 1: Read the file and quantify

Read the target `CLAUDE.md`. Run `scripts/audit.py <path>` to get a structured report:

```bash
python3 scripts/audit.py <path-to-CLAUDE.md>
```

The script reports: line count, estimated token count (~4 chars/token heuristic), detected anti-patterns with line numbers, and section-by-section classification (essential / extract / delete).

If the file is already ≤200 lines and the audit finds no anti-patterns, tell the user it's already lean and stop. Don't invent problems.

### Step 2: Classify every section

For each section of the file, decide: **keep**, **extract**, or **delete**.

- **Keep** if it's essential project identity, a convention that affects every interaction, an output preference, or a hard boundary.
- **Extract** if it's useful but specific to a subset of interactions. Name the destination explicitly (`docs/hooks.md`, `~/.claude/CLAUDE.md`, `CLAUDE.local.md`, a new skill).
- **Delete** if it's obsolete, duplicated elsewhere (e.g., already in an installed skill), or a "just in case" note that's never actually referenced.

### Step 3: Apply the anti-pattern fixes

See `references/anti-patterns.md` for the full list and rewrite patterns. Summary:

- **Negative rules → positive rules.** "Don't use `var`" becomes "Use `const`/`let`." Positive instructions compile to shorter mental models and avoid reinforcing the thing you're trying to prevent.
- **Embedded reference docs → links.** A 200-line API schema inside `CLAUDE.md` becomes `See docs/api-reference.md for endpoint schemas.`
- **Tutorials / step-by-step procedures → Skills.** If it reads like a runbook, it belongs in `.claude/skills/<name>/SKILL.md` where it loads only when relevant.
- **Preemptive file preloads → removed.** Instructions like "Read `src/config.ts` at session start" are almost always wasteful; Claude can read files on demand when the task requires them.
- **Historical state / status tables → `CLAUDE.local.md`.** Anything dated (gcloud auth status from 3 weeks ago, "current sprint goal") is ephemeral and doesn't belong in a shared file.

### Step 4: Produce two outputs

1. **The rewritten `CLAUDE.md`** — the full replacement file, lean and ready to drop in.
2. **The extraction plan** — a clear list: "Lines X–Y (topic) → destination Z, because …" so the user can act on the extractions (create those docs, move content to user-level, etc.).

Show the before/after stats at the top of the plan: original line count, new line count, estimated token delta, percent reduction.

Do not silently lose content. Every deleted or moved section must appear somewhere in the extraction plan, so the user can audit the move.

## Author mode — how to run it

### Step 1: Interview

Ask the user about:
- **Identity**: What does the codebase do? (2–3 sentence answer)
- **Stack**: Language, framework, APIs, deploy target, test tool.
- **House rules**: Top 3–5 conventions new contributors need to know.
- **Output prefs**: Diff style, explanation length, any formatting requests.
- **Boundaries**: Files never to touch, secrets, required pre-finish checks.
- **References**: Where do architecture docs live? Canonical knowledge store (Notion, Confluence, `docs/`)?

Batch these questions — two or three at a time, not one by one. Don't ask about every conceivable section; the template has defaults for missing info.

### Step 2: Write the file

Fill in `references/template.md`. Keep each section tight. If a section has nothing real to put in it, delete the section rather than pad with "TBD" — missing sections are information, padding is noise.

### Step 3: Verify

Run `scripts/audit.py` on the result. It should pass all checks. If it doesn't (e.g., you accidentally included a 40-line JSON example), fix before delivering.

## Output format

Whichever mode, the final output structure is:

```
## Stats
[before/after line and token counts, percent reduction if auditing]

## CLAUDE.md
` ` `md
[the full lean file, ready to save]
` ` `

## Extraction plan  (audit mode only)
- Lines X–Y [topic] → [destination] — [one-line why]
- …

## Next steps
[concrete actions: create docs/foo.md with content X, add Y to ~/.claude/CLAUDE.md, etc.]
```

## Principle of lack of surprise

This skill only rewrites `CLAUDE.md`-family files (CLAUDE.md, AGENTS.md, CLAUDE.local.md). Never modify source code, configs, or secrets while doing this. Never delete the original until the user confirms the rewrite works — write the new file alongside the old one (e.g., `CLAUDE.md.new`) or show the diff and let them apply it.

If the audit would extract content to new files the user hasn't seen yet (a new `docs/hooks.md`, a new Skill), draft those too but clearly mark them as "proposed" — don't auto-create a web of new files without consent.

## Reference files

- `references/template.md` — The lean `CLAUDE.md` skeleton with all essential sections and inline guidance. Read this before writing in author mode.
- `references/anti-patterns.md` — The catalog of common bloat patterns with before/after rewrite examples. Read this before auditing.

## Script

- `scripts/audit.py` — Runs a quantitative audit: line count, token estimate, anti-pattern detection by regex, section classification. Use it at the start of audit mode and again as a final check on any rewrite (author or audit).
