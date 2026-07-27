# X Content Intelligence

Scrape X (Twitter) for insights and generate community-matched content.

## What it does

This plugin gives Claude two capabilities for working with X (Twitter):

**X Insights**: Scrape and analyze X content and public audiences. It uses the
Xquik Apify Actors for posts, conversations, followers, lists, communities,
and overlap. If the user has TweetClaw, it can analyze reviewed exports.

**X Content Generator** — Create posts, threads, replies, and content calendars that match a target community's tone and topics. Works standalone or paired with X Insights for data-driven content creation.

## Use cases

- Analyze a community's tone, topics, and engagement patterns before posting
- Discover trending topics and emerging conversations in any niche
- Generate posts that sound natural to a specific audience
- Build weekly content calendars with varied post types
- Draft thoughtful replies to boost engagement
- Research what people are saying about any topic on X
- Scan feeds for interesting content and patterns
- Compare public follower audiences and community membership

## Requirements

- An Apify MCP connector with Actor and dataset tools
- [Xquik X Tweet Scraper](https://apify.com/xquik/x-tweet-scraper) for content research
- [Xquik X Follower Scraper](https://apify.com/xquik/x-follower-scraper) for audience research
- An Apify account with enough balance for the approved bounded run

The skill checks current schemas and pricing before requesting approval.

Optional source path:
- [TweetClaw](https://github.com/Xquik-dev/tweetclaw) through OpenClaw or MCP can provide reviewed X/Twitter source data for tweet search, reply search, user lookup, follower export, media context, monitors, webhooks, and giveaway evidence.

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

**Audience overlap:**
> "Compare the public followers of two accounts and summarize their overlap"

## License

MIT

## Independence

Xquik is an independent third-party service. Not affiliated with X Corp.
"Twitter" and "X" are trademarks of X Corp.
