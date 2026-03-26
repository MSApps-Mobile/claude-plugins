---
name: session-context
description: >
  Captures and saves a complete session handoff document so work can be resumed seamlessly in a new Claude session.
  Use this skill whenever Michal says "save context", "document what we did", "save session", "create handoff",
  "I want to continue this tomorrow", "summarize the session", "what did we do today", or any request to
  capture, document, or preserve the current state of work. Also trigger proactively at the end of long
  sessions or whenever many files have been created and a natural stopping point is reached.
  The output is a structured markdown file saved to /Users/michalshatz/Documents/Claude/sessions/ that
  captures everything needed to resume — decisions made, files created, next steps, and a ready-to-paste
  resume prompt.
---

# Session Context Capture Skill

Your job is to produce a complete, self-contained handoff document that lets a *future Claude session with no memory of this conversation* pick up exactly where things left off — confidently, without asking Michal to repeat herself.

## What to capture

Think of yourself as a journalist embedded in this session. You've watched everything happen. Now write the document you wish had existed at the start of this session.

### 1. Session summary
- Date and approximate time range
- One-sentence mission ("What were we trying to accomplish?")
- 3-5 bullet points of what was actually done (not what was planned — what happened)

### 2. All files created or modified
For every file created, modified, or relevant to the work:
```
| File | Location | Purpose | Status |
|------|----------|---------|--------|
| msapps-plugins.html | /Users/.../Documents/Claude/... | Integrations page | ✅ Done |
| gumroad_cover.png   | ~/Desktop/                     | Product cover     | ✅ Done |
```
Include VM paths AND Mac paths where both exist. If a file was created in the VM temp folder but not saved to Mac, note it as "⚠️ Temp only — needs saving".

### 3. Key context (credentials, URLs, IDs)
Capture every specific detail that would be frustrating to rediscover:
- URLs of pages worked on (e.g. Gumroad product edit URL)
- Account usernames used
- Colors, hex codes, design decisions made
- API endpoints or account IDs referenced
- Any passwords or tokens should NOT be captured — just note "auth needed for X"

### 4. Decisions made
The reasoning behind choices, not just the choices themselves. Future Claude needs to know *why* things were done a certain way so it doesn't undo them.

Example: "Changed Gumroad button color to #BACC00 (lime green) — matches MSApps brand. Used React native input value setter via JavaScript because the color picker UI was dismissing on click."

### 5. Open threads and blockers
- Things that weren't finished and why
- Known issues or limitations discovered
- Things Michal said she wanted to do later
- Things waiting on Michal's action (e.g. "Michal needs to manually set payout method")

### 6. Next steps (prioritized)
A numbered list of what should happen in the next session, in order of priority. Be specific — not "finish the page" but "Add the LinkedIn outreach section to msapps-plugins.html with a card for the LinkedIn Outreach Messages plugin."

### 7. Resume prompt
This is the most important part. Write a ready-to-paste prompt that Michal can use to start a new Claude session and get back up to speed instantly. It should:
- Be written in second person to Claude ("You are continuing work on...")
- Reference the handoff document itself ("Read the session notes at [path]")
- Include the top 1-2 immediate next actions so Claude can start without asking questions
- Be 3-5 sentences max — a pointer, not a recap

## Output format

Save the file to: `/Users/michalshatz/Documents/Claude/sessions/YYYY-MM-DD_[short-topic].md`

Use today's date and a 2-3 word slug describing the session topic (e.g. `2026-03-18_gumroad-plugins-page.md`).

Then confirm to Michal: "✅ Session saved to [filename]. Here's your resume prompt:" and show the resume prompt inline in the chat so she can copy it easily.

## Style notes

- Write in clear, direct English (not Hebrew unless quoting something)
- Be specific: file paths, hex codes, exact URLs — not vague references
- Avoid repeating yourself — each section should add new information
- The whole document should be scannable in 2 minutes
- Don't be exhaustive about every message in the conversation — capture *state*, not *history*

## After saving

Offer to also upload the session document to Google Drive (use the google-drive-upload skill if available) so it's backed up and accessible from anywhere.
