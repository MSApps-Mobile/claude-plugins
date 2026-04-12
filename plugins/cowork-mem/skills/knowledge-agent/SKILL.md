---
name: knowledge-agent
description: >
  Answer questions using accumulated project memory as a knowledge base.
  Use when the user asks "why did we choose X", "what's our approach to Y",
  "what do we know about Z", "explain how our auth works", "what's the
  deployment process", "what libraries are we using", "remind me why we
  did X this way", or any question that has likely been answered or decided
  in a previous session. Also trigger when making architectural decisions
  to check if a similar decision was already made.
---

# knowledge-agent: Memory as Knowledge Base

Your memory DB contains decisions, insights, and notes from past sessions.
Before answering questions from scratch, search it — you may have already
figured this out.

## Query Workflow

```bash
# 1. Semantic search for the concept
COWORK_MEM_DB=~/mnt/.claude/.cowork-mem/memory.db \
python3 {SKILL_DIR}/scripts/vector_search.py "<question>" --limit 8

# 2. Keyword search for specific terms
python3 {SKILL_DIR}/scripts/memory_store.py search "<key term>" --limit 5

# 3. Fetch full text for the most relevant results
python3 {SKILL_DIR}/scripts/memory_store.py get <id1> <id2>
```

## Answering from Memory

After retrieving relevant observations:
1. **Synthesize, don't quote** — distill what the observations say into a direct answer
2. **Cite the age** — "We decided this 3 days ago" gives the user confidence in freshness
3. **Flag uncertainty** — if observations are old or sparse, say so
4. **Update if stale** — if the situation has clearly changed, save a new observation

## When Memory Doesn't Know

If search returns nothing relevant:
1. Answer from your general knowledge or by reading the codebase
2. If you derive something new and useful, save it:
```bash
python3 {SKILL_DIR}/scripts/memory_store.py add insight \
  "<what you learned>" --tags "<relevant,tags>"
```

## Decision Archaeology

When the user asks "why did we do X this way?":
```bash
# Search specifically for past decisions
python3 {SKILL_DIR}/scripts/memory_store.py search "<X>" --type decision --limit 10
```

If you find a past decision, explain it with context. If you don't, note that
"this decision isn't in memory — here's what I'd infer from the codebase."
