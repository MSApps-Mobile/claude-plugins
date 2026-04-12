---
name: smart-explore
description: >
  Explore a project or codebase using memory as a guide. Use when the user
  says "explore this project", "understand the codebase", "give me an overview",
  "catch me up on this project", "what's the state of X", "orient me", or
  starts working on a project that likely has prior sessions.
  Also trigger at the start of any new session on an ongoing project
  to build context before diving in.
---

# smart-explore: Memory-Guided Project Exploration

Before reading files blindly, check what memory already knows. Past sessions may
have documented the architecture, key files, gotchas, and current status.

## Exploration Workflow

### 1. Check memory first
```bash
# What do we know about this project?
COWORK_MEM_DB=~/mnt/.claude/.cowork-mem/memory.db \
python3 {SKILL_DIR}/scripts/vector_search.py "project architecture overview" --limit 8

# Any recent decisions or file edits?
python3 {SKILL_DIR}/scripts/memory_store.py timeline --hours 168 --limit 20
```

### 2. Orient from memory → fill gaps with file reads

Use what memory tells you to target your file reads:
- If memory mentions `src/auth.py` was refactored, read that file
- If memory notes a known bug in the API layer, look there first
- Skip files that memory says are stable/untouched

### 3. Build a mental model

After combining memory recall + targeted file reads, produce a brief summary:
- **What the project does** (1 sentence)
- **Current state** (what's working, what's in progress)
- **Key files / architecture** (3-5 most relevant)
- **Active issues or blockers** (from memory)
- **What to work on next** (from last session summary)

### 4. Save any new insights
```bash
python3 {SKILL_DIR}/scripts/memory_store.py add insight \
  "Project overview: <what you learned>" --tags "architecture,overview"
```

## What Makes This "Smart"

Regular exploration = read every file from scratch.
Smart-explore = memory tells you where to look, so you read 20% of the files
and understand 80% of the project state.
