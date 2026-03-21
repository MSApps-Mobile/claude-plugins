---
name: backup-setup
description: Configure the Google Drive backup connection
---

Guide the user through setting up the backup:

1. **Check if config exists**: Read `~/.cowork-gdrive-config.json`
2. **If not configured**: Walk the user through:
   - Deploying the Google Apps Script web app
   - Getting the script URL and API key
   - Creating the config file:
     ```json
     {
       "url": "https://script.google.com/macros/s/YOUR_SCRIPT_ID/exec",
       "apiKey": "your-api-key"
     }
     ```
3. **Test the connection**: Upload a small test file to verify it works
4. **Set up scheduling**: Create a Cowork scheduled task for daily runs
