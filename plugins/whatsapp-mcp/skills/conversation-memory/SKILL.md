---
name: conversation-memory
description: >
  Persistent per-contact memory for WhatsApp conversations, stored in Obsidian vault.
  Automatically triggered before and after WhatsApp interactions. Stores contact profiles,
  communication preferences, conversation history, and learnings as Markdown files in the
  vault's People/ folder and Claude Memory/WhatsApp/ folder.
  Use when sending or reading WhatsApp messages to personalize communication.
  Also trigger when the user asks about a contact's preferences, past conversations,
  or communication style — "how does X like to be contacted", "what language does Y prefer",
  "show me what we know about Z".
---

# Conversation Memory — Obsidian-Based Contact Profiles

Persistent per-contact memory that makes Claude better at WhatsApp communication over time.
All data is stored as local Markdown files in the user's Obsidian vault.

## Vault Path

Default vault path:
```
/Users/boaz/Library/CloudStorage/GoogleDrive-boaz@bizzabo.com/My Drive/Obsidian Vault/Boaz Main/
```

## Storage Layout

```
Obsidian Vault/
├── People/                          — (EXISTING) Contact profiles
│   ├── {Contact Name}.md            — General info + WhatsApp section
│   └── ...
└── Claude Memory/
    └── WhatsApp/                    — (CREATED BY PLUGIN) Conversation logs
        ├── {Contact Name}/
        │   ├── 2026-03-31.md        — Conversation log for that date
        │   └── ...
        └── Outreach Log.md          — Business outreach tracking
```

### People/ Files (Contact Profiles)

Each contact gets a file in `People/` with a `## WhatsApp Profile` section appended or updated.
If the file already exists (with non-WhatsApp info), add the section — never overwrite existing content.

**Template for WhatsApp section in People/{Contact Name}.md:**

```markdown
## WhatsApp Profile

- **Phone**: 972501234567
- **JID**: 972501234567@s.whatsapp.net
- **Preferred Language**: Hebrew
- **Preferred Tone**: Casual, Direct
- **Relationship**: Client
- **Responds Well To**: Short messages, Voice messages
- **Avoid**: Long paragraphs, Formal tone
- **Best Time to Reach**: After 6pm
- **Success Score**: 7/10

### Key Learnings

- Prefers voice messages over text
- Responds faster to Hebrew messages
- Engages more with questions than statements
- [2026-03-31] Liked the project update format with bullet points

### Interaction Summary

- **First Contact**: 2026-03-15
- **Last Interaction**: 2026-03-31
- **Total Interactions**: 8
- **Avg Response Time**: ~2 hours
```

### Claude Memory/WhatsApp/ (Conversation Logs)

Detailed conversation logs stored per contact per date:

**Template for Claude Memory/WhatsApp/{Contact Name}/2026-03-31.md:**

```markdown
---
title: "WhatsApp — {Contact Name} — 2026-03-31"
tags: [claude-memory, whatsapp, conversation-log]
contact: "[[{Contact Name}]]"
date: 2026-03-31
---

# Conversation with {Contact Name} — 2026-03-31

## Context
- **Purpose**: Follow-up on project proposal
- **Initiated by**: User
- **Language**: Hebrew

## Conversation

| Time | Sender | Message |
|------|--------|---------|
| 14:30 | User | שלום, רציתי לעדכן אותך על ההצעה |
| 14:35 | Contact | היי! כן, חיכיתי לזה |
| ... | ... | ... |

## Analysis

- **Tone**: Warm, engaged
- **Response Speed**: Fast (5 min)
- **Engagement Level**: High
- **Topics That Worked**: Project updates, timeline questions
- **Topics That Fell Flat**: N/A

## Learnings (saved to profile)

- Responds quickly to project-related messages
- Prefers Hebrew for business communication

## Next Steps

- [ ] Send revised proposal by Thursday
- [ ] Schedule call for next week
```

## Core Workflows

### 1. Pre-Conversation Lookup (Before Sending)

**Triggered automatically** when the user is about to send a WhatsApp message.

1. Identify the contact name from the send request
2. Use Glob to check if `People/{Contact Name}.md` exists
3. If found, Read the file and extract the `## WhatsApp Profile` section
4. Use the profile to adapt the message:
   - Match their preferred language
   - Match their preferred tone
   - Avoid known dislikes
   - Time the message appropriately if "Best Time to Reach" is set
5. If no profile exists, proceed with neutral defaults and note this is a first interaction

**Example:**
```
User: "Send a message to Yossi about the project update"
Claude: [Reads People/Yossi.md → sees he prefers Hebrew, casual tone, short messages]
Claude: "I'll draft this in Hebrew, keeping it short and casual since that's what works best with Yossi:
  'היי יוסי, עדכון קצר על הפרויקט — סיימנו את השלב הראשון. אפשר לדבר מחר?'
  Send this to Yossi (972501234567)?"
```

