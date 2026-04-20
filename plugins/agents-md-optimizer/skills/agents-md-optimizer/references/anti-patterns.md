# CLAUDE.md anti-patterns and how to fix them

Each pattern below is something that commonly bloats `CLAUDE.md`. For each one: how to spot it, why it's a problem, and the rewrite.

## 1. Negative rules stacked on negative rules

**Spot it:** Lines starting with "Don't", "Never", "Avoid", "Do not", especially stacked 3+ in a row.

**Why it's a problem:** Negative rules force the reader (human or model) to hold the forbidden concept in mind while simultaneously trying to suppress it. They also tend to multiply — every new mistake adds a new "don't" rather than revising the positive rule.

**Rewrite:** Flip to a positive directive that makes the forbidden thing unnecessary.

| Before | After |
|---|---|
| `Don't use var. Don't use let in global scope. Don't mutate globals.` | `Use const at module scope. Use let only inside the narrowest block that needs reassignment.` |
| `Never hardcode API keys. Never put credentials in code.` | `Read credentials from environment variables; never commit .env files.` |
| `Don't write inline styles. Don't use CSS-in-JS at runtime.` | `Style with Tailwind utility classes; extend via tailwind.config.ts when needed.` |

**Exception:** Genuine hard stops with no positive rephrasing ("Never modify files under `vendor/`") belong in the Boundaries section and stay negative — because that's their actual semantic: a prohibition, not a preference.

## 2. Embedded reference docs

**Spot it:** Long code blocks, JSON schemas, API tables, type definitions, HTTP endpoint lists. Usually 20+ contiguous lines.

**Why it's a problem:** Reference docs are consulted rarely. `CLAUDE.md` loads every session. A 200-line schema in `CLAUDE.md` is 200 lines spent on context most tasks don't need.

**Rewrite:** Move to `docs/` and replace with a pointer.

**Before:**
```markdown
## API endpoints
POST /api/users — create user. Body: { email, name, role }. Returns 201 with { id, ... }.
GET /api/users/:id — fetch user.
... [80 more lines]
```

**After:**
```markdown
## API endpoints
See `docs/api-reference.md` for endpoint schemas and example payloads.
```

## 3. Step-by-step tutorials

**Spot it:** Numbered lists with imperative steps, especially "first do X, then do Y, verify Z." Setup guides. "How to deploy" procedures.

**Why it's a problem:** Tutorials are runnable procedures. Their natural home is either (a) a shell script, (b) a `Makefile`/`justfile` target, or (c) a Claude Skill that loads when the task triggers. Baking them into `CLAUDE.md` pays the context cost on every unrelated task.

**Rewrite:** Extract to whichever of those three is appropriate.

| Tutorial content | Best destination |
|---|---|
| "How to run migrations" | `scripts/migrate.sh` or `package.json` script |
| "How to set up a new environment" | A Skill (runs on "set up new env" prompts) |
| "How to add a new feature flag" | `docs/feature-flags.md`, linked from Quick reference |

## 4. Preemptive file preloads

**Spot it:** Instructions like "Read `src/config.ts` at session start", "Always load `docs/architecture.md` first", "Before responding, review `schema.prisma`."

**Why it's a problem:** These force a read on every session, including tasks where the file is irrelevant. They also signal a lack of trust in on-demand reading, which tends to compound — next the user adds a second preload, then a third.

**Rewrite:** Delete. Replace with a pointer in Quick reference: `Main schema: prisma/schema.prisma`. Claude will read it when the task calls for it.

## 5. Ephemeral / dated state in the shared file

**Spot it:** Status tables ("As of 2024-11-01, auth uses X"), current sprint info, open incident notes, "current" API tokens, active deploy environments with timestamps.

**Why it's a problem:** This content goes stale fast, and when it does, it quietly misleads everyone who loads the file. It's also often personal to the author rather than team-shared.

**Rewrite:** Move to `CLAUDE.local.md` (gitignored, personal) or delete. If the information is genuinely useful to the team and stable, rewrite it as a non-dated fact.

## 6. Personal preferences in the project file

**Spot it:** "I like terse responses", "Address me as <name>", "Always reply in English even if my message is in another language", personal aliases.

**Why it's a problem:** The project `CLAUDE.md` is committed to the repo and shared with every collaborator. Your preferences aren't theirs.

**Rewrite:** Move to `~/.claude/CLAUDE.md`, the user-level file.

## 7. Duplicated skill content

**Spot it:** Sections in `CLAUDE.md` that re-state something already covered in an installed Skill's `SKILL.md`.

**Why it's a problem:** You're paying the cost twice — once in `CLAUDE.md` on every session, once in the skill when it triggers.

**Rewrite:** Delete from `CLAUDE.md`. The skill loads when it's needed.

## 8. Re-statements of general knowledge

**Spot it:** Explanations of what Git is, how REST works, what TypeScript does.

**Why it's a problem:** Claude already knows this. Re-stating it wastes context and reads as noise.

**Rewrite:** Delete. Keep only non-obvious project-specific twists.

## 9. "Just in case" notes

**Spot it:** Content that's been in the file for months without being referenced. Notes like "If you run into X, do Y" where X has never actually happened.

**Why it's a problem:** Every "just in case" note pays for itself every session, forever, whether or not the case ever occurs.

**Rewrite:** Delete. If X does happen, the user can ask directly.

## Quick decision tree

When you look at a section and aren't sure whether to keep, extract, or delete:

1. **Is this needed on more than half of interactions with this repo?** If no → extract or delete.
2. **Is this team-shared, or personal to the author?** Personal → `~/.claude/CLAUDE.md` or `CLAUDE.local.md`.
3. **Is this stable fact, or dated state?** Dated → `CLAUDE.local.md` or rewrite non-dated.
4. **Does a Skill already cover this?** Yes → delete.
5. **Is this a runnable procedure?** Yes → script or Skill, not prose.
6. **Is this general knowledge Claude already has?** Yes → delete, keep only the project-specific twist.

If after all six it still passes, it earns its place in the project `CLAUDE.md`.
