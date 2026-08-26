# Apify Scraper

Full-featured Apify web scraping platform integration via MCP server. Manage Actors (pre-built scrapers), run scraping jobs, monitor execution, and work with structured datasets.

## Available Tools/Skills

**Actors (5 tools)**
- `apify_list_actors` - Browse account Actors
- `apify_get_actor` - Inspect Actor details and example input
- `apify_run_actor` - Start an asynchronous Actor run
- `apify_run_actor_sync` - Run a small Actor job synchronously
- `apify_build_actor` - Build an Actor version

**Runs (6 tools)**
- `apify_list_runs` - List Actor runs
- `apify_get_run` - Inspect one run
- `apify_get_last_run` - Inspect the latest Actor run
- `apify_abort_run` - Stop a running job
- `apify_resurrect_run` - Continue a finished run
- `apify_get_run_log` - Read run logs

**Storage and automation (16 tools)**
- 4 dataset tools
- 5 key-value store tools
- 5 schedule and webhook tools
- 2 saved-task tools

## Configuration

- **Required**: `APIFY_API_TOKEN` environment variable
- **Server**: `npx tsx` (Node.js MCP server)
- **Rate limits**: Respects Apify API quotas per account tier

## Common Workflows

1. **Find & Run an Actor**
   - Browse Actors with `apify_list_actors`
   - Inspect one with `apify_get_actor`
   - Verify its current schema and pricing
   - Get explicit approval for the bounded input
   - Execute it with `apify_run_actor`
   - Monitor it with `apify_get_run`
   - Read results with `apify_get_dataset_items`

2. **Scrape Multiple Pages**
   - Use Actors designed for pagination (most have `maxResults` or `maxPages`)
   - Alternatively, chain multiple Actor runs with different parameters
   - Combine results from multiple datasets

3. **Extract Specific Fields**
   - Use `apify_get_dataset_items` with `fields`
   - Example: `fields="url,title,price"` from e-commerce Actor

4. **Research X**
   - Use `xquik/x-tweet-scraper` for posts and conversations
   - Use `xquik/x-follower-scraper` for audiences and overlap
   - Follow `skills/apify-scraping/references/xquik-x-research.md`

## Best Practices

- **Check Actor first** - Inspect it with `apify_get_actor`
- **Use datasets for structured data** - More efficient than parsing HTML from output
- **Monitor long runs** - Set reasonable timeouts or check with `apify_get_run`
- **Respect rate limits** - Stagger requests if scraping multiple sites
- **Start small** - Use a small approved cap before proposing a larger run
- **Store datasetIds** - Save them for later reference or reprocessing
- **Require approval** - Show live pricing and a finite result cap before every Actor run

## Independence

Xquik is an independent third-party service. Not affiliated with X Corp.
"Twitter" and "X" are trademarks of X Corp.
