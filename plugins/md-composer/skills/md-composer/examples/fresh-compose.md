# Example: fresh compose for a new project

## Input

User says: *"Write a CLAUDE.md for my new e-commerce API. It's Node/Express + MongoDB, we use Jest for tests, and I want Claude to never touch the payments folder without me approving first."*

## Clarifying questions asked

1. Output style preference — terse or explained?
2. Any personal conventions that belong at user level instead?
3. Anything secret/local that should go in `.local.md`?

## Resulting root `./CLAUDE.md`

```markdown
# Project: Shop API

## What This Is
REST API for our e-commerce storefront. Powers the web and mobile apps; ~5k req/min peak.

## Tech Stack
- Runtime: Node 22, Express 5
- Database: MongoDB via Mongoose
- Testing: Jest, Supertest
- Validation: Zod

## Code Conventions
- Use const/let, triple equals, async/await
- Strict TypeScript (no `any`)
- Zod schemas as the single source of truth for request shapes
- Routes in src/routes/, controllers in src/controllers/, models in src/models/

## Output Preferences
- Explain the plan before editing
- Keep diffs minimal — don't rewrite what doesn't need to change
- Match existing test style

## Boundaries
- Never modify src/payments/ without explicit approval
- Never modify .env, .env.* or ops/secrets/
- Always run: npm run typecheck && npm test before finishing

## Quick Reference
- Entry: src/server.ts
- Routes registered in src/routes/index.ts
- API docs: docs/openapi.yaml
- Deploy runbook: docs/deploy.md
- Incident runbook: docs/incidents.md
```

## Paired `~/.claude/CLAUDE.md` (personal, all projects)

```markdown
# Personal Preferences

## Communication
- Terse; ask before long explanations
- Prefer showing diffs over prose summaries

## Defaults
- pnpm over npm when choice exists
- Conventional commits
- 2-space indent
```

## Paired `./CLAUDE.local.md` (gitignored)

```markdown
# Local Overrides

- Local Mongo: mongodb://localhost:27017/shop_dev
- Stripe test keys are in ~/.config/shop-api/stripe.env — load them via direnv
- Skip the seed-admin script, my local DB already has one
```

## Feature-level split (optional)

Create `src/payments/CLAUDE.md` for stricter per-folder rules — loaded only when Claude touches that subtree:

```markdown
# Payments Module

## Hard Rules
- Every change requires human review before commit
- No silent retries — errors must surface to the caller
- All writes go through the audit logger

## Testing
- Contract tests against Stripe sandbox required for any API-shape change
- Run: npm test -- src/payments
```
