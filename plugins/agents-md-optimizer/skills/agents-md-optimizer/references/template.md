# Lean CLAUDE.md template

Use this skeleton when authoring a new `CLAUDE.md`. Keep the whole file to roughly one screen. If a section has nothing real to say, delete the section — don't pad with "TBD."

```markdown
# Project: <short name>

## What this is

<2–3 sentences explaining what the codebase does, who it's for, and why it
exists. Someone skimming this should know whether they're in the right repo.>

## Tech stack

- **Language:** <e.g., TypeScript 5, Python 3.12>
- **Framework:** <e.g., Next.js 15 (App Router), FastAPI>
- **Key APIs:** <only the ones that matter for every task — the rest go in docs/>
- **Deploy:** <e.g., Vercel + Cloud Run worker; Fly.io; GitHub Pages>
- **Testing:** <e.g., Vitest + Playwright; pytest + hypothesis>

## Code conventions

- <Positive rule 1 — e.g., "Prefer server components; opt into `'use client'`
  only where interactivity is needed.">
- <Positive rule 2 — e.g., "Validate every external input with a `zod` schema
  at the boundary.">
- <3–7 rules total. Each one should be the kind of thing a new contributor
  would get wrong on their first PR without it.>

## Output preferences

- <e.g., "Show a brief diff summary before large edits; small edits just ship.">
- <e.g., "Keep code snippets under ~60 lines; link to the full file instead.">
- <e.g., "Explain the why, not the what — assume the reader can read the diff.">

## Boundaries

- **Never commit:** <secrets, `.env*`, generated artifacts — the hard list>
- **Always run before finishing:** <e.g., `pnpm lint && pnpm typecheck && pnpm test`>
- <Any other hard stop — e.g., "Don't touch `prisma/migrations/`; use
  `prisma migrate` instead.">

## Quick reference

- **Main entry:** <path/to/entry>
- **Routes / handlers:** <path>
- **Tests:** <path>
- **Deeper docs:** <`docs/` — list 2–3 key files by name, don't embed them>
- **Canonical knowledge:** <link to Notion / Confluence / wiki>
```

## Section notes

**What this is.** Resist the urge to market the project here. This is orientation, not a pitch. If you find yourself listing features, stop — features belong in the README, not `CLAUDE.md`.

**Tech stack.** One line per entry is the target. If you need two lines to describe a single dependency, it probably needs its own doc in `docs/`.

**Code conventions.** Frame rules as positives ("Use const/let"), not negatives ("Don't use var"). Positives are shorter and they tell Claude what to do instead of what to avoid. The exception is genuine hard stops ("Never modify files under `vendor/`") — those belong in Boundaries, not Conventions.

**Output preferences.** This is the most overlooked section. It's where you tune Claude's communication style for this repo specifically. A repo of quick utility scripts wants terse output; a monorepo with onboarding concerns wants more explanation. State the preference explicitly.

**Boundaries.** Only put hard stops here. Soft preferences belong in Conventions. If a rule has exceptions and judgment calls, it's a Convention. If violating it is a breaking incident, it's a Boundary.

**Quick reference.** Point to files by path, not by content. `See docs/api.md` is correct; pasting the contents of `docs/api.md` into `CLAUDE.md` defeats the point.

## What *not* to include

- API documentation. Link to it.
- Architecture deep-dives. Link to them.
- Historical decisions / changelogs. Those belong in `CHANGELOG.md` or PR descriptions.
- Per-session state (current branch, active sprint, recent incidents). That belongs in `CLAUDE.local.md` or nowhere at all.
- Personal communication preferences ("I prefer concise answers"). That belongs in `~/.claude/CLAUDE.md`, the user-level file, because it applies to all projects.
- Full hook JSON blocks, setup commands, install scripts. If it's a runnable procedure, it's a script or a Skill, not prose in `CLAUDE.md`.
- Re-statements of things Claude already knows (what Git is, what Python is, how HTTP works).
