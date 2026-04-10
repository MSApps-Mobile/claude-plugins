---
name: scrape-company
description: Scrape a LinkedIn company page to extract company data including description, size, industry, and recent updates.
---

# Scrape LinkedIn Company Page

Extract company information from a LinkedIn company page using the Apify LinkedIn Company Scraper actor.

## Requirements
- A valid Apify API token (set as APIFY_TOKEN environment variable)
- - A LinkedIn company page URL
 
  - ## Workflow
  - 1. Validate input: Confirm the user has provided a valid LinkedIn company URL
    2. 2. Run the Apify actor: Use the Apify LinkedIn Company Scraper to extract company data
       3. 3. Parse and format: Structure the extracted data into a clean summary
          4. 4. Present results: Display the formatted company data to the user
            
             5. ## Important Notes
             6. - Always confirm with the user before initiating a scrape
                - - Respect rate limits and LinkedIn terms of service
