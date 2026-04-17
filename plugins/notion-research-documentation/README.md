# Notion Research & Documentation — Claude Plugin

Searches across your Notion workspace, synthesizes findings from multiple pages, and creates comprehensive research documentation as new Notion pages with proper citations.

## What it does

- Broad-then-narrow search across Notion
- Fetches and analyzes relevant pages
- Synthesizes findings across sources
- Produces structured output — research summary, comprehensive report, or quick brief
- Cites sources back to originating pages

## Origin & credits

Official **Anthropic skill** from Claude's Notion team, re-packaged as a plugin.

- Announcement: [Claude on LinkedIn — "Claude skills in Notion"](https://www.linkedin.com/posts/claude_claude-skills-in-notion-activity-7392288254068420608-atoy)
- Source: [notiondevs.notion.site/notion-skills-for-claude](https://notiondevs.notion.site/notion-skills-for-claude)

Skill content is © Anthropic, re-published unmodified.

## Installation

**Claude Code:**
```bash
/plugin marketplace add MSApps-Mobile/claude-plugins
/plugin install notion-research-documentation@msapps-plugins
```

**Cowork:** Settings → Plugins → Marketplaces → Add `MSApps-Mobile/claude-plugins` → Install.

## Requirements

- Notion connector

## Triggers

- "Research X across our Notion and write it up"
- "Pull together a comprehensive report on Y"
- "Give me a quick brief on our competitor analysis"

## Files

- `skills/notion-research-documentation/SKILL.md`
- `skills/notion-research-documentation/reference/` — format guides (summary / report / brief / comparison) + citation styles + advanced search
- `skills/notion-research-documentation/examples/` — market research, technical investigation, competitor analysis
- `evaluations/` — skill evals

## License

MIT (packaging). Skill content © Anthropic.
