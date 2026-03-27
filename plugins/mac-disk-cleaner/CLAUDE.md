# Mac Disk Cleaner

Free up disk space on macOS by clearing safe caches, finding large files, and providing storage recommendations.

## Available Skills

- **Mac Cleanup** — Clears safe caches: Chrome, npm, pip, Swift, Homebrew, Gradle, Yarn. Never touches passwords, bookmarks, history, documents, photos, mail, or system files.
- **Disk Explorer** — Analyzes disk usage and prioritizes items as safe to delete, worth reviewing, or bloat.

## Configuration

No configuration required. Works out of the box on macOS Ventura+.

Requires Claude Code or Cowork with Desktop Commander MCP.

## Common Workflows

- "Clean up my Mac" → runs Mac Cleanup on all safe cache locations
- "What's taking up space?" → runs Disk Explorer to analyze and prioritize
- "Clear npm and pip caches" → targeted cleanup of specific caches
- "Set up weekly cleanup" → schedule automatic cache clearing

Works with natural language in any language (Hebrew, French, Spanish, etc.).

## Best Practices

- Always show the user what will be deleted and how much space will be freed before proceeding
- Start with safe caches (Phase 1) before suggesting deeper cleanup
- Never delete anything outside the defined safe zones
- Offer to schedule recurring cleanup for users with chronic space issues
- When in doubt, flag items for user review rather than auto-deleting
