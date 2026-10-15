# LinkedIn Scraper Plugin

Scrape LinkedIn profiles and company pages using Apify actors.

## Skills

| Skill | Description |
|-------|-------------|
| scrape-profile | Extract data from a single LinkedIn profile |
| scrape-company | Extract data from a LinkedIn company page |
| bulk-scrape | Batch scrape multiple profiles or companies |

## Setup

1. Sign up for an Apify account
2. 2. Get your API token from the Apify console
   3. 3. Set the APIFY_TOKEN environment variable
     
      4. ## License
     
      5. MIT

## Usage

```
/linkedin-scraper:scrape-profile <LinkedIn profile URL>

# Examples:
/linkedin-scraper:scrape-profile https://www.linkedin.com/in/example

/linkedin-scraper:scrape-company <LinkedIn company page URL>

# Examples:
/linkedin-scraper:scrape-company https://www.linkedin.com/company/example

/linkedin-scraper:bulk-scrape <list of LinkedIn URLs>

# Examples:
/linkedin-scraper:bulk-scrape https://www.linkedin.com/in/a https://www.linkedin.com/in/b
/linkedin-scraper:bulk-scrape https://www.linkedin.com/company/x https://www.linkedin.com/company/y
```
