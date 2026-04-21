# agents-md-optimizer

Audit bloated agent-instruction files (`CLAUDE.md`, `AGENTS.md`, and their local/user-level variants) and rewrite them lean — or author a new one from scratch following the 200-line "recipe book" principle.

## What it does

`CLAUDE.md` is loaded into every Claude session. Every line is a recurring tax on the context window, paid before any real work starts, across every session, forever. Most files drift into bloat: embedded API docs, step-by-step tutorials, hoarded historical state, stacked negative "don't do X" rules.

This plugin provides two modes:

| Mode | When to use |
|------|-------------|
| **Audit** | You have an existing file that's grown too large or has anti-patterns |
| **Author** | You want a lean `CLAUDE.md` for a new or undocumented project |

## Skills

### `agents-md-optimizer`

The core skill. Detects the right mode from context and runs accordingly.

**Audit mode** — reads the target file, runs `scripts/audit.py` for a quantitative report (line count, token estimate, anti-patterns with line numbers), classifies every section as keep/extract/delete, and produces:
1. The full rewritten file, lean and ready to drop in
2. An extraction plan mapping every removed section to its correct destination

**Author mode** — interviews the user (project identity, stack, house rules, output prefs, boundaries) and writes a lean file using `references/template.md`.

## Trigger phrases

- "My CLAUDE.md is too big"
- "Trim / audit my CLAUDE.md"
- "Write a CLAUDE.md for my new project"
- "Optimize my agent instructions"
- "AGENTS.md is bloated"
- Any `CLAUDE.md` or `AGENTS.md` in context that is >200 lines or contains known anti-patterns

## The four-layer hierarchy

Understanding where things belong is the core of this skill:

1. **Enterprise policy** — org-wide, set by admins
2. **`./CLAUDE.md`** — project-level, committed to the repo, shared with every collaborator
3. **`~/.claude/CLAUDE.md`** — user-level, personal defaults across every project
4. **`./CLAUDE.local.md`** — project-local, gitignored, personal notes about this specific repo

## Anti-patterns detected

| Pattern | Fix |
|---------|-----|
| Negative rules stacked | Flip to positive directives |
| Embedded reference docs | Move to `docs/`, add a pointer |
| Step-by-step tutorials | Extract to a script or Skill |
| Preemptive file preloads | Delete — Claude reads on demand |
| Ephemeral / dated state | Move to `CLAUDE.local.md` |
| Personal preferences | Move to `~/.claude/CLAUDE.md` |
| Duplicated skill content | Delete — skill already covers it |
| General knowledge re-statements | Delete |

## Reference files

- `skills/agents-md-optimizer/references/template.md` — lean `CLAUDE.md` skeleton
- `skills/agents-md-optimizer/references/anti-patterns.md` — catalog of bloat patterns with before/after rewrites
- `skills/agents-md-optimizer/scripts/audit.py` — quantitative audit script

## Script usage

```bash
python3 skills/agents-md-optimizer/scripts/audit.py path/to/CLAUDE.md
python3 skills/agents-md-optimizer/scripts/audit.py path/to/CLAUDE.md --json
python3 skills/agents-md-optimizer/scripts/audit.py path/to/CLAUDE.md --strict
```

## Install

Install via the Cowork plugin system or copy `skills/agents-md-optimizer/` into your `.claude/skills/` directory.
