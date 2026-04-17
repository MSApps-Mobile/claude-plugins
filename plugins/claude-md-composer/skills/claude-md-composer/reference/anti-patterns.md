# CLAUDE.md Anti-Patterns

Four bloat patterns to hunt during an audit.

## 1. The documentation dump

Symptom: sections titled "API Reference", "Component API", "Data Model" with 100+ lines of tables or specs inlined.

```
## API Documentation
### GET /users
Returns a list of users. Parameters include...
[500 lines]
```

Fix: move to `docs/<topic>.md`, leave a one-line pointer.

```
## API Reference
See docs/api-reference.md. Read it when working with endpoints.
```

Token win: typically 80-95% reduction for the affected section.

## 2. The negative spiral

Symptom: long lists of "Don't …" rules.

```
- Don't use var
- Don't use any
- Don't use == (use ===)
- Don't use console.log
- Don't use function declarations
- Don't mutate props
```

Fix: flip to positive equivalent.

```
- Use const/let, triple equals, arrow functions
- Use strict TypeScript (no `any`)
- Treat props as immutable
- Log via the logger module, not console
```

Token win: ~40-60% reduction, plus Claude gets the *positive* behavior goal instead of a blocklist.

## 3. The kitchen sink (file preloads)

Symptom: `@file:` or similar directives loading specific files on every request.

```
@file:src/components/Button.tsx
@file:src/components/Modal.tsx
@file:src/utils/format.ts
@file:src/utils/validate.ts
... (30+ entries)
```

Fix: delete them. Claude reads files on demand when relevant. Replace with a one-line pointer:

```
## Code Layout
- Components: src/components/
- Utilities: src/utils/
- Tests: next to source files (*.test.ts)
```

Token win: entire section deleted — can save thousands of tokens per session.

## 4. The everything-tutorial

Symptom: step-by-step procedures inlined ("How to add a new route", "How to deploy", "How to run tests").

Fix: each tutorial becomes a Skill (lazy-loaded on trigger) or a slash command (invoked on demand). CLAUDE.md just mentions they exist:

```
## Workflows
- Add a route: trigger the `add-route` skill
- Deploy: `/deploy` slash command
- Run tests: `npm test` (see docs/testing.md for config)
```

Token win: depends on how many tutorials — often the single biggest saving.

## Bonus: Feature-level scoping

Not an anti-pattern per se, but missed opportunity. Put per-folder rules in `./<folder>/CLAUDE.md` — only loads when Claude touches that subtree.

Example split:
- `./CLAUDE.md` — repo-wide identity, stack, global conventions
- `./api/CLAUDE.md` — REST naming, error-shape, auth
- `./frontend/CLAUDE.md` — component conventions, styling, state mgmt

Each subtree pays its own token cost only when relevant.
