# LinkedIn Scraper — Claude Plugin by MSApps

Token-efficient LinkedIn data access. Scrapes profiles, companies, and jobs via structured MCP — 5-10x cheaper than browser-based approaches.

## What it does

- Get full LinkedIn profiles (experience, education, skills, posts)
- Search for people and jobs by keywords and location
- Get company profiles and recent posts
- Falls back to Chrome MCP automatically if scraping fails

## Installation

**Claude Code (CLI):**
```bash
/plugin marketplace add MSApps-Mobile/claude-plugins
/plugin install linkedin-scraper@msapps-plugins
```

**Cowork:** Search for "linkedin-scraper" in Settings → Plugins.

## Setup (one-time)

Requires Python 3.10+ with [uv](https://docs.astral.sh/uv/) installed.

Run this once in your terminal to authenticate with LinkedIn:
```bash
uvx linkedin-scraper-mcp --login
```

A browser window opens — log in to LinkedIn, then close the window. Your session is saved to `~/.linkedin-mcp/profile/` and works automatically from then on.

## Why use this instead of Chrome?

Chrome-based LinkedIn browsing costs ~5,000–15,000 tokens per profile (screenshots, OCR, page reads, navigation). This plugin returns structured data directly — ~500–2,000 tokens per request. Same data, fraction of the cost.

## Credits

Built on [linkedin-mcp-server](https://github.com/stickerdaniel/linkedin-mcp-server) by Daniel Sticker.