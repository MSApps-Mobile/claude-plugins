---
name: linkedin-data
description: >
  Token-efficient LinkedIn data retrieval. Use this skill whenever the user asks to
  "get a LinkedIn profile", "look up someone on LinkedIn", "search LinkedIn for people",
  "find jobs on LinkedIn", "get company info from LinkedIn", "scrape LinkedIn",
  "check someone's LinkedIn", "pull LinkedIn data", or any request involving
  retrieving structured data from LinkedIn profiles, companies, or job postings.
  Also trigger when other skills (like outreach or lead enrichment) need LinkedIn
  profile data as an input step. This skill routes through a structured scraping MCP
  to avoid expensive Chrome screenshot/OCR token usage.
metadata:
  version: "0.1.0"
---

# LinkedIn Data Retrieval
This plugin provides token-efficient access to LinkedIn data through a structured scraping MCP server. It returns clean, structured data — no screenshots, no OCR, no page reads.

## Available Tools

The `linkedin-scraper` MCP server exposes these tools:

| Tool | Purpose | Key Parameters |
|------|---------|---------------|
| `get_person_profile` | Full profile data | `url`, `sections` (experience, education, interests, honors, languages, contact_info, posts) |
| `get_company_profile` | Company information | `url`, `sections` |
| `get_company_posts` | Recent company posts | `url` |
| `search_people` | Find people | `keywords`, `location` |
| `search_jobs` | Find job postings | `keywords`, `location` |
| `get_job_details` | Full job posting info | `url` |
| `close_session` | Clean up browser session | — |

## Routing Rules

**ALWAYS try the linkedin-scraper MCP tools first.** These return structured data at a fraction of the token cost compared to Chrome-based browsing.

### Primary Path (Scraper MCP)

1. Identify which tool matches the user's request
2. Call the appropriate `linkedin-scraper` tool
3. Parse and present the structured response
4. Call `close_session` when done with a batch of requests
### Fallback Path (Chrome MCP)

Only fall back to Chrome MCP (`mcp__Claude_in_Chrome__*`) if:
- The scraper tool returns an error (e.g., page structure changed, rate limit, auth failure)
- The scraper tool returns empty or clearly incomplete data
- The user explicitly asks to use the browser

When falling back:
1. Inform the user: "The scraper couldn't fetch this — switching to browser."
2. Use `mcp__Claude_in_Chrome__navigate` to open the LinkedIn URL
3. Use `mcp__Claude_in_Chrome__get_page_text` or `read_page` to extract data
4. Present the results

### Session Management

- The scraper uses a persistent browser profile at `~/.linkedin-mcp/profile/`
- First-time setup requires running `uvx linkedin-scraper-mcp --login` in a terminal to authenticate with LinkedIn
- If authentication errors occur, tell the user to re-run the login command

## Usage Patterns

### Get a person's profile
```
User: "Pull the LinkedIn profile for https://linkedin.com/in/someone"
→ Call get_person_profile with url and desired sections
```

### Search for people
```
User: "Find CTOs in fintech companies in Dubai"
→ Call search_people with keywords="CTO fintech" location="Dubai"
```
### Get company info
```
User: "Get me info about Microsoft from LinkedIn"
→ Call get_company_profile with the company LinkedIn URL
```

### Enrich a lead
```
Other skill needs LinkedIn data → Call get_person_profile, return structured result
```

## Token Efficiency Notes

- A typical Chrome-based LinkedIn profile fetch: ~5,000-15,000 tokens (screenshots + OCR + page text + navigation steps)
- A scraper MCP profile fetch: ~500-2,000 tokens (structured JSON response)
- That's a **5-10x reduction** per LinkedIn data request