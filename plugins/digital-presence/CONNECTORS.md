# Connectors

## How tool references work

Plugin files use `~~category` as a placeholder for whatever tool the user
connects in that category. Plugins are tool-agnostic — they describe
workflows in terms of categories rather than specific products.

## Connectors for this plugin

| Category | Placeholder | Options |
|----------|-------------|---------|
| Social scheduler | `~~social scheduler` | Buffer, Hootsuite, Later, Sprout Social |
| CMS / Blog | `~~cms` | WordPress, Ghost, Webflow, Notion |
| Analytics | `~~analytics` | Google Analytics, Plausible, Fathom |
| Design tool | `~~design tool` | Canva, Figma, Adobe Express |
| GitHub | `~~github` | GitHub (via GitHub MCP) |
| Browser | `~~browser` | Claude in Chrome, Puppeteer, Playwright |

## Notes

All connectors are **optional**. The plugin works fully without any external tool connections — it generates content as text that users can copy-paste to any platform.

When a connector is available, the plugin can:
- **~~browser**: Visit actual profiles to analyze current activity, scan posts, check engagement (powers the `presence-analyzer` skill). Without this, the plugin falls back to user-provided screenshots and descriptions.
- **~~social scheduler**: Schedule posts directly instead of just generating text
- **~~cms**: Publish blog posts directly to the user's website
- **~~analytics**: Pull performance data to inform content strategy and enhancement recommendations
- **~~design tool**: Create visuals to accompany posts
- **~~github**: Update READMEs and profile directly
