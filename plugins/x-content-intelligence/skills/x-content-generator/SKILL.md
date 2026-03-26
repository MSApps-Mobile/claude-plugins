---
name: x-content-generator
description: >
  Generate X (Twitter) content based on community insights and trends. Use this skill when the user asks to
  "write a tweet", "create X content", "generate posts for X", "draft a thread",
  "write something for Twitter", "create a content calendar for X", "draft replies for X",
  "help me post on X", "write posts that match this community", "generate engagement content",
  "create a posting schedule", "write a reply to this tweet", or any request to create
  content for X/Twitter. Also trigger when the user wants to generate content that matches
  a specific community's tone, create a weekly posting plan, or draft engagement replies.
---

# X Content Generator — Create Community-Matched Content for X

Generate posts, threads, replies, and content calendars for X (Twitter) that match the tone, topics, and engagement patterns of a target community. Works best when combined with the x-insights skill for data-driven content creation.

## Workflow

### Step 1: Understand the Content Goal

Determine what the user needs:

- **Single post**: One-off tweet on a specific topic
- **Thread**: Multi-tweet deep dive on a topic
- **Reply/engagement**: Thoughtful responses to existing posts
- **Content calendar**: A planned series of posts over days/weeks
- **Batch generation**: Multiple posts on different topics at once

Also determine:
- **Target audience**: Who should this resonate with?
- **Tone**: Should it match a specific community's voice? (If so, suggest running x-insights first)
- **Goal**: Awareness, engagement, thought leadership, community building, information sharing?

### Step 2: Gather Context

**If insights are available** (from a previous x-insights run or user-provided context):
- Use the community tone analysis to match voice and language
- Reference trending topics for relevance
- Mirror high-engagement post formats
- Avoid topics or tones that don't resonate

**If no insights are available**, ask the user:
- Describe the target community or audience
- Share examples of posts they like or that perform well
- Specify the tone they want (casual, professional, technical, curious, etc.)
- Mention any topics to focus on or avoid

### Step 3: Generate Content

#### Single Posts
Write posts that:
- Lead with the most interesting point (hook)
- Stay focused on one clear idea
- Use language natural to the target community
- Include a call to engagement when appropriate (question, opinion invite)
- Respect X's character limits (280 for standard, longer for premium)

#### Threads
Structure threads that:
- Open with a compelling hook tweet that stands alone
- Build logically from point to point
- Include concrete examples or data
- End with a summary or call to action
- Number tweets if helpful (1/N format)
- Keep each tweet self-contained enough to be retweeted

#### Replies & Engagement
Draft replies that:
- Add genuine value to the conversation
- Show understanding of the original post
- Share a relevant perspective, experience, or question
- Avoid generic praise ("Great post!")
- Feel natural, not promotional

#### Content Calendar
Build calendars that:
- Vary content types (observations, questions, sharing, insights, appreciation)
- Spread topics across the calendar to avoid repetition
- Align with community rhythms (e.g., weekday vs. weekend posting)
- Include a mix of evergreen and timely content
- Suggest optimal posting times based on community activity

### Step 4: Review & Refine

For every piece of generated content, self-check:

1. **Authenticity**: Does this sound like a real person, not a bot or marketer?
2. **Value**: Would someone in the target community find this useful, interesting, or thought-provoking?
3. **Tone match**: Does it fit the community's communication style?
4. **Engagement potential**: Does it invite conversation or sharing?
5. **Clarity**: Is the message clear and easy to understand?
6. **Length**: Is it concise enough for the format?

If any check fails, revise before presenting.

### Step 5: Present Content

Present the generated content clearly:

**For single posts**: Show the post text, explain the reasoning behind the approach
**For threads**: Show each tweet numbered, with a brief note on the thread's narrative arc
**For replies**: Show the reply in context of what it's responding to
**For content calendars**: Present as a table with columns for date, content type, topic, and draft text

Always ask if the user wants adjustments to tone, topic, length, or approach.

## Content Types Reference

Rotate among these types for variety in calendars and batch generation:

| Type | Description | Example opener |
|------|-------------|---------------|
| Observation | Share a pattern or insight noticed | "Something I've noticed about..." |
| Question | Ask the community something genuine | "Curious how others handle..." |
| Discovery | Share something useful found | "Found something interesting..." |
| Before/After | Show a change or improvement | "Last month we... Now we..." |
| Hot take | Share a mildly contrarian opinion | "Unpopular opinion:..." |
| Appreciation | Highlight someone else's great work | "This thread by @... really clicked" |
| How-to | Share a practical tip or technique | "Quick tip that saved us hours:..." |
| Story | Tell a short, relatable narrative | "Last week I ran into..." |

## Tone Presets

If the user doesn't specify tone, offer these presets:

- **Builder**: Sharing from experience, practical, peer-to-peer ("We tried X and found that Y...")
- **Curious**: Asking questions, exploring ideas, open-minded ("I've been thinking about X...")
- **Technical**: Precise, detailed, code-aware ("Here's the approach we used for X...")
- **Casual**: Relaxed, conversational, sometimes humorous ("OK but why does X always...")
- **Professional**: Polished, informative, balanced ("Key takeaway from X: ...")

## Best Practices

- Never sound like a press release or marketing copy
- Avoid buzzwords that the target community would roll their eyes at
- Use specific examples over vague generalities
- When in doubt, shorter is better
- Questions drive more engagement than statements
- Tagging/mentioning others should be genuine, not forced
- Hashtags: use sparingly (0-2 per post) and only if the community actually uses them
