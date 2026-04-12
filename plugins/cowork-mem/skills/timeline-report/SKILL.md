---
name: timeline-report
description: >
  Generate a chronological report of what happened across sessions.
  Use when the user asks "what have we done this week", "give me a history",
  "summarize what happened", "what changed recently", "show me the timeline",
  "weekly recap", "what did we accomplish", "show session history", or
  any request for a narrative summary of past work over a time period.
---

# timeline-report: What Happened When

Turns raw observations into a readable narrative of work done across sessions.

## Generating a Timeline

```bash
# Last 24 hours
python3 {SKILL_DIR}/scripts/memory_store.py timeline --hours 24 --limit 50

# Last week
python3 {SKILL_DIR}/scripts/memory_store.py timeline --hours 168 --limit 100

# All time (recent first)
python3 {SKILL_DIR}/scripts/memory_store.py stats  # check oldest date first
python3 {SKILL_DIR}/scripts/memory_store.py timeline --hours 9999 --limit 200
```

## Report Format

Group observations by session, then by day. Format as:

---
**[Session — Date]** Project: `<project>`

- **Decision:** <what was decided and why>
- **File edits:** <files changed and what changed>
- **Insights:** <things discovered>
- **Errors fixed:** <problems encountered and solutions>
- **Summary:** <session-end summary if available>
---

## Semantic Timeline (Topic-Based)

Instead of chronological, search for a topic across all time:
```bash
COWORK_MEM_DB=~/mnt/.claude/.cowork-mem/memory.db \
python3 {SKILL_DIR}/scripts/vector_search.py "<topic>" --limit 20
```

This answers "what happened with authentication across all sessions" better than a pure timeline.

## Export for Sharing

```bash
python3 {SKILL_DIR}/scripts/memory_store.py export --format md > /tmp/memory-export.md
```

Produces full markdown export suitable for sharing with teammates or saving to Drive.
