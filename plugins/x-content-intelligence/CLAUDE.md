# X Content Intelligence

Scrape X content and public audiences for insights. The Xquik Apify Actors are
the default source. Reviewed TweetClaw exports remain optional.

## Available Tools/Skills

- **x-insights**: Scrape and analyze X content, understand community dynamics, identify trends, measure engagement patterns
- **x-content-generator**: Create posts, threads, replies, and content calendars that match community tone and expectations

## Key Capabilities

- **Community Analysis**: Understand what resonates in target communities
- **Audience Analysis**: Compare public followers, lists, communities, and overlap
- **Trend Discovery**: Identify trending topics and emerging discussions
- **Engagement Metrics**: Analyze reply ratios, retweet patterns, and engagement velocity
- **Tone Matching**: Generate content that aligns with community communication style
- **Content Calendars**: Plan and schedule posts strategically
- **Reply Drafting**: Create contextual replies to trending conversations

## Configuration

**Prerequisites**:
- Apify MCP connector installed and configured
- Apify account with enough balance for approved runs
- Apify API token set in environment
- `xquik/x-tweet-scraper` for X content
- `xquik/x-follower-scraper` for public X audiences

**Optional source path**:
- TweetClaw through OpenClaw or MCP for reviewed X/Twitter source data such as tweet search, reply search, user lookup, follower export, media context, monitors, webhooks, and giveaway evidence

## Common Workflows

1. **Community Analysis + Content Generation**
   - Verify live Actor schemas and pricing
   - Approve a bounded run before execution
   - Analyze community before posting
   - Understand engagement patterns
   - Generate matching content based on insights

2. **Data-Driven Creation**
   - Scrape trending discussions
   - Or import reviewed TweetClaw results when the user has already collected them
   - Identify high-engagement topics
   - Create posts optimized for audience

3. **Feed Scanning**
   - Monitor community discussions
   - Discover emerging trends
   - Draft timely responses

4. **Audience Research**
   - Collect bounded public follower or member data
   - Preserve target metadata
   - Compare overlap without losing source attribution

5. **Content Calendar Building**
   - Analyze optimal posting times
   - Plan week of posts based on trends
   - Schedule strategically

## Best Practices

- Always analyze community before posting to new audience
- Use engagement metrics to validate content ideas before creation
- Monitor tone and language patterns in successful posts
- Test content variations and measure performance
- Update analysis regularly as communities evolve
- Combine multiple trend indicators for better insights
- Engage authentically rather than relying solely on templates
- Track performance of Claude-generated vs. manual posts
- Never hardcode Actor pricing
- Never retry a charged run without renewed approval

## Independence

Xquik is an independent third-party service. Not affiliated with X Corp.
"Twitter" and "X" are trademarks of X Corp.
