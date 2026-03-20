---
name: youtube-transcriber
description: >
  Transcribe YouTube videos and playlists by extracting auto-generated captions directly
  from the browser — no API key, no external service, completely free.
  Trigger on: "transcribe this video", "transcribe this playlist", "get the transcript",
  "extract captions", "what does this video say", "תמלל את הסרטון", "תמלל פלייליסט",
  or any request involving extracting text/captions/subtitles from a YouTube video or playlist URL.
  Also trigger when the user pastes a YouTube URL and asks about its content.
---

# YouTube Transcriber

Extract transcripts from YouTube videos and playlists using browser-based caption extraction.
Works with any video that has auto-generated or manual captions — no API key required.

---

## Prerequisites

This skill requires **Claude in Chrome** (browser automation). If the Chrome MCP tools
(`navigate`, `javascript_tool`, `get_page_text`, etc.) are not available, inform the user
that this skill needs the Claude in Chrome extension to work.

---

## Single Video Transcription

### Step 1: Navigate to the video

```
navigate to: https://www.youtube.com/watch?v={VIDEO_ID}
```

Wait for the page to load. If given a short URL (youtu.be/ID) or a URL with extra params,
extract the video ID and use the canonical format above.

### Step 2: Expand the description to reveal the transcript button

Use `javascript_tool` to click "...more" on the description:

```javascript
const expandBtn = document.querySelector('#description-inline-expander #expand')
              || document.querySelector('tp-yt-paper-button#expand');
if (expandBtn) expandBtn.click();
```

Wait 1-2 seconds for the description to expand.

### Step 3: Open the transcript panel

Use `javascript_tool` to find and click the "Show transcript" button:

```javascript
const buttons = document.querySelectorAll('button.yt-spec-button-shape-next');
let clicked = false;
buttons.forEach(b => {
  if (b.innerText.includes('Show transcript') || b.innerText.includes('הצגת תמליל') || b.innerText.includes('להצגת התמליל')) {
    b.click();
    clicked = true;
  }
});
clicked ? 'Transcript panel opened' : 'Show transcript button not found';
```

Wait 2 seconds for the transcript panel to load.

**If the transcript button is not found**, the video may not have captions. Inform the user.

### Step 4: Scroll the transcript panel to load all segments

YouTube lazy-loads transcript segments. Scroll the engagement panel to trigger loading:

```javascript
(() => {
  const panel = document.querySelector(
    'ytd-engagement-panel-section-list-renderer[visibility="ENGAGEMENT_PANEL_VISIBILITY_EXPANDED"]'
  );
  if (!panel) return 'No transcript panel found';

  const scroller = panel.querySelector('#content');
  if (!scroller) return 'No scrollable content found';

  // Scroll to bottom to trigger lazy-load
  scroller.scrollTop = scroller.scrollHeight;
  return 'Scrolled transcript panel';
})();
```

**Important**: Run this scroll snippet 2-3 times with a short pause between each call
to ensure all segments load. For long videos (10+ minutes), scroll more aggressively.

### Step 5: Extract the transcript text

Use `javascript_tool` to extract text from the engagement panel and parse it:

```javascript
(() => {
  const panel = document.querySelector(
    'ytd-engagement-panel-section-list-renderer[visibility="ENGAGEMENT_PANEL_VISIBILITY_EXPANDED"]'
  );
  if (!panel) return 'ERROR: No transcript panel found';

  const raw = panel.innerText;
  const lines = raw.split('\n').map(l => l.trim()).filter(l => l.length > 0);

  const timestampRe = /^(\d{1,2}:)?\d{1,2}:\d{2}$/;
  const hebrewTimeWords = /שני|דקו|שעה/;

  const result = [];
  for (let i = 0; i < lines.length; i++) {
    if (timestampRe.test(lines[i])) {
      const ts = lines[i];
      // Next line might be a Hebrew duration description — skip those
      let text = '';
      if (i + 1 < lines.length && !timestampRe.test(lines[i + 1])) {
        if (hebrewTimeWords.test(lines[i + 1])) {
          // Skip Hebrew time description, get the line after
          if (i + 2 < lines.length && !timestampRe.test(lines[i + 2])) {
            text = lines[i + 2];
            i += 2;
          } else {
            i += 1;
            continue;
          }
        } else {
          text = lines[i + 1];
          i += 1;
        }
      }
      if (text) result.push(ts + ' ' + text);
    }
  }

  return result.length > 0
    ? result.join('\n')
    : 'ERROR: Could not parse transcript lines. Raw line count: ' + lines.length;
})();
```

