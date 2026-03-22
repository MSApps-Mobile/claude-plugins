---
name: brand-voice-setup
description: >
  Interactive brand voice configuration for the digital-presence plugin. Use this skill
  when the user says "set up my voice", "configure my brand", "my writing style",
  "brand voice setup", "how should my posts sound", "tone setup", "define my style",
  or any request about establishing or updating their personal or brand writing style
  for social media and content. Also trigger when a user first installs the plugin
  and hasn't configured their voice yet.
---

# Brand Voice Setup

Establish the user's unique writing voice so all content skills produce on-brand output.

## What This Creates

A `brand-voice.md` file saved to the user's workspace that other skills in this plugin
reference when generating content. This file captures identity, audience, tone, topics,
and style rules.

## Interview Process

Walk the user through these sections conversationally. Use AskUserQuestion when possible.
Don't dump all questions at once — go section by section.

### Section 1: Identity
- What's your name and role?
- What does your company/brand do? (1-2 sentences)
- What industry are you in?

### Section 2: Audience
- Who are you trying to reach? (job titles, demographics, interests)
- What problems do they have that you help with?
- Where do they hang out online? (which platforms matter most)

### Section 3: Tone & Style
Ask the user to pick 3-5 adjectives that describe how they want to sound. Offer examples:

Confident, Casual, Technical, Witty, Direct, Warm, Authoritative, Playful,
Provocative, Educational, Minimalist, Storytelling, Data-driven, Conversational

**Resolve conflicts:** If the chosen adjectives might clash (e.g., "Witty + Formal" or
"Direct + Warm"), ask the user to clarify how they balance these. For example:
"You picked both 'direct' and 'witty' — does that mean you lead with a sharp point
and soften with humor? Or does the wit come first?" This prevents voice drift later.

Then ask:
- Show me a post or piece of writing you love (yours or someone else's) — what do you like about it?
- Is there a style you actively dislike? (motivational guru, corporate jargon, emoji-heavy, etc.)

### Section 4: Topics & Expertise
- What 3-5 topics do you post about most?
- Any topics that are off-limits?
- Do you have specific phrases, terms, or frameworks you use often?

### Section 5: Platform Preferences
- Which platforms are most important to you? (rank them)
- Should your voice shift across platforms? (e.g., more casual on X, more polished on LinkedIn)
  If yes, capture the specific differences per platform.
- Any platform-specific preferences? (e.g., "no emojis on LinkedIn", "threads only on X")

## Output Format

Generate a `brand-voice.md` file with this structure:

```markdown
# Brand Voice — [Name]

## Identity
**Name:** [Name]
**Role:** [Role]
**Company:** [Company]
**Industry:** [Industry]
**One-liner:** [What you do in one sentence]

## Audience
**Primary:** [Description]
**Pain points:** [What they struggle with]
**Platforms:** [Ranked list]

## Voice & Tone
**Adjectives:** [3-5 adjectives]
**In practice:** [2-3 sentences describing the voice in action]

### Do
- [Style rule 1]
- [Style rule 2]
- [Style rule 3]

### Don't
- [Anti-pattern 1]
- [Anti-pattern 2]
- [Anti-pattern 3]

## Topics
**Core topics:** [List]
**Off-limits:** [List or "none"]
**Signature phrases/frameworks:** [List or "none"]

## Platform Notes
[Any platform-specific preferences]
```

Save to the user's workspace folder. Confirm the file location with the user.

## Updating an Existing Voice

If the user already has a `brand-voice.md`, read it first and ask what they want to change
rather than re-running the full interview.
