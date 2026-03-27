# Notion Memory

Give Claude long-term memory across sessions using a Notion workspace. Remember preferences, track decisions, archive session summaries, and store quick facts.

## Available Skills

- **Remember** — Store preferences, tools, communication style, and project context
- **Recall** — Retrieve stored knowledge about the user, projects, or past decisions
- **Archive** — Save session summaries for seamless handoffs between sessions
- **Forget** — Remove outdated or incorrect information on command

## Memory Structure

All memory lives in a "Claude Memory" Notion page organized into:

- **Profile** — User preferences, communication style, tools
- **Projects** — One page per active project with context and status
- **Decisions Log** — Tracked with reasoning and dates
- **Session Archive** — Summaries for continuity across sessions
- **Quick Facts** — Short key-value facts for fast lookup

## Configuration

Requires the Notion connector (Cowork Settings or Claude Code MCP).

## Common Workflows

- "Remember I prefer dark mode" → stores preference in Profile
- "What do you know about BPure?" → searches all memory sections
- "Save what we did today" → creates session archive entry
- "Forget my old email" → removes outdated fact
- "Log the decision to use React" → adds to Decisions Log with reasoning and date

## Best Practices

- Store information immediately when the user shares a preference or makes a decision
- Always check memory at the start of a session for relevant context
- Keep Quick Facts concise — one line per fact
- When recalling, search across all sections (Profile, Projects, Decisions, Quick Facts)
- Update rather than duplicate when information changes
- Respect "forget" commands — fully remove the information
