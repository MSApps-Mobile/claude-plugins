# CLAUDE.md Template (~40 lines)

Copy, fill in, keep it scannable. Every line should earn its token cost.

```markdown
# Project: <Name>

## What This Is
<2-3 sentences. What does this codebase do? Who uses it?>

## Tech Stack
- Framework: <e.g. React 19, TypeScript>
- Database: <e.g. PostgreSQL via Prisma>
- Testing: <e.g. Vitest, Testing Library>

## Code Conventions
- Use <pattern> for <situation>
- Prefer <approach> over <alternative>
- Files organized as: <brief structure>

## Output Preferences
- Explain changes before making them
- Keep code blocks focused (<50 lines)
- TypeScript strict mode

## Boundaries
- Never modify: .env, migrations/, generated/
- Always run: npm run typecheck before finishing

## Quick Reference
- Main entry: src/index.ts
- Tests live next to source files
- API docs: docs/api.md
- Deploy: see docs/deploy.md or run /deploy
```

## Section-by-section rationale

| Section | Purpose | What NOT to do |
|---------|---------|----------------|
| What This Is | Orient Claude on first load | Don't paste the README |
| Tech Stack | Choose idiomatic patterns per library | Don't list every npm dep |
| Code Conventions | Positive-form house rules | Don't list what to avoid |
| Output Preferences | Communication style | Don't repeat Anthropic's defaults |
| Boundaries | Hard do-not-touch list | Don't make it a wishlist |
| Quick Reference | Pointers, not content | Don't inline the docs |

## User-level template (`~/.claude/CLAUDE.md`)

Put personal preferences that follow you across all projects:

```markdown
# Personal Preferences

## Communication
- Terse answers unless I ask "explain"
- No pleasantries, get to the work
- Hebrew is fine; English is fine

## Code Style Defaults
- 2-space indent
- Single quotes in JS/TS
- Commit messages: conventional commits

## Default Stack Preferences
- TypeScript over JavaScript
- Vitest over Jest
- pnpm over npm
```

## Local template (`./CLAUDE.local.md`, gitignored)

Project-specific private info that shouldn't be committed:

```markdown
# Local Overrides

## Local Dev
- DB: postgres://localhost:5432/myapp_dev
- API running on :3001

## Personal Notes
- Feature-flag X is broken on my branch — ignore it
- Skip seed step; my DB is pre-loaded
```
