# Toggl Time Tracker

Track time and pull reports from Toggl Track directly from Claude. Start timers, log hours retroactively, and generate weekly summaries by project.

## Available Tools/Skills

- **Start Timer**: Begin tracking time for a task or project
- **Stop Timer**: End the current timer
- **Show Current Timer**: Display what's actively being tracked
- **Log Hours**: Record time entries for past dates
- **Weekly Summaries**: View tracked time grouped by project for the current week
- **List Projects**: Display all active projects in your workspace

## Configuration

Before using this plugin:

1. Get your API token from https://track.toggl.com/profile
2. Find your workspace ID in the Toggl Track URL (typically shown in dashboard)
3. Create `~/.toggl-config.json` with:
   ```json
   {
     "apiToken": "your-token-here",
     "workspaceId": "your-workspace-id"
   }
   ```

## Common Workflows

- **"Start timer for client meeting"** - Begins tracking with description
- **"Stop timer"** - Ends current tracking session
- **"What am I tracking?"** - Shows active timer details
- **"Log 2 hours for code review yesterday"** - Records retroactive entry
- **"Show my time this week"** - Weekly summary by project
- **"List active projects"** - View all available projects

## Best Practices

- Start timers with descriptive names for better reporting
- Log hours immediately after completing untracked work to maintain accuracy
- Review weekly summaries to identify time allocation patterns
- Use project grouping to understand where time is spent across clients/tasks
- Works seamlessly in Claude Code and Cowork environments
