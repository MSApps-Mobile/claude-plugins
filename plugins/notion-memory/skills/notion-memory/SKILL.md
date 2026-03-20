# Notion Memory — Long-Term Memory for Claude Cowork & Claude Code

You are Claude running in Cowork mode or Claude Code. This skill gives you **persistent long-term
memory** by storing and retrieving context from the user's Notion workspace. Use it to remember
facts, decisions, preferences, and project state across sessions.

This works in both environments:
- **Cowork**: Connect Notion via Settings → Connectors → Notion
- **Claude Code**: Add a Notion MCP server to your Claude Code config (`.mcp.json` or settings)

## Prerequisites

- The user must have **Notion MCP tools** available (connected via Cowork or configured in Claude Code)
- If Notion tools are not available, tell the user how to connect based on their environment:
  - Cowork: "Connect Notion via Settings → Connectors → Notion"
  - Claude Code: "Add a Notion MCP server to your `.mcp.json` config"

## Memory Architecture

All memory lives in a single Notion page called **"Claude Memory"** in the user's workspace.
Under that page, you create child pages organized by category:

```
Claude Memory (root page)
├── Profile          — User preferences, name, role, communication style, recurring instructions
├── Projects         — One sub-page per active project with goals, status, decisions, context
├── Decisions Log    — Key decisions made across sessions with date and reasoning
├── Session Archive  — Summaries of past sessions (most recent first)
└── Quick Facts      — Short key-value facts the user has told you to remember
```

## Core Workflows

### 1. Initialize Memory (First Time Setup)

When the user first asks you to remember something or says "set up memory", and no "Claude Memory"
page exists yet:

1. Use `notion-search` to look for a page titled "Claude Memory"
2. If not found, use `notion-create-pages` to create the root page "Claude Memory"
3. Create the five child pages listed above under the root page
4. Confirm to the user: "I've set up your memory space in Notion. I'll use it to remember
   things across our sessions."

### 2. Remember Something (Saving Context)

When the user says "remember this", "save this", "note that", or shares a fact/preference/decision:

1. Determine the right category:
   - Personal preferences, work style, tools → **Profile**
   - Project-specific info → **Projects** (find or create the project sub-page)
   - A decision with reasoning → **Decisions Log**
   - A standalone fact → **Quick Facts**
2. Use `notion-search` to find the appropriate category page
3. Use `notion-update-page` or `notion-create-pages` to append the new information
4. Format entries clearly:
   - **Quick Facts**: `**[Topic]**: [Value]` (one per line)
   - **Decisions Log**: `### [Date] — [Decision Title]\n[Context and reasoning]`
   - **Profile**: Grouped by theme (Communication, Tools, Preferences, etc.)
   - **Projects**: Each project page has sections: Goal, Status, Key Decisions, Open Questions, Notes

### 3. Recall Context (Loading Memory)

At the **start of any new session**, or when the user asks "what do you remember about X":

1. Use `notion-search` for "Claude Memory" to find the root page
2. Use `notion-fetch` to read the relevant category pages
3. Load context silently at session start — don't dump everything on the user, just use it
   to inform your responses
4. When explicitly asked, summarize what you remember in a conversational way

**Important**: Don't read ALL pages every time. Be selective:
- Always load **Profile** (it's small and always relevant)
- Load **Quick Facts** (also small)
- Load specific **Project** pages only when the conversation topic matches
- Load **Session Archive** only if the user references a past session
- Load **Decisions Log** only when a related decision comes up

### 4. End-of-Session Save

When a session is wrapping up, or the user says "save session", "update memory", or "remember
what we did":

1. Summarize the session: what was discussed, what was decided, what was created
2. Save a session summary to **Session Archive** with the date
3. Update any **Project** pages that were worked on
4. Add any new **Decisions** to the log
5. Update **Profile** if new preferences were expressed
6. Confirm: "I've saved this session to memory. Next time we chat, I'll remember where we
   left off."

### 5. Forget Something

When the user says "forget X", "delete X from memory", or "remove X":

1. Search for the relevant content in Notion
2. Remove or clear the specific entry
3. Confirm what was removed

## Automatic Memory Triggers

Watch for these patterns and proactively save to memory:

| User says... | Action |
|-------------|--------|
| "I prefer...", "I always...", "I like..." | Save to **Profile** |
| "Let's go with...", "The decision is..." | Save to **Decisions Log** |
| "Remember that...", "Note that...", "FYI..." | Save to **Quick Facts** |
| "We're working on [project]..." | Create/update **Projects** page |
| "I'm [name/role]..." | Save to **Profile** |

## Formatting Guidelines

When writing to Notion:

- Use Markdown formatting (Notion renders it well)
- Always include dates on time-sensitive entries: `[2026-03-20]`
- Keep entries concise — this is reference material, not prose
- Use headers (`###`) to separate entries within a category page
- Most recent entries go at the TOP of each page (reverse chronological)

## Privacy & Transparency

- Only save information the user has shared in conversation
- Never save sensitive data (passwords, API keys, tokens) to memory
- When in doubt about whether to save something, ask the user
- The user can always say "show me my memory" to see everything stored
- All memory is in the user's own Notion workspace — they have full control

## Error Handling

- If Notion tools are unavailable: inform the user and suggest connecting Notion
- If a page can't be found: recreate the missing category page under the root
- If write fails: retry once, then tell the user and suggest checking Notion permissions
- If the memory page structure looks corrupted: offer to rebuild it

## Example Interactions

**User**: "Remember that I prefer dark mode in all my apps and I use Vim keybindings"
**Claude**: *Saves to Profile page* "Got it — I'll remember your dark mode and Vim preferences."

**User**: "What do you know about me?"
**Claude**: *Fetches Profile and Quick Facts* "From our past sessions, I know you prefer dark
mode and Vim keybindings, you work at [company] as a [role], and you like concise responses
without too much hand-holding."

**User**: "Save what we did today"
**Claude**: *Creates session summary* "Saved — today we built the Notion Memory plugin,
packaged it, and listed it on the MSApps marketplace."
