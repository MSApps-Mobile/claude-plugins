# Example: 500-line audit → 40-line file

## Before (excerpt — 500 lines total, ~2,000 tokens)

```markdown
# My Project

This is the README basically, copy-pasted. Welcome to the project...
[... 50 lines of marketing intro ...]

## Complete API Documentation

### GET /api/users
Returns users. Parameters:
- page (int, optional): page number
- limit (int, optional): page size
- sort (string, optional): field to sort by
- order (string, optional): asc|desc
[... 300 lines of endpoint specs ...]

## File Preloads
@file:src/components/Button.tsx
@file:src/components/Modal.tsx
@file:src/components/Card.tsx
[... 30 preloads ...]

## Rules
- Don't use var
- Don't use any
- Don't use ==
- Don't use console.log
- Don't mutate props
- Don't write untyped functions
[... 40 "Don't" rules ...]

## How to Add a Route
1. Create the file in src/routes/
2. Register it in src/routes/index.ts
3. Add the navigation entry in src/nav.ts
[... 80 lines of tutorial ...]
```

## After (40 lines, ~180 tokens — 90% reduction)

```markdown
# Project: MyApp

## What This Is
SaaS dashboard for fleet tracking. Used internally by 40 ops people.

## Tech Stack
- Framework: React 19 + TypeScript
- Backend: Node 22, Fastify, Prisma + Postgres
- Testing: Vitest + Testing Library

## Code Conventions
- Use const/let, triple equals, arrow functions
- Strict TypeScript (no `any`)
- Treat props as immutable
- Log via src/lib/logger, not console

## Output Preferences
- Explain changes before making them
- Keep code blocks under 50 lines
- Match existing patterns before introducing new ones

## Boundaries
- Never modify: .env, migrations/, prisma/generated/
- Always run: pnpm typecheck && pnpm test before finishing

## Quick Reference
- Entry: src/index.ts
- Routes: src/routes/ (see docs/routing.md)
- API specs: docs/api.md
- New route: trigger the `add-route` skill
- Deploy: /deploy command
```

## Extraction log

Where every removed section went:

| Removed from CLAUDE.md | Moved to |
|------------------------|----------|
| 300-line API specs | `docs/api.md` |
| 30 `@file:` preloads | deleted — Claude reads on demand |
| 80-line "How to Add a Route" | new skill: `add-route` |
| 40 "Don't …" rules | collapsed to 4 positive rules |
| 50-line README intro | compressed to 2 sentences |

## Impact

- **Tokens per session:** 2,000 → 180 (~90% reduction)
- **Daily savings (100 sessions/day):** 182,000 tokens
- **Scannability:** now fits on one screen
