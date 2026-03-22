---
description: Turn one piece of content into posts for every platform
argument-hint: [content or topic]
---

Take the provided content and create platform-native versions for multiple social platforms.

## Input
The user provides: $ARGUMENTS

This could be a blog post, article, long-form text, a link, raw notes, or a topic idea.

## Process

1. **Extract the core message** — What's the one thing this content is really about?
2. **Identify 2-3 key insights** — The most shareable, valuable points
3. **Read the user's brand voice** — Check for `brand-voice.md` in the workspace and apply it

## Create Versions For Each Platform

Read the platform reference files from the social-content skill for detailed guidance:
`${CLAUDE_PLUGIN_ROOT}/skills/social-content/references/`

Generate content for ALL of these platforms (unless user specifies otherwise):

### LinkedIn
- 150-300 words, professional tone
- Lead with the most business-relevant insight
- Short paragraphs, 2-3 hashtags at end

### X/Twitter
- Thread (3-5 tweets) if the topic has depth, or single tweet if it's sharp enough
- Most compressed version — distill to the essence
- 0-1 hashtags

### Instagram
- 80-150 word caption (assume they'll pair with a relevant image)
- More personal/authentic angle
- 5-10 hashtags at end or suggest for first comment

### Facebook
- 100-200 words, conversational and shareable
- Frame for community discussion
- 0-2 hashtags

## Output Format

Present each version clearly labeled with the platform name as a header.
After all versions, suggest which platform should go first (highest-value content match).

Don't just shorten or lengthen the same text — genuinely reimagine the content for each platform's audience and format.
