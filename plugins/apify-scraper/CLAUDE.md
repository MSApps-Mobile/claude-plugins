# Apify Scraper

Full-featured Apify web scraping platform integration via MCP server. Manage Actors (pre-built scrapers), run scraping jobs, monitor execution, and work with structured datasets.

## Available Tools/Skills

**Actors (7 tools)**
- `search-actors` - Search Apify Store by keyword (5-100 results, pagination)
- `fetch-actor-details` - Get documentation, input schema, output schema, pricing for any Actor
- `call-actor` - Execute an Actor with input parameters (async or sync mode)
- `get-actor-run` - Check run status, timestamps, resource IDs

**Runs (5 tools)**
- `get-actor-output` - Retrieve dataset items from run output (pagination, field selection)
- Full run monitoring via run metadata

**Datasets (3 tools)**
- Read structured output data from completed runs
- Filter by fields using dot notation (e.g., `crawl.statusCode`)
- Paginate results (offset/limit)

**Documentation**
- `search-apify-docs` - Search Apify/Crawlee documentation
- `fetch-apify-docs` - Fetch full docs by URL

## Configuration

- **Required**: `APIFY_API_TOKEN` environment variable
- **Server**: `npx tsx` (Node.js MCP server)
- **Rate limits**: Respects Apify API quotas per account tier

## Common Workflows

1. **Find & Run an Actor**
   - Search for Actor type: `search-actors` with keyword (e.g., "Instagram posts")
   - Inspect its input schema: `fetch-actor-details` with actor name
   - Execute: `call-actor` with properly formatted input
   - Monitor run: `get-actor-run` to check status
   - Read results: `get-actor-output` with datasetId

2. **Scrape Multiple Pages**
   - Use Actors designed for pagination (most have `maxResults` or `maxPages`)
   - Alternatively, chain multiple Actor runs with different parameters
   - Combine results from multiple datasets

3. **Extract Specific Fields**
   - Use `get-actor-output` with `fields` parameter (comma-separated)
   - Example: `fields="url,title,price"` from e-commerce Actor

## Best Practices

- **Check Actor exists first** - Always search/fetch-details before calling to verify input schema matches your data
- **Use datasets for structured data** - More efficient than parsing HTML from output
- **Monitor long runs** - Set reasonable timeouts or check periodically with `get-actor-run`
- **Respect rate limits** - Stagger requests if scraping multiple sites
- **Test with small datasets first** - Use `maxResults=5` or similar to verify output format before scaling
- **Store datasetIds** - Save them for later reference or reprocessing
