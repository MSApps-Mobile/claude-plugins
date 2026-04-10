---
name: scrape-profile
description: Scrape a LinkedIn profile to extract professional data including name, headline, work history, education, and skills.
---

# Scrape LinkedIn Profile

Extract professional data from a LinkedIn profile using the Apify LinkedIn Profile Scraper actor.

## Requirements
- A valid Apify API token (set as APIFY_TOKEN environment variable)
- - A LinkedIn profile URL
 
  - ## Workflow
  - 1. Validate input: Confirm the user has provided a valid LinkedIn profile URL
    2. 2. Run the Apify actor: Use the Apify LinkedIn Profile Scraper to extract profile data
       3. 3. Parse and format: Structure the extracted data into a clean summary
          4. 4. Present results: Display the formatted profile data to the user
            
             5. ## Important Notes
             6. - Always confirm with the user before initiating a scrape
                - - Respect rate limits and LinkedIn terms of service
