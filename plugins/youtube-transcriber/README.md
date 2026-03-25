# YouTube Transcriber — Claude Plugin by MSApps

Transcribe YouTube videos and playlists directly from Claude using browser-based caption extraction. No API key, no external service, completely free.

## What it does

- **Single videos**: Paste a YouTube URL → get a timestamped transcript
- **Full playlists**: Paste a playlist URL → get transcripts for every video
- **Any language**: Works with any language YouTube generates captions for
- **Educational tools**: Use transcripts to create vocabulary sheets, summaries, and study guides

## Installation

**Claude Code (CLI):**
```bash
/plugin marketplace add MSApps-Mobile/claude-plugins
/plugin install youtube-transcriber@msapps-plugins
```

**Cowork:** Search for "youtube-transcriber" in Settings → Plugins.

## Requirements

- **Claude in Chrome** extension (for browser automation) — works in both Cowork and Claude Code
- A YouTube video or playlist with auto-generated or manual captions

## Usage

Just ask Claude naturally:

- "Transcribe this video: https://youtube.com/watch?v=..."
- "Get the transcript of this playlist: https://youtube.com/playlist?list=..."
- "What does this video say?" + paste a YouTube link

Or in any language — Hebrew, French, Spanish, German, etc.

## How it works

The plugin uses Claude's browser automation to:
1. Navigate to the YouTube video
2. Open the transcript panel
3. Extract and clean the caption text
4. Save it as a formatted document

No scraping APIs, no third-party services, no keys to configure.

## License

MIT — Free and open source.

## Author

**MSApps** — [msapps.mobi](https://msapps.mobi) | [michal@msapps.mobi](mailto:michal@msapps.mobi)

GitHub: [MSApps-Mobile](https://github.com/MSApps-Mobile)
