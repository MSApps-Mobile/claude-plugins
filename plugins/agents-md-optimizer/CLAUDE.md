# agents-md-optimizer

Plugin that audits and rewrites bloated `CLAUDE.md` / `AGENTS.md` files, or authors new ones lean from scratch.

## Skill

- `skills/agents-md-optimizer/SKILL.md` — core skill with audit and author modes
- `skills/agents-md-optimizer/references/template.md` — lean CLAUDE.md skeleton
- `skills/agents-md-optimizer/references/anti-patterns.md` — bloat pattern catalog
- `skills/agents-md-optimizer/scripts/audit.py` — quantitative audit script

## Quick reference

- **Target file size:** ≤200 lines, ≤1600 tokens
- **Anti-patterns:** negative rules, embedded docs, tutorials, preemptive preloads, dated state, personal prefs
- **Extraction targets:** `docs/` for reference material, `~/.claude/CLAUDE.md` for personal prefs, `CLAUDE.local.md` for ephemeral state, Skills for runnable procedures
