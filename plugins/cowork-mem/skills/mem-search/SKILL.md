---
name: mem-search
description: >
  Search persistent memory using keyword or semantic (TF-IDF) search.
  Use when the user asks "do we have any notes on X", "what do we know about Y",
  "did we decide anything about Z", "search memory for", "recall anything about",
  "look up in memory", or any question about past decisions, errors, or context.
  Also trigger proactively when answering questions where past context would help.
---

# mem-search: Smart Memory Search

Search cowork-mem with two complementary modes — keyword FTS5 and semantic TF-IDF.
Use both for important queries; keyword finds exact matches, semantic finds related ideas.

## Quick Search

**Keyword (FTS5 — fast, exact):**
```bash
python3 {SKILL_DIR}/scripts/memory_store.py search "<query>" --limit 10
```

**Semantic (TF-IDF — finds related concepts):**
```bash
COWORK_MEM_DB=~/mnt/.claude/.cowork-mem/memory.db \
python3 {SKILL_DIR}/scripts/vector_search.py "<query>" --limit 10
```

**Fetch full detail on specific results:**
```bash
python3 {SKILL_DIR}/scripts/memory_store.py get obs_abc123 obs_def456
```

## When to Use Each Mode

| Mode | Best for |
|------|---------|
| Keyword | Exact tool names, file paths, error messages |
| Semantic | "what did we decide about auth", "any DB issues", "deployment problems" |

## Search Workflow

1. Start with semantic search — it catches paraphrases
2. If results are weak, run keyword search as a fallback
3. For any result worth reading in full, call `get <id>`
4. Synthesize what you found into 1-2 sentences before acting on it

## Filter by Type

```bash
# Only past decisions
python3 {SKILL_DIR}/scripts/memory_store.py search "<query>" --type decision

# Only errors and solutions
python3 {SKILL_DIR}/scripts/memory_store.py search "<query>" --type error
```

Types: `decision`, `file_edit`, `tool_use`, `insight`, `error`, `note`, `summary`
