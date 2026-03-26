---
name: x-insights
description: >
  Scrape and analyze X (Twitter) content for insights. Use this skill when the user asks to
  "scrape X", "analyze tweets", "scan my X feed", "get X insights", "what's trending on X",
  "analyze this X community", "research X topics", "find popular posts on X",
  "scan X for trends", "what are people saying about X topic", "community analysis on X",
  or any request to gather and analyze content from X/Twitter.
  Also trigger when the user wants to understand engagement patterns, discover trending topics,
  analyze a specific account's content, or scan X for information on any subject.
---

# X Insights — Scrape & Analyze X (Twitter) Content

Scrape X (Twitter) using Apify and analyze the results to extract actionable insights about communities, trends, engagement patterns, and content performance.

## Requirements

- **Apify MCP** must be connected (the `apify` MCP with `call-actor` and `get-actor-output` tools)
- The recommended Apify Actor is `apidojo/tweet-scraper` (Tweet Scraper V2)

## Workflow

### Step 1: Clarify the Scraping Goal

Before scraping, determine what the user wants to learn. Common use cases:

- **Community analysis**: Understand what a specific X community talks about, their tone, popular topics
- **Trend discovery**: Find what's trending around specific keywords, hashtags, or topics
- **Account analysis**: Analyze a specific account's content, engagement, and posting patterns
- **Topic research**: Gather posts about a specific subject to understand the conversation
- **Feed scanning**: Broad scan of a topic area for general intelligence and interesting content
- **Engagement analysis**: Understand what types of posts get the most engagement in a niche

Ask the user to specify: keywords/hashtags to search, specific accounts to analyze, time range, and how many posts to gather.

### Step 2: Scrape X Using Apify

Use the `apidojo/tweet-scraper` Actor with appropriate input configuration.

**For keyword/hashtag search:**
```json
{
  "searchTerms": ["keyword1", "#hashtag1"],
  "maxItems": 100,
  "sort": "Top"
}
```

**For profile scraping:**
```json
{
  "twitterHandles": ["handle1", "handle2"],
  "maxItems": 50
}
```

**For URL-based scraping:**
```json
{
  "startUrls": ["https://x.com/..."],
  "maxItems": 50
}
```

Run the Actor using `call-actor` with Actor name `apidojo/tweet-scraper`, then retrieve results with `get-actor-output`.

### Step 3: Analyze the Results

Once data is retrieved, perform the analysis the user requested. Structure the analysis around these dimensions as relevant:

**Content Analysis:**
- What topics/themes appear most frequently?
- What questions are people asking?
- What problems or pain points are mentioned?
- What solutions or tools are being discussed?

**Tone & Voice Analysis:**
- What's the overall tone? (technical, casual, enthusiastic, skeptical, etc.)
- How do people communicate in this community? (short takes, long threads, questions, declarations)
- What language patterns are common? (jargon, abbreviations, emojis)
- What's the balance between sharing vs. asking vs. commenting?

**Engagement Patterns:**
- Which posts get the most likes, retweets, and replies?
- What post formats perform best? (text only, with images, threads, polls)
- What times/days seem to have higher engagement?
- What makes a post resonate in this community?

**Trend Identification:**
- What topics are gaining momentum?
- Are there emerging conversations or debates?
- What recent events or launches are driving discussion?
- What topics are declining in interest?

**Key Accounts & Voices:**
- Who are the most active participants?
- Who gets the most engagement?
- Are there clear thought leaders or influencers?
- What accounts does the community engage with most?

### Step 4: Present Insights

Present findings in a clear, organized format. Tailor the depth to the user's request:

- **Quick scan**: 3-5 bullet point summary of key takeaways
- **Standard analysis**: Structured report covering the most relevant dimensions above
- **Deep dive**: Comprehensive analysis with specific examples, quotes (attributed), and data points

Always include:
1. A summary of what was scraped (search terms, accounts, number of posts, time range)
2. The key insights relevant to the user's goal
3. Actionable recommendations based on the findings

### Adjusting Scrape Parameters

If the initial results are insufficient:
- Increase `maxItems` for broader coverage
- Change `sort` from "Top" to "Latest" for recency, or vice versa for quality
- Adjust search terms to be more specific or broader
- Add or remove accounts from the scrape list

## Tips for Better Results

- Scraping 50-200 posts is usually sufficient for community analysis
- Use "Top" sort for engagement analysis, "Latest" for trend discovery
- Combine keyword searches with account-specific scraping for richer context
- For niche communities, scraping key accounts is often more valuable than keyword search
- When analyzing tone, look at replies and quote tweets, not just original posts
