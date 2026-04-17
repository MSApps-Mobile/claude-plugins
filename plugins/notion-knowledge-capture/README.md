# Notion Knowledge Capture — Claude Plugin

Transforms conversations and discussions into structured documentation pages in your Notion workspace.

## What it does

- Extracts key insights, decisions, and knowledge from chat context
- Classifies content (concept, how-to, decision record, FAQ, learning, reference)
- Formats with appropriate templates (headings, examples, metadata)
- Saves to the right wiki / database / project page
- Links the new page into hub/index pages so it's discoverable

## Origin & credits

This is an official **Anthropic skill** shared by Claude's Notion team. This plugin is a convenience packaging so it can be installed via the MSApps marketplace.

- Announcement: [Claude on LinkedIn — "Claude skills in Notion"](https://www.linkedin.com/posts/claude_claude-skills-in-notion-activity-7392288254068420608-atoy)
- Source (skill zips + docs): [notiondevs.notion.site/notion-skills-for-claude](https://notiondevs.notion.site/notion-skills-for-claude)

All `SKILL.md`, `reference/`, `examples/`, and `evaluations/` content is © Anthropic — re-published here unmodified, credit to the Notion Devs team.

## Installation

**Claude Code (CLI):**
```bash
/plugin marketplace add MSApps-Mobile/claude-plugins
/plugin install notion-knowledge-capture@msapps-plugins
```

**Cowork:** Settings → Plugins → Marketplaces → Add `MSApps-Mobile/claude-plugins` → Install.

## Requirements

- Notion connector enabled (Claude Code MCP or Cowork Settings)

## Triggers

Say things like:
- "Save this decision to our wiki"
- "Capture this Q&A as an FAQ entry in Notion"
- "Turn this discussion into a how-to guide"

## Files

- `skills/notion-knowledge-capture/SKILL.md` — main skill instructions
- `skills/notion-knowledge-capture/reference/` — database schemas & best practices
- `skills/notion-knowledge-capture/examples/` — worked examples
- `evaluations/` — JSON evals for measuring skill performance

## License

MIT (plugin packaging). Skill content is © Anthropic.
