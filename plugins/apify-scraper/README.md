# Apify Scraper Plugin

Full Apify web scraping platform integration for Claude. Run Actors, manage datasets, key-value stores, schedules, webhooks, and tasks — all from within Claude.

## Setup

### 1. Get your Apify API Token
1. Go to [Apify Console](https://console.apify.com/) → Settings → Integrations
2. Copy your API token

### 2. Install the Plugin
Install the `.plugin` file in Claude. When prompted, set the environment variable:

```
APIFY_API_TOKEN=your_token_here
```

## Available Tools (27)

| Category | Tools | Description |
|----------|-------|-------------|
| **Actors** | 5 | List, inspect, run, build Actors |
| **Runs** | 6 | Monitor, abort, resurrect runs, read logs |
| **Datasets** | 4 | List, read, push dataset items |
| **Key-Value Stores** | 5 | CRUD operations on KV store records |
| **Schedules** | 3 | Create/delete cron-based schedules |
| **Webhooks** | 2 | Create webhooks for run events |
| **Tasks** | 2 | List and run saved Actor tasks |

## Quick Examples

**Scrape a website (fast):**
> "Run apify/web-scraper on https://example.com and get the results"

**Schedule a daily scrape:**
> "Create a schedule to run apify/google-search-scraper every day at 8am UTC"

**Check what happened:**
> "Show me the last run of apify/web-scraper and its log"

**Research X content:**
> "Use the Xquik X Tweet Scraper for 50 recent posts about AI agents"

**Compare X audiences:**
> "Use the Xquik X Follower Scraper to compare two follower audiences"

The bundled skill includes bounded recipes for
[Xquik X Tweet Scraper](https://apify.com/xquik/x-tweet-scraper) and
[Xquik X Follower Scraper](https://apify.com/xquik/x-follower-scraper).
It verifies live schemas and pricing before requesting run approval.

## Architecture

```
apify-scraper/
├── .claude-plugin/
│   └── plugin.json          # Plugin manifest
├── .mcp.json                # MCP server configuration
├── servers/apify/
│   ├── package.json         # Dependencies
│   └── src/
│       ├── index.ts         # Entry point
│       ├── constants.ts     # API config
│       ├── types.ts         # TypeScript interfaces
│       ├── schemas/
│       │   └── common.ts    # Shared Zod schemas
│       ├── services/
│       │   └── api-client.ts # Axios HTTP client
│       └── tools/
│           ├── actors.ts            # Actor tools
│           ├── runs.ts              # Run tools
│           ├── datasets.ts          # Dataset tools
│           ├── key-value-stores.ts  # KV store tools
│           └── schedules-webhooks.ts # Schedule, webhook & task tools
├── skills/apify-scraping/
│   ├── SKILL.md             # Usage guidance for Claude
│   └── references/
│       └── xquik-x-research.md # Bounded X research recipes
└── README.md
```

## Tech Stack

- **Runtime**: Node.js with `npx tsx` (no build step)
- **MCP SDK**: `@modelcontextprotocol/sdk` (stdio transport)
- **HTTP**: Axios with Bearer token auth
- **Validation**: Zod schemas
- **API**: Apify REST API v2

## Author

MSApps

## Independence

Xquik is an independent third-party service. Not affiliated with X Corp.
"Twitter" and "X" are trademarks of X Corp.
