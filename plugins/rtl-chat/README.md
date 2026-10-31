# RTL Chat

Keeps Claude's replies readable when you chat in Hebrew.

Chat apps right-align Hebrew text, but when Hebrew and English share a line the word order often comes out scrambled. This plugin teaches Claude to structure its answers so that does not happen: at most one English term per line, lists instead of long mixed sentences, and code and commands kept on their own lines.

## What it does

- Turns on automatically whenever the conversation contains Hebrew.
- Keeps each line to a single English term, so the right-to-left order holds.
- Puts code, file paths and commands in code blocks, away from Hebrew text.
- Uses no invisible Unicode direction marks, which make rendering worse in Claude's apps.

## Works in

Claude Cowork, Claude Desktop and Claude Code.

## Privacy

The plugin only changes how Claude formats its own text. It makes no network calls and stores nothing.

## License

MIT. Made by MSApps, a Certified Claude Partner Network member. More plugins: https://claudeservices.ai/plugins
