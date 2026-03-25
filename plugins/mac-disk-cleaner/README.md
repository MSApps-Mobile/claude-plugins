# Mac Disk Cleaner

Free up disk space on your Mac by clearing caches, finding large files, and getting smart storage recommendations — all from a simple conversation with Claude.

Works in any language.

## What it does

**Mac Cleanup** — clears known-safe cache locations (Chrome, npm, pip, Swift, Homebrew, Gradle, Yarn) and reports exactly how much space was freed. Also flags any oversized folders on your Desktop or Downloads.

**Disk Explorer** — analyzes your disk and tells you where your space is going, with prioritized recommendations: what's safe to delete, what's worth reviewing, and what's developer bloat.

## How to use

Just ask Claude naturally:

- "Clean up my Mac"
- "What's taking up space on my disk?"
- "Free up some space"
- "Why is my Mac full?"
- "Show me large files"

Or in any language — Hebrew, French, Spanish, German, etc.

## What's safe

The cleanup only touches auto-regenerated caches. It **never** touches:

- Chrome passwords, bookmarks, or history
- Your documents, photos, or personal files
- Mail data or iCloud sync folders
- System files

## Scheduling

To run the cleanup automatically every week, ask Claude:
"Set up a weekly Mac cleanup for me"

## Installation

**Claude Code (CLI):**
```bash
/plugin marketplace add MSApps-Mobile/claude-plugins
/plugin install mac-disk-cleaner@msapps-plugins
```

**Cowork:** Search for "mac-disk-cleaner" in Settings → Plugins, or install from the [MSApps marketplace](https://github.com/MSApps-Mobile/claude-plugins).

## Requirements

- macOS (tested on macOS Ventura and later)
- One of the following:
  - **Claude Code** (CLI) — uses native Bash tool to run cleanup commands
  - **Claude Cowork** with Desktop Commander

## Author

Built by [MSApps](https://msapps.mobi)
