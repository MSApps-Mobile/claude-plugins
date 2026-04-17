# Notion Memory — Claude Plugin by MSApps

Give Claude long-term memory across sessions using your Notion workspace — **plus the 4 official Anthropic Notion skills** bundled in the same plugin.

## Bundled skills

| Skill | What it does | Author |
|-------|-------------|--------|
| `notion-memory` | Long-term memory across sessions — profile, projects, decisions, session archive, quick facts | MSApps |
| `notion-knowledge-capture` | Turns conversations into structured Notion docs — decisions, how-tos, FAQs, learnings | **Anthropic** |
| `notion-meeting-intelligence` | Prep for meetings — internal pre-read + external agenda, all saved to Notion | **Anthropic** |
| `notion-research-documentation` | Searches your workspace, synthesizes findings, produces research reports with citations | **Anthropic** |
| `notion-spec-to-implementation` | Turns specs into Notion tasks Claude Code can implement — plan, track, ship | **Anthropic** |

The four Anthropic skills were announced by Claude on [LinkedIn](https://www.linkedin.com/posts/claude_claude-skills-in-notion-activity-7392288254068420608-atoy) and originally distributed at [notiondevs.notion.site/notion-skills-for-claude](https://notiondevs.notion.site/notion-skills-for-claude). They're re-published here unmodified — skill content © Anthropic.

## Memory skill — what it does

- **Remembers** preferences, tools, communication style
- **Tracks** decisions with reasoning and dates
- **Archives** session summaries for seamless handoffs
- **Stores** quick facts and project context
- **Forgets** on command — you're always in control

Memory lives in a "Claude Memory" page in your Notion workspace, organized into Profile, Projects, Decisions Log, Session Archive, and Quick Facts.

## Installation

**Claude Code (CLI):**
```bash
/plugin marketplace add MSApps-Mobile/claude-plugins
/plugin install notion-memory@msapps-plugins
```

**Cowork:** Settings → Plugins → Marketplaces → Add `MSApps-Mobile/claude-plugins` → Install.

Installing the plugin enables **all 5 skills** at once.

## Requirements

- Notion connector (Claude Code MCP or Cowork Settings)

## Triggers per skill

- **notion-memory:** "Remember I prefer dark mode", "What do you know about project X?", "Save what we did today"
- **notion-knowledge-capture:** "Save this decision to our wiki", "Capture this Q&A as an FAQ"
- **notion-meeting-intelligence:** "Prep me for my meeting with X tomorrow", "Build an agenda for sprint review"
- **notion-research-documentation:** "Research X across our Notion and write it up", "Give me a quick brief on Y"
- **notion-spec-to-implementation:** "Implement the spec for X", "Break this PRD into tasks in Notion"

## Structure

```
plugins/notion-memory/
├── .claude-plugin/plugin.json
├── README.md
├── CLAUDE.md
├── skills/
│   ├── notion-memory/SKILL.md
│   ├── notion-knowledge-capture/       (Anthropic — SKILL.md + reference/ + examples/)
│   ├── notion-meeting-intelligence/    (Anthropic — SKILL.md + reference/ + examples/)
│   ├── notion-research-documentation/  (Anthropic — SKILL.md + reference/ + examples/)
│   └── notion-spec-to-implementation/  (Anthropic — SKILL.md + reference/ + examples/)
└── evaluations/
    ├── notion-knowledge-capture/
    ├── notion-meeting-intelligence/
    ├── notion-research-documentation/
    └── notion-spec-to-implementation/
```

## License

MIT for the plugin packaging and the `notion-memory` skill. The 4 bundled Anthropic skills (SKILL.md, reference/, examples/, evaluations/) are © Anthropic.