### 2. Post-Conversation Update (After Interaction)

**Triggered automatically** after a WhatsApp conversation ends or the user moves to a different topic.

1. Analyze the conversation that just happened:
   - What language was used?
   - What was the tone?
   - How quickly did they respond?
   - What topics generated engagement?
   - What didn't land?
2. Update `People/{Contact Name}.md`:
   - Update or create the `## WhatsApp Profile` section
   - Append new learnings with date stamps
   - Update interaction count and last interaction date
   - Adjust success score based on conversation quality
3. Create a conversation log in `Claude Memory/WhatsApp/{Contact Name}/{date}.md`
4. Silently confirm: "Updated Yossi's profile with today's conversation insights."

### 3. Explicit Profile Query

When the user asks "what do you know about X" or "how should I message X":

1. Read `People/{Contact Name}.md` for the WhatsApp profile
2. Use Grep to search `Claude Memory/WhatsApp/{Contact Name}/` for recent logs
3. Summarize: preferred language, tone, what works, what to avoid, recent interactions
4. Suggest the best approach for the next message

### 4. First-Time Contact Setup

When messaging someone for the first time (no existing profile):

1. After the conversation, create a new entry in `People/{Contact Name}.md`
   - If the file exists (from other contexts), append the `## WhatsApp Profile` section
   - If the file doesn't exist, create it with YAML frontmatter + WhatsApp profile
2. Create the first conversation log in `Claude Memory/WhatsApp/{Contact Name}/`
3. Note: first interaction = baseline only. Mark learnings as preliminary.

**New contact file template:**

```markdown
---
title: "{Contact Name}"
tags: [person, whatsapp-contact]
---

# {Contact Name}

## WhatsApp Profile

- **Phone**: {number}
- **JID**: {jid}
- **Preferred Language**: TBD (observed: {language from first message})
- **Preferred Tone**: TBD
- **Relationship**: {if known, else "Unknown"}
- **Success Score**: —/10 (insufficient data)

### Key Learnings

- [First interaction] — baseline data only, patterns will emerge after 2-3 conversations

### Interaction Summary

- **First Contact**: {today's date}
- **Last Interaction**: {today's date}
- **Total Interactions**: 1
```

### 5. Lead-Specific Memory

For contacts identified as business leads:

1. After each conversation, generate a **Conversation History Document** in
   `Claude Memory/WhatsApp/{Contact Name}/{date}.md` with extra detail:
   - Full conversation transcript
   - Deal stage / pipeline status
   - Objections raised and how they were handled
   - Buying signals
   - Next steps with deadlines
2. Optionally upload to Google Drive (if google-drive-upload plugin is available)
3. Optionally link to Google Calendar event (if calendar tools are available)
4. Update the lead's `People/{Name}.md` with:
   - Deal status in the WhatsApp Profile section
   - Key objections and responses in learnings

### 6. Outreach Tracking

For batch outreach campaigns, maintain `Claude Memory/WhatsApp/Outreach Log.md`:

```markdown
---
title: Outreach Log
tags: [claude-memory, whatsapp, outreach]
---

# WhatsApp Outreach Log

## {Campaign Name} — {Date}

| Contact | Status | Sent | Responded | Follow-up | Notes |
|---------|--------|------|-----------|-----------|-------|
| [[Yossi]] | Replied | 2026-03-31 | 2026-03-31 | 2026-04-03 | Interested, wants proposal |
| [[Dana]] | No reply | 2026-03-31 | — | 2026-04-02 | First attempt |
```

## Learning Curve

- **1st interaction** — Baseline: record language, initial tone, context. Profile marked "TBD".
- **2-3 interactions** — Patterns emerge: response speed, preferred message length, emoji usage. Update profile from TBD to observed values.
- **5+ interactions** — Deep understanding: what motivates them, communication style, best approach. Success score becomes meaningful.
- **Ongoing** — Continuous refinement as behavior changes over time.

## Automatic Triggers

| Event | Action |
|-------|--------|
| About to send WhatsApp message | Read contact profile from People/ |
| WhatsApp conversation ends | Update profile + create conversation log |
| User asks "how should I message X" | Read profile + recent logs, suggest approach |
| User says "remember X prefers..." | Update contact's WhatsApp Profile section |
| Outreach batch sent | Update Outreach Log |

## Privacy & Transparency

- All data stored as local Markdown in the user's Obsidian vault
- No external APIs for memory storage (filesystem only)
- User can view and edit any profile directly in Obsidian
- Never store passwords, tokens, or financial data in profiles
- User can say "forget what you know about X" → remove WhatsApp Profile section + conversation logs

## Error Handling

- If People/ folder doesn't exist: create it
- If Claude Memory/WhatsApp/ doesn't exist: create it
- If a contact file is locked by sync: wait briefly, retry, then inform user
- If contact name is ambiguous: ask the user to clarify before updating the wrong profile
