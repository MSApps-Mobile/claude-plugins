# Notion Meeting Intelligence — Claude Plugin

Prepares you for meetings by gathering context from Notion, enriching it with Claude's research, and creating both an internal pre-read and an external agenda.

## What it does

- Searches Notion for related pages and prior meeting notes
- Enriches with Claude's knowledge (industry context, best practices)
- Creates an **internal pre-read** for attendees
- Creates an **external agenda** for the meeting itself
- Links both documents to related projects

## Origin & credits

Official **Anthropic skill** from Claude's Notion team, re-packaged as a plugin.

- Announcement: [Claude on LinkedIn — "Claude skills in Notion"](https://www.linkedin.com/posts/claude_claude-skills-in-notion-activity-7392288254068420608-atoy)
- Source: [notiondevs.notion.site/notion-skills-for-claude](https://notiondevs.notion.site/notion-skills-for-claude)

Skill content is © Anthropic, re-published unmodified.

## Installation

**Claude Code:**
```bash
/plugin marketplace add MSApps-Mobile/claude-plugins
/plugin install notion-meeting-intelligence@msapps-plugins
```

**Cowork:** Settings → Plugins → Marketplaces → Add `MSApps-Mobile/claude-plugins` → Install.

## Requirements

- Notion connector

## Triggers

- "Prep me for my meeting with X tomorrow"
- "Build an agenda for the sprint review"
- "Pull context on the Acme customer call"

## Files

- `skills/notion-meeting-intelligence/SKILL.md`
- `skills/notion-meeting-intelligence/reference/` — templates (decision, retro, sprint, 1:1, brainstorm, status)
- `skills/notion-meeting-intelligence/examples/` — worked examples
- `evaluations/` — skill evals

## License

MIT (packaging). Skill content © Anthropic.
