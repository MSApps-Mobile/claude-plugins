---
name: social-content
description: >
  Write platform-optimized social media posts for LinkedIn, Instagram, X (Twitter),
  Facebook, and YouTube. Use this skill whenever the user asks to write a post, create
  social media content, draft a caption, compose a tweet, write a thread, create a
  LinkedIn article intro, write a YouTube description, or asks "what should I post".
  Also trigger when the user mentions "social content", "daily post", "content idea",
  "post about [topic]", "write something for [platform]", or any request about creating
  content for social media platforms — even casual ones like "I need something for LinkedIn"
  or "help me post about X". If the user shares an article, link, or idea and seems to
  want social content from it, this is the right skill.
---

# Social Content Writer

Create high-performing, platform-native social media content that sounds like the user — not like AI.

## Before Writing

### 1. Check for Brand Voice
Look for a `brand-voice.md` file in the user's workspace. If found, read it and apply
the voice throughout. If not found, write in a professional-but-human default tone and
suggest running the brand voice setup ("Want me to set up your brand voice first? It
takes 2 minutes and makes all future posts sound like you.").

### 2. Determine Platform
If the user didn't specify a platform, ask. Default to LinkedIn if they say "just pick one".
For "post this everywhere", use the `/repurpose` approach — adapt for each platform separately.

### 3. Understand the Input
The user might provide:
- **A topic/idea** → Find the angle, write the post
- **A link/article** → Extract the insight, don't just summarize
- **Raw thoughts** → Shape into a polished post
- **Nothing specific** → Suggest 2-3 topic ideas based on their brand voice topics
- **An image** → Write a caption that complements the visual

## Writing Process

### Step 1: Find the Hook
Every post needs an opening that stops the scroll. The hook should be:
- A surprising claim or counterintuitive take
- A relatable problem stated sharply
- A question that provokes thought
- A bold statement that demands context

Bad hooks: "I want to share something...", "In today's world...", "I've been thinking about..."
Good hooks: Start with the insight, the tension, or the unexpected angle.

### Step 2: Deliver Value in the Body
- Keep paragraphs short (1-3 sentences)
- One idea per paragraph
- Use concrete examples over abstract statements
- Data and specifics beat generalities
- Show, don't just tell

### Step 3: End with Intention
Don't force a CTA. Options:
- End on the strongest point (just stop at the peak)
- Ask a genuine question (not "What do you think?" but something specific)
- Leave an open loop that invites reflection
- Provide a clear next step if relevant

### Step 4: Platform Polish
Read the relevant platform reference file from `references/` for detailed formatting rules.
Apply platform-specific conventions (hashtags, length, structure, emoji usage).

## Platform Quick Reference

| Platform | Length | Tone | Hashtags | Emoji | Structure |
|----------|--------|------|----------|-------|-----------|
| LinkedIn | 150-300 words | Professional-smart | 2-3, end only | Minimal or none | Short paragraphs, line breaks |
| Instagram | 80-150 words | Casual-authentic | 5-15, comment or end | Moderate | Visual-first, caption supports image |
| X/Twitter | 1-3 tweets | Sharp-concise | 0-1 | Rare | Thread for complex topics |
| Facebook | 100-200 words | Conversational-warm | 0-2 | Light | Shareable, community-oriented |
| YouTube | Title + description | Clear-searchable | Tags, not inline | Minimal | SEO-aware, timestamped |

For detailed guidance on any platform, read `references/[platform].md`.

## Style Principles (When No Brand Voice File Exists)

1. **Sound human** — Write like a sharp person talking, not like a "content creator"
2. **Lead with insight** — Every post should teach, reveal, or reframe something
3. **Be specific** — "We reduced load time by 40%" beats "We improved performance"
4. **Cut the fluff** — If a sentence doesn't add value, delete it
5. **Match the platform** — A LinkedIn post is not a tweet with more words

## What NOT to Do

- Don't start with "Hey everyone!" or "Happy [day]!"
- Don't use motivational-poster language ("The journey of a thousand miles...")
- Don't stuff hashtags into the text body
- Don't write the same content for every platform
- Don't end every post with "Thoughts?" or "Drop a comment!"
- Don't use excessive emojis as bullet points (🔥 📌 💡 🚀)
- Don't include AI giveaway phrases ("In today's rapidly evolving landscape...")

## Tagging Rules

Every post MUST include tags/mentions for all relevant entities. This is not optional.

### Who to tag
- **Your own brand** — always tag your company/personal brand account
- **Tools & platforms mentioned** — if you mention a product, tool, or company by name, tag them
- **Social platforms discussed** — if the post talks about LinkedIn, Instagram, X, etc., tag their official accounts
- **People mentioned** — if you reference someone specific, tag them
- **Partners / collaborators** — anyone involved in what you're sharing

### Platform-specific tagging format
- **LinkedIn:** Use @CompanyName or @PersonName (LinkedIn auto-suggests)
- **X/Twitter:** Use @handles — find the correct handle for each brand
- **Instagram:** Use @handles in caption body or tag in the image
- **Facebook:** Use @PageName — Facebook auto-links recognized pages

### Common tags to remember
| Brand | LinkedIn | X/Twitter | Instagram | Facebook |
|-------|----------|-----------|-----------|----------|
| Anthropic | @Anthropic | @AnthropicAI | @anthropic | @Anthropic |
| Claude | @Claude | @ClaudeAI | — | — |
| GitHub | @GitHub | @github | @github | @GitHub |
| LinkedIn | — | @LinkedIn | @linkedin | @LinkedIn |
| Instagram | — | @Instagram | — | @Instagram |
| X/Twitter | — | @X | @x | — |

### Why this matters
Tags drive visibility. Every tag is a chance the tagged brand sees your post, engages, or reshares. Missing tags = missing reach. Always over-tag rather than under-tag.

## Output Format

Present the post ready to copy-paste. After the post, briefly note:
- Platform it's optimized for
- Suggested posting time (if relevant)
- One alternative angle if you see one

If the user wants variations, offer 2 versions with different hooks or angles.

## Handling Repurposing

If the user says "post this on all platforms" or "repurpose this":
1. Identify the core message
2. Write a unique version for each requested platform
3. Don't just shorten/lengthen — reimagine the content for each context
4. Present each version clearly labeled
