---
name: conversation-memory
description: >
  Persistent conversation memory that learns from WhatsApp interactions.
  Reads contact preferences before messaging, updates learnings after each conversation.
  For leads: creates a conversation history doc, uploads to Google Drive, and links to the GCal event.
  Use this skill AUTOMATICALLY before and after every WhatsApp conversation.
  Trigger words: "מה אני יודע על", "conversation memory", "עדכן זיכרון", "תלמד מהשיחה",
  or any WhatsApp interaction where context about the contact would help.
metadata:
  version: "0.1.0"
  notion_db: "collection://98f76167-3dc2-423a-9615-6e1470c608d2"
  notion_parent: "32938b5d-fb27-810f-ab42-ebbb6860c481"
---

# Conversation Memory System

Persistent memory that learns from every WhatsApp conversation Claude has.
Stored privately in Notion under Claude Memory > Conversation Memory.

## Notion Database
- **Data Source:** `collection://98f76167-3dc2-423a-9615-6e1470c608d2`
- **Parent Page:** Claude Memory (`32938b5d-fb27-810f-ab42-ebbb6860c481`)

## Schema (Notion DB columns)
| Column | Type | Purpose |
|--------|------|---------|
| Contact Name | Title | Person's name |
| Phone/JID | Text | WhatsApp JID or phone |
| Preferred Language | Select | Hebrew / English / Mixed |
| Preferred Tone | Select | Casual / Professional / Warm / Direct / Playful || Relationship | Select | Family / Friend / Client / Lead / Colleague / Other |
| Responds Well To | Multi-select | Emojis, Short messages, Detailed messages, Questions, Humor, Formal |
| Avoid | Text | Things NOT to do with this contact |
| Last Interaction | Date | When we last talked |
| Conversation Log | Text | Running log of interactions |
| Key Learnings | Text | What we learned about this person |
| Success Score | Number | 0-10, how well conversations go |

---

## BEFORE Sending a WhatsApp Message

**Always do this before composing any WhatsApp message:**

1. **Search Notion** for the contact:
   - Use `notion-search` with the contact's name
   - Or search the Conversation Memory data source directly
2. **If found** — read their profile and adapt:
   - Use their preferred language and tone
   - Apply "Responds Well To" patterns
   - Avoid things listed in "Avoid"
   - Read the Conversation Log for context on last interactions
3. **If NOT found** — create a new entry after the conversation

---

## AFTER Every WhatsApp Conversation

**Always update memory after a conversation:**

1. **Analyze the interaction:**
   - What language did the contact respond in?
   - What was their tone? (short replies = prefers brevity, emojis = playful, etc.)
   - Did they engage? (response time, length, enthusiasm)
   - What topic got the best reaction?
2. **Update Notion entry** using `notion-update-page`:
   - Update `Preferred Language`, `Preferred Tone` based on observed patterns
   - Add to `Responds Well To` if something worked
   - Add to `Avoid` if something fell flat
   - Append to `Conversation Log`: date + summary of what was sent and response
   - Update `Key Learnings` with new insights
   - Adjust `Success Score` (0 = no response, 5 = engaged, 10 = enthusiastic)
   - Set `Last Interaction` to today

3. **If new contact** — create a new page in the Conversation Memory DB

---

## LEAD-SPECIFIC WORKFLOW

When the contact is a **Lead** (Relationship = Lead), do extra steps:

### First Conversation with a Lead
1. After the WhatsApp conversation, generate a **Conversation History Document**:
   - Format: Markdown file (`.md`) with structured sections
   - Include: lead name, company, date, full conversation, notes, next steps
   - File name: `WhatsApp-History-{LeadName}-{Date}.md`

2. **Upload to Google Drive** using the google-drive-upload skill:
   - Upload the file to a "WhatsApp Conversations" folder in Drive
   - Save the returned Drive link

3. **Link to GCal event** using Google Calendar MCP:
   - Search for the lead's event in GCal (leads are stored as calendar events)
   - Update the event description to include the Drive link
   - Format: `📱 WhatsApp History: {drive_link}`
### Follow-up Conversations with a Lead
1. **Read the existing history doc** from Drive (via the GCal event link)
2. **Append** the new conversation to the doc
3. **Re-upload** the updated file to Drive (same name, overwrite)
4. Update the Notion entry with new learnings

### Conversation History Document Template
```markdown
# WhatsApp Conversation History — {Lead Name}
**Company:** {company}
**Phone:** {phone}
**Relationship:** Lead
**First Contact:** {date}
**Last Updated:** {date}

---

## Conversation 1 — {date}
**Context:** {why we reached out}
**Messages:**
- **Claude:** {message sent}
- **{Name}:** {their response}
- **Claude:** {follow-up}

**Outcome:** {what happened}
**Next Steps:** {what to do next}

---

## Key Insights
- {language preference}
- {tone preference}
- {topics of interest}
- {decision-making style}
```

---

## How Learning Works

The system learns through pattern accumulation:
1. **First interaction** — baseline: record language, initial tone, context
2. **2-3 interactions** — patterns emerge: response speed, preferred length, emoji usage
3. **5+ interactions** — deep understanding: what motivates them, communication style, best approach
4. **Ongoing** — refinement: continuously update as behavior changes

Each session reads the accumulated knowledge and builds on it. The Notion DB is the persistent brain — it survives across sessions and grows smarter with every conversation.

## Integration Points

- **whatsapp-send skill** — reads memory before composing messages
- **whatsapp-outreach skill** — uses lead profiles for personalized outreach
- **lead-management-crm skill** — syncs with lead status in GCal
- **google-drive-upload skill** — stores conversation history docs
- **Google Calendar MCP** — links docs to lead events

## Privacy

All data is stored in Michal's private Notion workspace under "Claude Memory".
No data is shared externally. Contact profiles are only used to improve conversation quality.