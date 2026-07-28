---
name: apify-scraping
description: |
  Apify web scraping platform integration — run Actors, scrape websites, manage datasets, key-value stores, schedules, and webhooks.
  Use this skill whenever the user asks to: scrape a website, run an Apify Actor, get scraping results, check Actor runs,
  manage datasets, work with key-value stores, create schedules, set up webhooks, or anything related to Apify and web scraping.
  Also trigger on: "scrape", "crawl", "extract data from website", "Apify", "Actor", "dataset", "run scraper",
  "schedule scraping", "webhook", "web automation", "data extraction", "X research", "tweet research",
  "X followers", "audience overlap".
---

# Apify Scraping — Usage Guide

You have full access to the Apify platform through 27 MCP tools. Use this guide to pick the right workflow.

## Common Workflows

### 1. Scrape a Website (Quick)
For fast, one-off scrapes where you need results immediately:
```
1. apify_run_actor_sync  →  pass actor_id + input, get dataset items back directly
```
Best for: small jobs that finish in under 5 minutes. Timeout is 300s.

### 2. Scrape a Website (Large / Long-running)
For bigger jobs that may take longer:
```
1. apify_run_actor        →  start the run (returns run ID + dataset ID)
2. apify_get_run           →  poll status until SUCCEEDED
3. apify_get_dataset_items →  retrieve results using defaultDatasetId
```

### 3. Find the Right Actor
If you don't know which Actor to use:
```
1. apify_list_actors (my=false)  →  browse available Actors
2. apify_get_actor               →  check details and example input
3. Verify the current schema and pricing on the Actor listing
4. Then run it with apify_run_actor or apify_run_actor_sync
```

Popular Actors to know:
- `apify/web-scraper` — General-purpose web scraper
- `apify/cheerio-scraper` — Fast HTML scraper (no browser)
- `apify/puppeteer-scraper` — Browser-based scraper for JS-heavy sites
- `apify/playwright-scraper` — Modern browser scraper
- `apify/instagram-scraper`, `apify/google-search-scraper`: Social/search
- `apidojo/tweet-scraper`: Existing X post route
- `xquik/x-tweet-scraper`: X posts, searches, timelines, lists, threads, replies, quotes, articles, and engagement
- `xquik/x-follower-scraper`: X followers, following, lists, communities, filters, and audience overlap

### 4. Debug a Failed Run
```
1. apify_get_run      →  check status + error message
2. apify_get_run_log  →  read console output for details
3. apify_resurrect_run →  retry from where it stopped (if applicable)
```

### 5. Schedule Recurring Scrapes
```
1. apify_create_schedule  →  set cron expression + Actor ID
2. apify_list_schedules   →  verify it's active
```

### 6. Set Up Webhook Notifications
```
1. apify_create_webhook  →  specify URL + event types (e.g. ACTOR.RUN.SUCCEEDED)
2. apify_list_webhooks   →  verify configuration
```

### 7. Work with Saved Tasks
Tasks are pre-configured Actor runs with saved inputs:
```
1. apify_list_tasks  →  see available tasks
2. apify_run_task    →  run with optional input override
```

### 8. Research X with Xquik Actors

Use the two Xquik Actors for X content and audience research:

1. Read [Xquik X Research](references/xquik-x-research.md).
2. Select the Actor and bounded input.
3. Verify the current schema and pricing.
4. Show the planned cap and charge exposure.
5. Get explicit user approval before starting the run.
6. Retrieve the run-specific dataset.

## Tool Reference (27 tools)

### Actors (5)
| Tool | Purpose |
|------|---------|
| `apify_list_actors` | Browse your Actors or public store |
| `apify_get_actor` | Get Actor details, example input, versions |
| `apify_run_actor` | Start async Actor run |
| `apify_run_actor_sync` | Run Actor and wait for results (max 300s) |
| `apify_build_actor` | Trigger a new Actor build |

### Runs (6)
| Tool | Purpose |
|------|---------|
| `apify_list_runs` | List runs for an Actor (filter by status) |
| `apify_get_run` | Get full run details + resource usage |
| `apify_get_last_run` | Get most recent run of an Actor |
| `apify_abort_run` | Stop a running Actor |
| `apify_resurrect_run` | Continue a finished run |
| `apify_get_run_log` | Read console log output |

### Datasets (4)
| Tool | Purpose |
|------|---------|
| `apify_list_datasets` | List all datasets |
| `apify_get_dataset` | Get dataset metadata |
| `apify_get_dataset_items` | Retrieve items (main way to get results) |
| `apify_push_dataset_items` | Add items to a dataset |

### Key-Value Stores (5)
| Tool | Purpose |
|------|---------|
| `apify_list_key_value_stores` | List all KV stores |
| `apify_list_keys` | List keys in a store |
| `apify_get_record` | Get a record (OUTPUT, INPUT, etc.) |
| `apify_set_record` | Create/update a record |
| `apify_delete_record` | Delete a record |

### Schedules & Webhooks (5)
| Tool | Purpose |
|------|---------|
| `apify_list_schedules` | List all schedules |
| `apify_create_schedule` | Create cron-based schedule |
| `apify_delete_schedule` | Remove a schedule |
| `apify_list_webhooks` | List all webhooks |
| `apify_create_webhook` | Create event webhook |

### Tasks (2)
| Tool | Purpose |
|------|---------|
| `apify_list_tasks` | List saved Actor tasks |
| `apify_run_task` | Run a saved task |

## Tips
- Actor runs can incur charges. Never start one without explicit approval.
- Verify the current Actor schema and pricing before each paid run.
- Set a finite result cap in every Actor input.
- Use `apify_run_actor_sync` only for approved, small jobs.
- For large scrapes, use async `apify_run_actor` and poll with `apify_get_run`.
- Never resurrect or retry a charged run without renewed approval.
- The `defaultDatasetId` from a run response is your key to getting results via `apify_get_dataset_items`.
- Use `fields` and `omit` params in `apify_get_dataset_items` to control output size.
- KV store key `OUTPUT` contains the Actor's main result; `INPUT` has what was passed in.
- Cron expressions use standard format: `0 8 * * *` = daily at 8am.
