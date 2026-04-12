---
name: do
description: >
  Execute a task using memory for context — the memory-aware task runner.
  Use when the user says "do X", "implement Y", "fix Z", "build this",
  "continue working on", "pick up where we left off", "keep going", or
  any task that benefits from knowing what was already done. This skill
  wraps task execution with memory recall at the start and observation
  capture at the end — making every task build on prior work.
---

# do: Memory-Aware Task Execution

Every task you run should start from what you know, not from zero.

## Execution Workflow

### Before you start: Load context
```bash
# What's already done / decided related to this task?
COWORK_MEM_DB=~/mnt/.claude/.cowork-mem/memory.db \
python3 {SKILL_DIR}/scripts/vector_search.py "<task description>" --limit 8

# Any relevant errors or blockers?
python3 {SKILL_DIR}/scripts/memory_store.py search "<key term>" --type error --limit 5
```

Use the recalled context to:
- Skip work that's already done
- Avoid approaches that previously failed (check errors)
- Follow established patterns (check past decisions)
- Build on existing file structure (check file_edits)

### During execution: Save what matters

As you work, save observations for significant actions:
```bash
# When you make a choice
python3 {SKILL_DIR}/scripts/memory_store.py add decision \
  "<what you chose and why>" --tags "<task-tag>"

# When you discover something non-obvious
python3 {SKILL_DIR}/scripts/memory_store.py add insight \
  "<what you learned>" --tags "<task-tag>"

# When you hit an error and solve it
python3 {SKILL_DIR}/scripts/memory_store.py add error \
  "<error encountered + solution>" --tags "<task-tag>"
```

Don't over-log. Save things future-you would want to know that aren't obvious from the code.

### After completion: Close the loop
```bash
python3 {SKILL_DIR}/scripts/memory_store.py add note \
  "Completed: <what was done>. Status: <done/partial>. Next: <what remains>" \
  --tags "completed,<task-tag>"
```

## Parallelism with PostToolUse Hook

If the PostToolUse hook is active, file edits and bash commands are captured
automatically. Focus your manual saves on:
- **Decisions** (why you chose this approach)
- **Insights** (non-obvious things you discovered)
- **Errors** (problems and solutions)

The hook handles the "what happened"; you handle the "why it matters."
