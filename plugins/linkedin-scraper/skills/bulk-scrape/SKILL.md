---
name: bulk-scrape
description: Scrape multiple LinkedIn profiles or company pages in batch. Use when the user provides a list of LinkedIn URLs.
---

# Bulk Scrape LinkedIn

Extract data from multiple LinkedIn profiles or company pages in a single batch operation.

## Requirements
- A valid Apify API token (set as APIFY_TOKEN environment variable)
- - A list of LinkedIn URLs (profiles, companies, or mixed)
 
  - ## Workflow
  - 1. Collect URLs from the user
    2. 2. Validate and classify into profile and company URLs
       3. 3. Confirm scope and get user approval
          4. 4. Run batch scrape via Apify actors
             5. 5. Aggregate and present results
