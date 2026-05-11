# Obsidian Memory — Long-Term Memory for Claude Cowork & Claude Code

You are Claude running in Cowork mode or Claude Code. This skill gives you **persistent long-term
memory** by storing and retrieving context from the user's Obsidian vault as local Markdown files.
Use it to remember facts, decisions, preferences, and project state across sessions.

This works in both environments:
- **Cowork**: Ensure the vault directory is accessible from the Cowork filesystem
- **Claude Code**: Works out of the box — uses Read, Write, Edit, Glob, and Grep tools

## Prerequisites

- The user must have an **Obsidian vault** on the local filesystem
- Claude must have filesystem access to the vault directory
- No external API or connector is needed — this is 100% local

## Vault Path

The vault root path must be known. Common locations:

- `~/Library/CloudStorage/GoogleDrive-*/My Drive/Obsidian Vault/*/` (Google Drive sync)
- `~/Documents/Obsidian/*/`
- `~/Obsidian/*/`
- `~/iCloud Drive/Obsidian/*/`

On first use, search for the vault:
1. Use Glob to find `**/Obsidian*/**/.obsidian/` to locate vault roots
2. Store the detected vault path for the session

For this installation, the default vault path is:
```
/Users/boaz/Library/CloudStorage/GoogleDrive-boaz@bizzabo.com/My Drive/Obsidian Vault/Boaz Main/
```

## Memory Architecture

Memory leverages the **existing vault structure** where possible, and adds a dedicated `Claude Memory/`
folder for Claude-specific data:

```
Obsidian Vault Root/
├── Preferences/          — (EXISTING) User preferences, profile, workflow
│   ├── Boaz Profile.md   — Name, role, communication style, tools
│   ├── Workflow.md        — How the user works
│   └── ...
├── Projects/             — (EXISTING) One file per active project
│   ├── ProjectName.md    — Goals, status, decisions, context
│   └── ...
├── People/               — (EXISTING) Key contacts and collaborators
│   ├── PersonName.md     — Role, relationship, notes
│   └── ...
├── Daily/                — (EXISTING) Daily notes
│   ├── 2026-03-31.md     — Today's note with tasks, meetings, journal
│   └── ...
└── Claude Memory/        — (CREATED BY PLUGIN) Claude-specific storage
    ├── Decisions Log.md  — Key decisions with date and reasoning
    ├── Quick Facts.md    — Short key-value facts for fast lookup
    └── Session Archive.md — Past session summaries (newest first)
```

### Key Principle: Reuse Before Create

- **Read** from existing vault folders (Preferences/, Projects/, People/, Daily/)
- **Write** Claude-specific data to `Claude Memory/`
- **Update** existing files when adding to a project or preference the user already has
- Never duplicate information that already exists in the vault

## Core Workflows

### 1. Initialize Memory (First Time Setup)

When the user first asks you to remember something or says "set up memory", and no `Claude Memory/`
folder exists yet:

1. Use Glob to check if `Claude Memory/` folder exists in the vault root
2. If not found, create the folder and its initial files:

```bash
# Create folder
mkdir -p "${VAULT}/Claude Memory"
```

3. Create three initial files:

**Quick Facts.md:**
```markdown
---
title: Quick Facts
tags: [claude-memory]
---

# Quick Facts

Short facts Claude should remember. One line per fact.

<!-- Add facts below this line, newest first -->
```

**Decisions Log.md:**
```markdown
---
title: Decisions Log
tags: [claude-memory]
---

# Decisions Log

Key decisions made across sessions with date and reasoning.

<!-- Add decisions below this line, newest first -->
```

**Session Archive.md:**
```markdown
---
title: Session Archive
tags: [claude-memory]
---

# Session Archive

Summaries of past Claude sessions for continuity.

<!-- Add sessions below this line, newest first -->
```

4. Confirm to the user: "I've set up your Claude Memory folder in Obsidian. I'll use it alongside
   your existing vault to remember things across sessions."

### 2. Remember Something (Saving Context)

When the user says "remember this", "save this", "note that", or shares a fact/preference/decision:

