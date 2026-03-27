# RTL Chat Fixer

Fix jumbled text when mixing RTL languages with English in chat. Ensures clean, readable mixed-direction output.

## Supported Languages

Hebrew, Arabic, Persian, Urdu, Pashto, Sindhi, Kurdish (Sorani), Yiddish, Dhivehi.

## Formatting Rules

When responding in a mix of RTL and English:

1. **One English term per line max** — never stack multiple LTR terms on one line
2. **English at line ends** — place LTR terms at line boundaries for clean rendering
3. **Short paragraphs** — minimize direction-switching confusion
4. **Backtick all code** — wrap code, paths, and technical terms in backticks
5. **No markdown lists in mixed content** — use prose instead; lists get jumbled

## Configuration

None required. Activates automatically when RTL text is detected in the conversation.

## Best Practices

- Break lines before inserting English terms into RTL text
- Use fenced code blocks to isolate longer LTR content
- If a response is mostly English with a few RTL words, standard LTR formatting is fine
- Test each line reads naturally in its dominant direction
