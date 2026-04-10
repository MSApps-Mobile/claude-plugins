---
name: cowork-mem
description: >
  Persistent memory across Cowork sessions. Use this skill at the START of every
  session to recall what happened before, and throughout any session to save
  important context — decisions, file changes, insights, errors, tool usage.
  Trigger whenever: the user says "remember this", "what did we do last time",
  "save this", "recall", "memory", "context from before", "what was the decision on",
  "continue where we left off", or starts a new session on an ongoing project.
  Also trigger when the user references past work, asks about project history,
  or says anything suggesting they expect continuity across sessions. Even if the
  user doesn't explicitly mention memory, if they're working on a project that
  has prior sessions, proactively check memory for relevant context.
---

# Cowork-Mem: Persistent Memory for Cowork

You have access to a persistent memory system that survives across Cowork sessions.
It stores observations (decisions, file edits, insights, errors, notes) in a SQLite
database with full-text search, organized into sessions.

Think of it like claude-mem but built natively for Cowork: no background services,
no hooks — just a Python script you call to read and write memories.

## The Memory Script

All memory operations go through a single script:

```
python3 {SKILL_DIR}/scripts/memory_store.py <command> [args]
```

The database lives at `{WORKSPACE}/.cowork-mem/memory.db` and persists on the
user's machine across sessions.

## Core Workflow

### 1. Session Start — Always Recall First

At the beginning of every session (or when starting work on a project), check
what happened before:

```bash
python3 {SKILL_DIR}/scripts/memory_store.py session-start --project "project-name"
```

This returns the last session's summary and recent context for that project. If
the user hasn't named the project, infer it from context or ask.

Then briefly tell the user what you remember: "Last time we worked on X, we
decided Y and were in the middle of Z." Keep it to 1-2 sentences — don't dump
the whole history.

### 2. During Work — Save What Matters

As you work, save observations that future sessions would benefit from knowing.
Not every action — just the important ones:

**Decisions** — when the user makes a choice or you agree on an approach:
```bash
python3 {SKILL_DIR}/scripts/memory_store.py add decision "Chose PostgreSQL over MongoDB for the user database because we need ACID transactions" --tags "architecture,database"
```

**File edits** — significant structural changes (not every typo fix):
```bash
python3 {SKILL_DIR}/scripts/memory_store.py add file_edit "Refactored auth module to use middleware pattern, moved from src/auth.py to src/middleware/auth.py" --tags "refactor" --context "files:src/middleware/auth.py"
```

**Insights** — things learned that affect future work:
```bash
python3 {SKILL_DIR}/scripts/memory_store.py add insight "The production API has a 100 req/min rate limit per API key, not per user" --tags "api,production"
```

**Errors** — problems encountered and their solutions:
```bash
python3 {SKILL_DIR}/scripts/memory_store.py add error "Build fails if Node version < 18 because of native fetch usage. Solution: add engines field to package.json" --tags "build,node"
```

**Notes** — anything else worth remembering:
```bash
python3 {SKILL_DIR}/scripts/memory_store.py add note "User prefers tabs over spaces, 80 char line width, and dislikes ternary operators" --tags "preferences,style"
```

#### What to save vs. what to skip

Save things that help future-you understand the project state: architectural
decisions, non-obvious constraints, user preferences, hard-won debugging
insights, things that took multiple attempts to get right.

Skip routine operations: reading files, listing directories, standard installs.
If you'd forget it in 5 minutes, future-you doesn't need it either.

#### Privacy

If the user wraps something in `<private>` tags, the content is stored but
excluded from search results. Useful for sensitive data that provides context
but shouldn't surface casually.

### 3. Search — When You Need Context

When the user asks about past work, or when you need context to make a decision:

```bash
python3 {SKILL_DIR}/scripts/memory_store.py search "authentication middleware" --limit 10
```

Search returns compact results (truncated to 300 chars). If you need full
details on specific observations, fetch them:

```bash
python3 {SKILL_DIR}/scripts/memory_store.py get obs_abc123 obs_def456
```

This is the same 3-layer retrieval pattern as claude-mem: search → scan → fetch.
It keeps token usage low.

For chronological context, use timeline:

```bash
python3 {SKILL_DIR}/scripts/memory_store.py timeline --hours 48
```

### 4. Session End — Summarize

When the user is wrapping up (they say goodbye, the conversation is ending, or
they're switching to a different project):

```bash
python3 {SKILL_DIR}/scripts/memory_store.py session-end --summary "Implemented JWT auth middleware, set up PostgreSQL connection pool. Next: add rate limiting and write tests for auth endpoints."
```

Write the summary as if you're leaving a note for yourself tomorrow. Include:
what was accomplished, what's in progress, and what's next.

## Maintenance Commands

**Stats** — see how much memory is stored:
```bash
python3 {SKILL_DIR}/scripts/memory_store.py stats
```

**Compact** — compress old observations into daily summaries to save space:
```bash
python3 {SKILL_DIR}/scripts/memory_store.py compact --before-days 30
```

**Export** — dump everything as JSON or Markdown:
```bash
python3 {SKILL_DIR}/scripts/memory_store.py export --format md
```

**Delete** — remove specific observations:
```bash
python3 {SKILL_DIR}/scripts/memory_store.py delete obs_abc123
```

## Behavior Guidelines

- **Be proactive, not noisy.** Check memory at session start without being asked.
  Save observations as you go without announcing each one. Only mention memory
  operations when the user asks or when recalled context changes your approach.

- **Summarize, don't regurgitate.** When recalling past context, synthesize it
  into what's relevant right now. "Last session we set up auth with JWT and
  decided on PostgreSQL" — not a bullet list of every observation.

- **Quality over quantity.** 5 well-written observations per session is better
  than 50 low-signal ones. Each observation should be independently useful to
  someone reading it without other context.

- **Use tags consistently.** Tags help with retrieval. Use lowercase, descriptive
  tags: `architecture`, `bugfix`, `user-preference`, `api`, `deployment`, etc.

- **Search before deciding.** When making architectural decisions or the user asks
  "didn't we already...", search memory first. Past decisions are valuable context.

See `references/REFERENCE.md` for the complete command reference with all options.