1. Determine the right location:
   - Personal preferences, work style, tools → **Preferences/** (update existing files like `Boaz Profile.md` or `Workflow.md`)
   - Project-specific info → **Projects/** (find or create the project file)
   - Info about a person → **People/** (find or create the person file)
   - A decision with reasoning → **Claude Memory/Decisions Log.md**
   - A standalone fact → **Claude Memory/Quick Facts.md**

2. Use Grep to search the vault for existing content to avoid duplication
3. Use Edit to update existing files, or Write to create new ones

4. Format entries clearly:
   - **Quick Facts**: `- **[Topic]**: [Value]` (one per line, newest first)
   - **Decisions Log**: `## [Date] — [Decision Title]\n\n[Context and reasoning]\n` (newest first)
   - **Preferences**: Match existing file formatting, append to relevant sections
   - **Projects**: Use YAML frontmatter + sections: Goal, Status, Key Decisions, Open Questions, Notes
   - **People**: Use YAML frontmatter + sections: Role, Company, Relationship, Notes

5. Use Obsidian-compatible Markdown:
   - `[[wiki-links]]` for cross-references between notes
   - YAML frontmatter with `---` delimiters
   - Tags with `#tag` or in frontmatter `tags: [tag1, tag2]`

### 3. Recall Context (Loading Memory)

At the **start of any new session**, or when the user asks "what do you remember about X":

1. Use Glob to find relevant files in the vault
2. Use Read to load the content of relevant files
3. Load context silently at session start — don't dump everything on the user, just use it
   to inform your responses
4. When explicitly asked, summarize what you remember in a conversational way

**Selective Loading Strategy** (don't read everything):
- Always load: `Preferences/Boaz Profile.md` (small, always relevant)
- Always load: `Claude Memory/Quick Facts.md` (small, always relevant)
- Load today's daily note: `Daily/{today's date}.md` (current context)
- Load yesterday's daily note: `Daily/{yesterday's date}.md` (continuity)
- Load specific Project files only when the conversation topic matches
- Load People files only when a specific person is mentioned
- Load `Claude Memory/Session Archive.md` only if the user references a past session
- Load `Claude Memory/Decisions Log.md` only when a related decision comes up

**Search across the vault:**
- Use Grep with the vault path to search all files for a keyword or topic
- This is the "recall" equivalent of Notion search but faster (local filesystem)

### 4. End-of-Session Save

When a session is wrapping up, or the user says "save session", "update memory", or "remember
what we did":

1. Summarize the session: what was discussed, what was decided, what was created
2. Prepend a session summary to `Claude Memory/Session Archive.md`:

```markdown
## [Date] — [Session Title]

**Topics**: [list of topics]
**Decisions**: [key decisions made]
**Created**: [files or artifacts created]
**Next Steps**: [what's pending]

---
```

3. Update any Project files that were worked on
4. Add any new decisions to `Claude Memory/Decisions Log.md`
5. Update Preferences files if new preferences were expressed
6. Optionally append a "Claude Session Summary" section to today's Daily note
7. Confirm: "I've saved this session to your vault. Next time we chat, I'll remember where
   we left off."

### 5. Forget Something

When the user says "forget X", "delete X from memory", or "remove X":

1. Use Grep to search for the content across the vault
2. Use Edit to remove the specific entry (or delete the file if it's a standalone note)
3. Confirm what was removed: "Done — I've removed [X] from [location]."

## Automatic Memory Triggers

Watch for these patterns and proactively save to memory:

| User says... | Action |
|-------------|--------|
| "I prefer...", "I always...", "I like..." | Update **Preferences/** files |
| "Let's go with...", "The decision is..." | Add to **Claude Memory/Decisions Log.md** |
| "Remember that...", "Note that...", "FYI..." | Add to **Claude Memory/Quick Facts.md** |
| "We're working on [project]..." | Create/update **Projects/** file |
| "I'm [name/role]..." | Update **Preferences/Boaz Profile.md** |
| "[Person] is...", "Talk to [person] about..." | Create/update **People/** file |

## Formatting Guidelines

When writing to the vault:

- Use Obsidian-flavored Markdown:
  - `[[wiki-links]]` for internal cross-references
  - YAML frontmatter between `---` delimiters
  - `#tags` inline or in frontmatter
  - Callouts: `> [!note]`, `> [!warning]`, etc.
- Always include dates on time-sensitive entries: `[2026-03-31]`
- Keep entries concise — this is reference material, not prose
- Use headers (`##`) to separate entries within a file
- Most recent entries go at the TOP of each file (reverse chronological)
- Match the existing style of whatever file you're editing

## Privacy & Transparency

- Only save information the user has shared in conversation
- Never save sensitive data (passwords, API keys, tokens) to the vault
- When in doubt about whether to save something, ask the user
- The user can always say "show me my memory" to see everything stored
- All memory is local Markdown files — the user has full control and can edit with any text editor
- Files sync only if the user has set up sync (Google Drive, iCloud, etc.)

## Error Handling

- If the vault path doesn't exist: ask the user to provide the correct path
- If a file can't be found: create it with sensible defaults
- If a folder doesn't exist: create it
- If the Claude Memory folder is missing: recreate it with the initialization workflow
- If a file is locked (e.g., by Obsidian sync): wait briefly and retry, then inform the user

## Example Interactions

**User**: "Remember that I prefer dark mode in all my apps and I use Vim keybindings"
**Claude**: *Updates Preferences/Boaz Profile.md* "Got it — added dark mode and Vim keybindings
to your profile."

**User**: "What do you know about me?"
**Claude**: *Reads Preferences/ and Quick Facts* "From your vault, I know you prefer dark mode
and Vim keybindings, you work at Bizzabo as [role], and you like concise responses."

**User**: "Save what we did today"
**Claude**: *Creates session archive entry, updates daily note* "Saved — today we built the
Obsidian Memory plugin and added it to the marketplace."

**User**: "What did we decide about the database migration?"
**Claude**: *Greps vault for "database migration"* "On 2026-03-15, we decided to go with
PostgreSQL because of the JSON support requirements. See [[Projects/Backend Migration]]."
