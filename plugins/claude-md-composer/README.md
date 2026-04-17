# claude-md-composer

Audit, compose, and refactor `CLAUDE.md` files so they stay lean and stop eating your token budget.

## The problem

`CLAUDE.md` loads into **every** session. A 2,000-token CLAUDE.md burns 200k tokens across 100 sessions — usually because people stuff API docs, step-by-step tutorials, file preloads, and walls of "Don't …" rules into it.

## What this skill does

Applies the **recipe-book, not filing-cabinet** pattern:

| Keep in CLAUDE.md | Move out |
|-------------------|----------|
| Project identity (2-3 sentences) | API docs → `docs/api.md` |
| House rules (positive form) | Workflows → a Skill |
| Output preferences | Reusable prompts → slash command |
| Hard boundaries | `@file:` preloads — delete |
| Quick reference pointers | Reference tables → `docs/` |

Enforces:

- **200-line rule** on the root CLAUDE.md
- **Negative → positive** rule flipping
- **Reference, don't include** for large docs
- **4-level hierarchy** split: enterprise → project → user → local (+ optional feature-level `./<subdir>/CLAUDE.md`)

## Trigger phrases

- "audit my CLAUDE.md"
- "my CLAUDE.md is too long"
- "compose a CLAUDE.md"
- "refactor CLAUDE.md"
- "CLAUDE.md is eating tokens"
- "flip the negative rules in CLAUDE.md"
- "set up the CLAUDE.md hierarchy"

## Install

```bash
/plugin install claude-md-composer@msapps-plugins
```

## What's inside

```
skills/claude-md-composer/
├── SKILL.md
├── reference/
│   ├── anti-patterns.md      (the 4 bloat patterns)
│   └── template.md           (~40-line canonical shape)
└── examples/
    ├── audit-before-after.md (500 → 40 lines)
    ├── fresh-compose.md      (new project from scratch)
    └── negative-flip.md      (rule-list transformation)
```

## Inspiration

Based on Kjramsy's Medium post [*"Your CLAUDE.md is eating your token budget (here's how to fix it)"*](https://medium.com/@kjramsy/your-claude-md-is-eating-your-token-budget-heres-how-to-fix-it-b8d6c4d1c986) (Jan 2026). Credit to the author for the recipe-book framing and the 200-line rule.

## License

MIT
