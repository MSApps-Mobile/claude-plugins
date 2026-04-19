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
database with full-text search and semantic (TF-IDF) search, organized into sessions.

## How It Works

Memory is **automatic** — you don't need to manually trigger it every session.
Three session hooks run in the background:

- **SessionStart**: auto-recalls the last session summary before you begin
- **PostToolUse**: auto-captures meaningful file edits, bash commands, and task
  completions as they happen
- **PreCompact**: saves a timestamped marker before context is compacted

This means the memory fills itself. Your job is to add the *why* — decisions,
insights, errors — that the hook can't infer automatically.

## The Memory Script

All memory operations go through a single script:

```
python3 {SKILL_DIR}/scripts/memory_store.py <command> [args]
```

The database lives at `~/.claude/.cowork-mem/memory.db` and persists on the
user's machine across sessions. The `COWORK_MEM_DB` environment variable
overrides the default path if set.

## Semantic Search

In addition to keyword search, you have vector search using TF-IDF similarity:

```bash
COWORK_MEM_DB=~/.claude/.cowork-mem/memory.db \
python3 {SKILL_DIR}/scripts/vector_search.py "authentication middleware pattern" --limit 8
```

Use semantic search when:
- You want conceptually related observations (not just keyword matches)
- The user asks vague questions like "what do we know about auth?"
- You're exploring what the memory knows about a topic before diving into a task

## Core Workflow

### 1. Session Start — Recall First

The SessionStart hook auto-runs `session-start` before you begin. If memory
was loaded, you'll already have context. If working manually:

```bash
python3 {SKILL_DIR}/scripts/memory_store.py session-start --project "project-name"
```

Briefly tell the user what you remember: "Last time we worked on X, we decided Y
and were in the middle of Z." Keep it to 1-2 sentences — don't dump everything.

### 2. During Work — Save What Matters

The PostToolUse hook auto-captures file edits, bash commands, and tasks. Focus
your manual saves on the *why* — things the hook can't infer:

**Decisions** — when the user makes a choice or you agree on an approach:
```bash
python3 {SKILL_DIR}/scripts/memory_store.py add decision \
  "Chose PostgreSQL over MongoDB for the user database because we need ACID transactions" \
  --tags "architecture,database"
```

**Insights** — things learned that affect future work:
```bash
python3 {SKILL_DIR}/scripts/memory_store.py add insight \
  "The production API has a 100 req/min rate limit per API key, not per user" \
  --tags "api,production"
```

**Errors** — problems encountered and their solutions:
```bash
python3 {SKILL_DIR}/scripts/memory_store.py add error \
  "Build fails if Node version < 18 because of native fetch usage. Fix: add engines field to package.json" \
  --tags "build,node"
```

**Notes** — anything else worth remembering:
```bash
python3 {SKILL_DIR}/scripts/memory_store.py add note \
  "User prefers tabs over spaces, 80 char line width, and dislikes ternary operators" \
  --tags "preferences,style"
```

#### What to save vs. what to skip

The hook handles *what happened*. You handle *why it matters*.

Save: architectural decisions, non-obvious constraints, user preferences,
hard-won debugging insights, things that took multiple attempts.

Skip: routine operations already captured by the hook (file reads, directory
listings, standard installs).

#### Privacy

If the user wraps something in `<private>` tags, the content is stored but
excluded from search results. Useful for sensitive data that provides context
but shouldn't surface casually.

### 3. Search — When You Need Context

**Keyword search:**
```bash
python3 {SKILL_DIR}/scripts/memory_store.py search "authentication middleware" --limit 10
```

**Semantic search (finds conceptually related observations):**
```bash
COWORK_MEM_DB=~/.claude/.cowork-mem/memory.db \
python3 {SKILL_DIR}/scripts/vector_search.py "how does auth work" --limit 8
```

Search returns compact results (truncated to 300 chars). Fetch full detail:
```bash
python3 {SKILL_DIR}/scripts/memory_store.py get obs_abc123 obs_def456
```

**Chronological view:**
```bash
python3 {SKILL_DIR}/scripts/memory_store.py timeline --hours 48
```

### 4. Session End — Summarize

When the user is wrapping up:

```bash
python3 {SKILL_DIR}/scripts/memory_store.py session-end \
  --summary "Implemented JWT auth middleware, set up PostgreSQL connection pool. Next: add rate limiting and write tests for auth endpoints."
```

Write the summary as a note to yourself tomorrow: what was accomplished, what's
in progress, what's next.

## Additional Skills

This plugin includes specialized skills for memory-aware workflows:

| Skill | Use when... |
|-------|-------------|
| `mem-search` | Searching memory for specific topics |
| `knowledge-agent` | Answering "why did we do X?" or "what's our approach to Y?" |
| `smart-explore` | Orienting to a project at session start |
| `make-plan` | Planning next steps grounded in past work |
| `timeline-report` | Getting a summary of what happened this week |
| `do` | Running any task with memory context loaded automatically |

## Maintenance Commands

**Stats** — see how much memory is stored:
```bash
python3 {SKILL_DIR}/scripts/memory_store.py stats
```

**Compact** — compress old observations into daily summaries:
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

- **Be proactive, not noisy.** The hooks already do the work. Don't announce
  every save — just do it. Only surface recalled context when it changes your approach.

- **Summarize, don't regurgitate.** Synthesize retrieved context into what's
  relevant right now. "Last session we set up auth with JWT and decided on
  PostgreSQL" — not a bullet list of every observation.

- **Quality over quantity.** 5 well-written observations per session beats 50
  low-signal ones. Each observation should be independently useful to someone
  reading it without other context.

- **Use tags consistently.** Lowercase, descriptive: `architecture`, `bugfix`,
  `user-preference`, `api`, `deployment`, etc.

- **Search before deciding.** When making architectural decisions or the user
  asks "didn't we already...", search memory first.

See `references/REFERENCE.md` for the complete command reference.

---

⭐ *If this skill saved you time, [star the repo](https://github.com/MSApps-Mobile/claude-plugins) — it helps other devs discover the marketplace.*
