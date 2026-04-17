# Notion Spec-to-Implementation — Claude Plugin

Turns product or tech specs into concrete Notion tasks that Claude Code can implement. Breaks down spec pages into detailed implementation plans with clear tasks, acceptance criteria, and progress tracking.

## What it does

- Finds and fetches the spec page
- Parses requirements and edge cases
- Creates a structured implementation plan
- Creates individual tasks in your Notion tasks database
- Tracks progress as implementation proceeds

## Origin & credits

Official **Anthropic skill** from Claude's Notion team, re-packaged as a plugin.

- Announcement: [Claude on LinkedIn — "Claude skills in Notion"](https://www.linkedin.com/posts/claude_claude-skills-in-notion-activity-7392288254068420608-atoy)
- Source: [notiondevs.notion.site/notion-skills-for-claude](https://notiondevs.notion.site/notion-skills-for-claude)

Skill content is © Anthropic, re-published unmodified.

## Installation

**Claude Code:**
```bash
/plugin marketplace add MSApps-Mobile/claude-plugins
/plugin install notion-spec-to-implementation@msapps-plugins
```

**Cowork:** Settings → Plugins → Marketplaces → Add `MSApps-Mobile/claude-plugins` → Install.

## Requirements

- Notion connector
- A tasks database in Notion (skill will help locate it)

## Triggers

- "Implement the spec for X"
- "Break this PRD into tasks in Notion"
- "Turn this spec into an implementation plan"

## Files

- `skills/notion-spec-to-implementation/SKILL.md`
- `skills/notion-spec-to-implementation/reference/` — implementation plan templates, spec parsing, task creation, progress tracking
- `skills/notion-spec-to-implementation/examples/` — API feature, database migration, UI component
- `evaluations/` — skill evals

## License

MIT (packaging). Skill content © Anthropic.
