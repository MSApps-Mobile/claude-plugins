# Obsidian Memory

Give Claude long-term memory across sessions using a local Obsidian vault. Remember preferences, track decisions, archive session summaries, and store quick facts.

## Available Skills

- **Remember** — Store preferences, tools, communication style, and project context
- **Recall** — Retrieve stored knowledge about the user, projects, or past decisions
- **Archive** — Save session summaries for seamless handoffs between sessions
- **Forget** — Remove outdated or incorrect information on command

## Memory Structure

All memory lives in the user's Obsidian vault as Markdown files, organized into existing vault folders:

- **Preferences/** — User preferences, communication style, tools, workflow
- **Projects/** — One file per active project with context and status
- **People/** — Key contacts and collaborators
- **Daily/** — Daily notes including session summaries and decisions
- **Claude Memory/** — Claude-specific storage (decisions log, quick facts, session archive)

## How It Works

Unlike the Notion Memory plugin which requires an MCP connector, this plugin operates directly on local Markdown files using Claude's built-in filesystem tools (Read, Write, Edit, Glob, Grep). No external API or connector is needed.

## Configuration

Set the vault path in the skill or detect it automatically. Default: `~/Library/CloudStorage/GoogleDrive-*/My Drive/Obsidian Vault/*/`

## Common Workflows

- "Remember I prefer dark mode" → stores preference in Preferences/
- "What do you know about BPure?" → searches vault for BPure references
- "Save what we did today" → appends to today's Daily note + session archive
- "Forget my old email" → removes outdated fact
- "Log the decision to use React" → adds to Claude Memory/Decisions Log

## Best Practices

- Leverage existing vault structure — don't duplicate what's already there
- Store information immediately when the user shares a preference or makes a decision
- Always check relevant vault files at the start of a session
- Keep Quick Facts concise — one line per fact
- When recalling, search across all vault folders using Grep
- Update rather than duplicate when information changes
- Respect "forget" commands — fully remove the information
- Use Obsidian-compatible Markdown (support `[[wiki-links]]` and YAML frontmatter)
