---
name: presence-analyzer
description: >
  Scan, view, and score a user's current activity across social media, website, and GitHub.
  Use this skill whenever the user asks to "check my LinkedIn", "review my profile",
  "how's my Instagram doing", "analyze my GitHub", "look at my posts", "audit my presence",
  "what's working on my socials", "score my activity", "review my website", "check my content",
  or any request to view, evaluate, or assess their current digital presence on any platform.
  Also trigger when someone says "what should I improve", "where am I weak", "am I posting enough",
  "how does my profile look", or shares a URL/handle and wants feedback. This is the READ side
  of digital presence — viewing what exists before suggesting changes.
---

# Presence Analyzer

View and evaluate a user's current digital activity across platforms. This skill is the
"diagnosis" step — understanding what exists before prescribing improvements.

## How It Works

This skill can operate in two modes depending on available tools:

### Mode 1: Live Scan (when ~~browser or Chrome tools are available)
Navigate to the user's actual profiles and analyze what's there in real-time.
Use Claude in Chrome / browser tools to:
- Visit their LinkedIn profile and recent posts
- Check their X/Twitter feed and engagement
- View their Instagram grid and captions
- Read their GitHub profile and repos
- Browse their website

### Mode 2: User-Reported (when no browser access)
Ask the user to share:
- Screenshots of their profiles
- Links to their recent posts
- Their posting frequency
- Any analytics they have access to

## Analysis Framework

For each platform the user wants analyzed, evaluate these dimensions:

### 1. Profile Quality (first impression)
- **Bio/headline:** Clear value proposition? Keywords? Compelling?
- **Photo/avatar:** Professional? Consistent across platforms?
- **Banner/cover:** Utilized? On-brand?
- **Links:** Working? Strategic? (e.g., link-in-bio, pinned tweet link)
- **Score: 1-10**

### 2. Content Quality (what they're posting)
- **Hook strength:** Do posts open with something that stops the scroll?
- **Value delivery:** Is each post teaching, sharing insight, or sparking discussion?
- **Platform-native:** Is content adapted per platform or copy-pasted?
- **Voice consistency:** Does the author sound like the same person across posts?
- **Visual quality:** (Instagram/LinkedIn) Are images/graphics professional?
- **AI tells:** Does the content sound AI-generated? (generic phrasing, "in today's world", etc.)
- **Score: 1-10**

### 3. Activity & Consistency (how often)
- **Posting frequency:** How often per week/month?
- **Consistency:** Regular schedule or sporadic bursts?
- **Recency:** When was the last post?
- **Platform-appropriate cadence:**
  - LinkedIn: 3-5x/week is strong, 1x/week is minimum
  - X/Twitter: Daily is ideal, 3x/week minimum
  - Instagram: 3-4x/week for feed, daily for stories
  - GitHub: Regular commits, not just occasional dumps
  - Website/blog: 2-4x/month for blogs
- **Score: 1-10**

### 4. Engagement (how people respond)
- **Likes/reactions:** Relative to follower count
- **Comments:** Quality and quantity
- **Shares/reposts:** Are people amplifying?
- **Response rate:** Does the user reply to comments?
- **Growth trend:** Growing, flat, or declining?
- **Score: 1-10**

### 5. Strategic Coherence (does it all add up?)
- **Cross-platform consistency:** Same person, adapted to each platform
- **Topic focus:** Clear expertise areas or all over the place?
- **Audience alignment:** Is content reaching the right people?
- **Funnel logic:** Does the presence lead somewhere? (newsletter, product, service, portfolio)
- **Score: 1-10**

## Platform-Specific Analysis

Read from `references/` for platform-specific scoring criteria:

- `references/linkedin-analysis.md` — LinkedIn-specific metrics and benchmarks
- `references/github-analysis.md` — GitHub activity scoring and profile review
- `references/website-analysis.md` — Website/blog content and SEO review

## Output Format

### Scorecard

```
╔══════════════════════════════════════════════════╗
║          DIGITAL PRESENCE SCORECARD              ║
╠══════════════════════════════════════════════════╣
║ Platform    │ Profile │ Content │ Activity │ Eng ║
╠─────────────┼─────────┼─────────┼──────────┼─────╣
║ LinkedIn    │  8/10   │  6/10   │  4/10    │ 5/10║
║ X/Twitter   │  5/10   │  7/10   │  3/10    │ 4/10║
║ Instagram   │  7/10   │  5/10   │  2/10    │ 3/10║
║ GitHub      │  3/10   │  —      │  6/10    │ —   ║
║ Website     │  6/10   │  4/10   │  2/10    │ —   ║
╠═════════════╧═════════╧═════════╧══════════╧═════╣
║ Overall Presence Score:  47/100                  ║
║ Strategic Coherence:     6/10                    ║
╚══════════════════════════════════════════════════╝
```

### Per-Platform Summary
For each platform, write 2-3 sentences covering:
1. What's working well (be specific — cite actual posts or elements)
2. The biggest gap (one thing that would make the most difference)
3. Quick win (something fixable in under 10 minutes)

### Top Findings
Rank the top 5 findings across all platforms by impact, with:
- What the issue is
- Why it matters
- How to fix it

After presenting the analysis, offer to hand off to the `enhancement-advisor` skill
for detailed improvement plans, or to the `social-content` skill to start creating
better content immediately.
