---
description: Full audit — scan current activity, score it, and propose improvements
argument-hint: [platform URLs or handles (optional)]
---

Run a complete digital presence audit: scan what exists, score it, and deliver an improvement plan.

This command orchestrates a two-step workflow:

## Step 1: Scan & Score (presence-analyzer)

Use the `presence-analyzer` skill to evaluate the user's current activity.

### If browser/Chrome tools are available:
Navigate directly to the user's profiles. Ask for their handles/URLs:
- LinkedIn profile URL
- X/Twitter handle
- Instagram handle
- GitHub username
- Website/blog URL
- Facebook page (if applicable)
- YouTube channel (if applicable)

Visit each profile, review recent posts, evaluate profile completeness, and score activity.

### If no browser access:
Ask the user to share screenshots, links to recent posts, or describe their current activity.

### Scoring Dimensions (per platform)
Score each on a 1-10 scale:
- **Profile quality** — Bio, headline, photo, links
- **Content quality** — Hooks, value, platform-native style, AI-free voice
- **Activity level** — Frequency, consistency, recency
- **Engagement** — Reactions, comments, shares relative to audience size
- **Strategic coherence** — Cross-platform consistency, audience alignment, funnel logic

Present results as the visual scorecard from the presence-analyzer skill.

## Step 2: Improve (enhancement-advisor)

After presenting scores, immediately transition to the `enhancement-advisor` skill:

1. **Quick wins** — 3-5 things fixable in 10 minutes (rewrite bios, pin posts, etc.)
2. **Platform plans** — Write the actual improved copy (don't just suggest — produce it)
3. **30-day roadmap** — Week-by-week action plan
4. **Immediate deliverables** — Offer to:
   - Write improved bios/headlines ready to paste
   - Draft 3-5 posts using the recommended strategy
   - Create a 2-week content calendar
   - Build a GitHub profile README

## Output Format

Combine both steps into a single comprehensive report:

```
═══ DIGITAL PRESENCE AUDIT ═══

📊 SCORECARD
[Visual scorecard from presence-analyzer]

🔍 KEY FINDINGS
[Top 5 findings ranked by impact]

⚡ QUICK WINS (do these now)
[3-5 immediate actions with actual rewritten copy]

📋 30-DAY IMPROVEMENT PLAN
[Week-by-week roadmap]

🚀 NEXT STEPS
[What you can help with right now]
```

The goal is not just diagnosis — it's handing the user a ready-to-execute plan
with actual deliverables they can start using immediately.
