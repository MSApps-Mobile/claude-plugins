# LinkedIn Scraper

Token-efficient LinkedIn data access via direct scraping (5-10x cheaper than browser-based MCP). Get full profiles, search people/jobs, retrieve company profiles and posts.

## Available Tools/Skills

- **Get full profiles** - Retrieve complete LinkedIn profile data (experience, skills, endorsements)
- **Search people** - Find contacts by name/title/company with pagination
- **Search jobs** - Query LinkedIn job postings by keyword/location
- **Get company profiles** - Full company data (industry, size, followers, recent posts)
- **Get posts** - Retrieve LinkedIn posts with engagement metrics
- **Fallback to Chrome MCP** - If scraping fails, automatically uses Chrome MCP (slower but reliable)

## Configuration

- **Required**: Python 3.10+ with `uv` package manager
- **Server**: `uvx linkedin-scraper-mcp` (runs Python MCP server)
- **One-time login**: `uvx linkedin-scraper-mcp --login` (interactive login, saves session)
- **Session storage**: `~/.linkedin-mcp/profile/` (persists across uses)
- **No API key needed** - Uses browser automation under the hood

## Common Workflows

1. **Get Someone's Full Profile**
   - Input: LinkedIn profile URL or name + current company
   - Returns: All experience, education, skills, endorsements, headline
   - Cost: ~50-100 tokens vs 5000-15000 with Chrome MCP

2. **Search for Prospects**
   - Query: job title, company, location (e.g., "VP Sales at Fortune 500 in NYC")
   - Returns: Paginated list with LinkedIn URLs, basic profile preview
   - Cost: ~100-200 tokens per 10 results

3. **Monitor Company/Posts**
   - Get recent posts from company or person
   - Track engagement, comments, shares
   - Perfect for market research or sales intelligence

## Best Practices

- **Cache LinkedIn profiles** - Save profiles locally once fetched; LinkedIn doesn't change hourly
- **Respect rate limits** - Space out requests; LinkedIn can block aggressive scrapers
- **Use Chrome fallback for reliability** - If scraper hits errors, Chrome MCP always works
- **Batch searches efficiently** - Get 50 people in 1 request rather than 50 individual profile lookups
- **Store session** - Login once; session persists for weeks in `~/.linkedin-mcp/profile/`
- **Monitor token usage** - Track costs: direct scraping ~100-500 tokens/request vs Chrome's 5000-15000
