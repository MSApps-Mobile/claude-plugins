# RTL Chat

Fix jumbled text when mixing RTL languages with English in chat responses. Ensures clean, readable output when Hebrew, Arabic, Persian, and other RTL languages are mixed with LTR content.

## Supported Languages

Hebrew, Arabic, Persian, Urdu, Pashto, Sindhi, Kurdish (Sorani), Yiddish, Dhivehi.

## Formatting Rules

When responding in a mix of RTL and English:

1. **One English term per line max** — never put two English/LTR terms on the same line
2. **English terms go at the end of the line** — place LTR content at line boundaries
3. **Short paragraphs** — keep paragraphs brief to reduce direction-switching confusion
4. **Code in backticks** — always wrap code, file paths, and technical terms in backticks
5. **Avoid markdown lists in mixed content** — lists with mixed directions get jumbled; use prose instead

## Configuration

None required. This skill activates automatically when RTL text is detected.

## Best Practices

- When in doubt, break the line before inserting an English term
- Test readability by checking if each line reads naturally in its dominant direction
- For code blocks, use fenced code blocks (triple backticks) to isolate LTR content
- If a response is mostly English with a few RTL words, standard LTR formatting is fine

## Execution Model
**Plan:** Detect Hebrew/RTL content in user messages.
**Act:** Apply BiDi formatting rules to response text.
**Verify:** Ensure rendered output is readable with minimal LTR/RTL mixing per line.

**Impact Level:** Low (formatting only, no external actions)
**Approval Gates:** None required — read-only text formatting.
