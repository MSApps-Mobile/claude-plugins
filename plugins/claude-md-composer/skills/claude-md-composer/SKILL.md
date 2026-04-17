---
name: claude-md-composer
description: Audit, compose, and refactor CLAUDE.md files so they stay under the token budget. Use when the user says "audit my CLAUDE.md", "my CLAUDE.md is too long", "compose a CLAUDE.md", "refactor CLAUDE.md", "CLAUDE.md is eating tokens", "flip negative rules", "extract bloat out of CLAUDE.md", "set up the CLAUDE.md hierarchy", "write a CLAUDE.md for this project", or any request to create, shrink, or reorganize a CLAUDE.md file. Works on the root CLAUDE.md, feature-level CLAUDE.md (in subdirs), user-level ~/.claude/CLAUDE.md, and local CLAUDE.local.md.
---

# CLAUDE.md Composer

Treat CLAUDE.md as a **recipe book on the counter**, not a filing cabinet. Every token in CLAUDE.md is loaded into every session — so keep only what's needed for **every** interaction, and push everything else to Skills, `docs/`, or Commands.

## The 200-line rule

The root CLAUDE.md should fit on one screen (~200 lines max). If it doesn't, something belongs elsewhere.

## When to use this skill

1. **Audit** — user has an existing CLAUDE.md and wants it trimmed
2. **Compose** — user wants a fresh CLAUDE.md for a project
3. **Refactor** — split monolith into the 4-level hierarchy
4. **Flip** — convert negative rule lists to positive equivalents

## The 4-level hierarchy

```
Enterprise policy         ← org-wide, IT-managed, highest precedence
       ↓
./CLAUDE.md               ← project memory (committed)
       ↓
~/.claude/CLAUDE.md       ← user memory (personal, all projects)
       ↓
./CLAUDE.local.md         ← project local (gitignored, private)
```

Feature-level CLAUDE.md files in subdirs load **only when Claude touches that subtree** — use them to scope per-folder conventions (`/api`, `/frontend`) without paying the token cost globally.

## Workflow

### Step 1 — Audit existing file

Read the target CLAUDE.md and report:

- Line count (flag if >200)
- Token estimate (~4 chars/token)
- Bloat categories found (see [reference/anti-patterns.md](reference/anti-patterns.md))
- Candidates for extraction (docs dumps, file preloads, step-by-step tutorials, negative rule spirals)

### Step 2 — Classify every section

For each section, decide:

| Keep in CLAUDE.md | Extract |
|-------------------|---------|
| Project identity (2-3 sentences) | API documentation → `docs/api.md` |
| House rules (positive form) | Step-by-step workflows → Skill |
| Output preferences | Reusable prompts → slash command |
| Hard boundaries | File preloads (`@file:…`) — delete |
| Quick reference (paths, entry points) | Detailed reference tables → `docs/` |

### Step 3 — Apply the recipe-book template

See [reference/template.md](reference/template.md) for the canonical ~40-line shape. Sections:

1. `# Project: <Name>` — one line
2. `## What This Is` — 2-3 sentences
3. `## Tech Stack` — bullet list
4. `## Code Conventions` — positive-form rules
5. `## Output Preferences` — how Claude should present work
6. `## Boundaries` — never-touch files, always-run commands
7. `## Quick Reference` — pointers to `docs/`, entry points, test layout

### Step 4 — Flip negatives to positives

Negative lists burn tokens telling Claude what NOT to do. Replace:

```
Don't use var. Don't use any. Don't use console.log. Don't use ==.
```

With:

```
Use const/let, strict TypeScript, triple equals.
```

Same rules, ~40% fewer tokens.

### Step 5 — Reference, don't include

Replace `@file:` preloads and inlined docs with pointers:

```
## API Reference
See docs/api-reference.md. Read it when working with API endpoints.
```

### Step 6 — Split across hierarchy

Move content to the correct level:

- **Personal taste** (verbose vs terse, emoji preference) → `~/.claude/CLAUDE.md`
- **Project standards** (stack, conventions, boundaries) → `./CLAUDE.md`
- **Secret/local overrides** (local DB URL, personal notes) → `./CLAUDE.local.md` (gitignored)
- **Subdir-specific conventions** (API style, frontend style) → `./<subdir>/CLAUDE.md`

### Step 7 — Verify

- Line count ≤ 200
- Zero `@file:` preloads at root
- Zero "Don't …" rules (all flipped)
- Every inlined doc >10 lines replaced with a `See docs/…` pointer
- Title is `# Project: <Name>` format

## Anti-patterns

See [reference/anti-patterns.md](reference/anti-patterns.md) for the full taxonomy:

- The documentation dump (entire API specs inlined)
- The negative spiral (Don't X, Don't Y, Don't Z)
- The kitchen sink (30+ file preloads)
- The everything-tutorial (step-by-step workflows inlined)

## Output

When running an audit, return:

1. **Before/after line count + token estimate**
2. **Slim CLAUDE.md** (applied template)
3. **Extraction plan** — what moved to `docs/`, what became a Skill, what went to user/local level
4. **Diff** — clear delta for review

## Examples

See [examples/](examples/):

- [examples/audit-before-after.md](examples/audit-before-after.md) — 500-line file → 40-line file
- [examples/fresh-compose.md](examples/fresh-compose.md) — new project from scratch
- [examples/negative-flip.md](examples/negative-flip.md) — rule-list transformation

## Inspiration

This skill is based on Kjramsy's Medium article *"Your CLAUDE.md is eating your token budget (here's how to fix it)"* (Jan 2026): <https://medium.com/@kjramsy/your-claude-md-is-eating-your-token-budget-heres-how-to-fix-it-b8d6c4d1c986>