### Step 6: Get the video title

Use `javascript_tool`:

```javascript
document.querySelector('yt-formatted-string.ytd-watch-metadata')?.innerText || document.title;
```

### Step 7: Format and save

Combine the video title, URL, and transcript into a clean document:

```
# {Video Title}
Video: https://www.youtube.com/watch?v={VIDEO_ID}

{timestamp} {text}
{timestamp} {text}
...
```

Save to the outputs folder as a `.txt` file.

---

## Playlist Transcription

When the user provides a playlist URL:

### Step P1: Extract video IDs from the playlist

Navigate to the playlist URL, then use `javascript_tool`:

```javascript
(() => {
  const links = document.querySelectorAll('a#video-title');
  const videos = [];
  const seen = new Set();
  links.forEach(a => {
    const href = a.href;
    const match = href.match(/[?&]v=([a-zA-Z0-9_-]{11})/);
    if (match && !seen.has(match[1])) {
      seen.add(match[1]);
      videos.push({ id: match[1], title: a.innerText.trim() });
    }
  });
  return JSON.stringify(videos);
})();
```

If the playlist has many videos, scroll down first to load them all:

```javascript
for (let i = 0; i < 10; i++) {
  window.scrollBy(0, 2000);
  await new Promise(r => setTimeout(r, 500));
}
```

### Step P2: Transcribe each video

Loop through each video ID and follow Steps 1-7 from Single Video Transcription.
Store each transcript in a separate variable/file, then compile at the end.

**Important**: Between videos, navigate directly to the next URL — do not rely on
the playlist's auto-play.

### Step P3: Compile all transcripts

Create a compiled file with all transcripts separated by headers:

```
============================================================
Video 1: {Title}
URL: https://www.youtube.com/watch?v={ID}
============================================================

{transcript}

============================================================
Video 2: {Title}
...
```

Save to outputs as `{playlist-name}-transcripts.txt`.

---

## Error Handling

| Problem | Solution |
|---------|----------|
| "Show transcript" button not found | The video may not have captions. Try checking if captions exist via the CC button in the player controls. |
| Transcript panel loads but is empty | Scroll the panel more aggressively (increase scroll iterations to 20+). |
| Hebrew/Arabic time descriptions mixed in | The extraction script filters these out using the `hebrewTimeWords` regex. If new patterns appear, add them. |
| Wrong language detected by YouTube | YouTube sometimes misdetects the language for songs. Note this in the output but still extract whatever text is available. |
| Very short video (<30 seconds) | May not have auto-generated captions. Inform the user and offer to describe the video content instead. |
| `navigate` tool not available | This skill requires Claude in Chrome. Suggest the user install the Chrome extension. |

---

## Tips

- **Quality**: Auto-generated captions vary in quality. Songs and heavily accented speech
  may produce inaccurate text. Always note when transcripts are auto-generated.
- **Languages**: This works with any language that YouTube generates captions for.
  The extraction is language-agnostic.
- **Large playlists**: For playlists with 20+ videos, consider processing in batches
  and saving intermediate results to avoid losing work.
- **Educational use**: After transcription, you can create vocabulary sheets, summaries,
  study guides, or flashcards from the transcript content. Ask the user what they'd
  like to do with the transcripts.
