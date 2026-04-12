---
name: make-plan
description: >
  Create a work plan using memory context from past sessions. Use when the user
  says "make a plan", "what should we do next", "plan this out", "give me a
  roadmap", "help me prioritize", "what's the next step", "plan the sprint",
  or any request to organize upcoming work. Memory ensures the plan is grounded
  in what's already done, decided, and known to be broken.
---

# make-plan: Memory-Grounded Planning

A good plan starts from the current state, not a blank slate. Memory tells you
what's been decided, what's blocking progress, and what was left mid-session.

## Planning Workflow

### 1. Load context from memory
```bash
# What was done recently?
python3 {SKILL_DIR}/scripts/memory_store.py timeline --hours 168 --limit 30

# What's in progress / blocked?
COWORK_MEM_DB=~/mnt/.claude/.cowork-mem/memory.db \
python3 {SKILL_DIR}/scripts/vector_search.py "in progress blocked next step" --limit 10

# What did the last session summary say?
python3 {SKILL_DIR}/scripts/memory_store.py search "session summary" --type summary --limit 5
```

### 2. Check for known errors or constraints
```bash
python3 {SKILL_DIR}/scripts/memory_store.py search "error bug blocked" --type error --limit 5
```

### 3. Build the plan

Structure the plan as:
- **Context**: What we know from memory (1-3 bullets, specific)
- **Goal**: What we're trying to accomplish
- **Steps**: Numbered, specific, actionable — reference actual files and systems
- **Blockers**: Known issues from memory that affect the plan
- **Open questions**: Things we'd need to investigate

### 4. Save the plan as a decision
```bash
python3 {SKILL_DIR}/scripts/memory_store.py add decision \
  "Plan: <summary of steps>" --tags "plan,session-goal"
```

## Planning Tips

- Plans built from memory are more accurate than plans from scratch — use it
- Surface blockers from memory explicitly; don't let them be surprises mid-sprint
- If memory has conflicting decisions, flag it for the user to resolve
- Short plans (3-5 steps) are better than exhaustive ones — you can always plan the next thing after
