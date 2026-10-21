# Example: flipping negative rules to positive

## Before (12 rules, ~85 tokens)

```markdown
## Rules
- Don't use var
- Don't use any
- Don't use ==
- Don't use console.log
- Don't mutate props
- Don't write untyped functions
- Don't commit .env files
- Don't skip tests
- Don't use default exports
- Don't use inline styles
- Don't use jQuery
- Don't use moment.js
```

## After (4 rules, ~45 tokens)

```markdown
## Rules
- Use const/let, triple equals, strict TypeScript
- Use named exports; treat props as immutable
- Log via src/lib/logger; test every new function
- Stack: React + Tailwind + date-fns (no jQuery, no moment)
```

## Token win

- **Before:** ~85 tokens
- **After:** ~45 tokens
- **Reduction:** ~47%

## Why it works

Claude responds better to **behavior goals** than **blocklists**. "Use X" tells Claude the target; "Don't use Y" leaves the target unspecified and Claude has to infer it.

## When keeping a "don't" is OK

Two cases where negative phrasing stays:

1. **Hard boundaries** — "Never modify .env" is clearer than "Keep .env intact"
2. **When the positive form needs a list** — e.g. allowed frameworks with forbidden alternatives is best as both ("Use X, Y, Z. Not A, B, C.")

The rule: if you're writing more than 2-3 "Don't …" lines in a row, you're spiraling — flip them.
