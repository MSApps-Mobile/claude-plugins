# X Content Intelligence

Scrape X (Twitter) for insights and generate community-matched content — powered by Apify.

## What it does

This plugin gives Claude two capabilities for working with X (Twitter):

**X Insights** — Scrape and analyze X content to understand communities, trends, engagement patterns, and conversations. Use it to scan feeds, research topics, discover what's trending, or analyze what makes content resonate in a specific niche.

**X Content Generator** — Create posts, threads, replies, and content calendars that match a target community's tone and topics. Works standalone or paired with X Insights for data-driven content creation.

## Use cases

- Analyze a community's tone, topics, and engagement patterns before posting
- Discover trending topics and emerging conversations in any niche
- Generate posts that sound natural to a specific audience
- Build weekly content calendars with varied post types
- Draft thoughtful replies to boost engagement
- Research what people are saying about any topic on X
- Scan feeds for interesting content and patterns

## Requirements

- [Apify MCP connector](https://apify.com/) — used for scraping X via the `apidojo/tweet-scraper` Actor
- An Apify account (free tier available, pay-per-result for scraping)

## Install

```
/plugin install x-content-intelligence@msapps-plugins
```

## Skills

| Skill | Trigger examples |
|-------|-----------------|
| **x-insights** | "analyze this X community", "what's trending on X about AI", "scan X for insights on topic" |
| **x-content-generator** | "write a tweet about...", "create a content calendar for X", "draft a reply to this post" |

## Examples

**Community analysis:**
> "Scrape the top 100 posts about AI agents on X and tell me what topics are trending and what tone resonates"

**Content generation:**
> "Based on those insights, write 5 posts that would fit naturally in that community"

**Content calendar:**
> "Create a 2-week content calendar for posting about developer tools on X, 3 posts per week"

**Feed scanning:**
> "Search X for what people are saying about Claude Code and summarize the key themes"

## License

MIT
