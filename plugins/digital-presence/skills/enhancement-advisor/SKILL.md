---
name: enhancement-advisor
description: >
  Propose specific, actionable improvements to a user's digital presence based on analysis.
  Use this skill when the user says "how can I improve", "what should I change", "fix my profile",
  "make my LinkedIn better", "improve my GitHub", "optimize my website", "upgrade my socials",
  "what's missing", "enhancement suggestions", "growth plan", or any request for recommendations
  on how to strengthen their online presence. Also trigger after a presence-analyzer scan when
  the user wants to act on the findings. This is the WRITE side — turning analysis into an
  action plan with specific deliverables.
---

# Enhancement Advisor

Turn presence analysis into a concrete improvement plan with specific deliverables the user
can implement immediately or over the next 30 days.

## How This Skill Connects

This skill works best AFTER `presence-analyzer` has run and scored the user's platforms.
If no analysis has been done yet, suggest running it first, OR ask the user to describe
their current situation so you can advise without a full audit.

## Enhancement Process

### Step 1: Identify the Biggest Levers

Not everything matters equally. Prioritize by impact:

**High Impact (fix these first):**
- Profile/bio optimization (every visitor sees this)
- Hook quality on posts (determines if anyone reads beyond line 1)
- Posting consistency (algorithms reward regularity)
- Platform choice (are they on the right platforms for their audience?)

**Medium Impact:**
- Content mix diversification
- Hashtag strategy
- Cross-platform consistency
- Engagement response rate

**Lower Impact (optimize later):**
- Posting time optimization
- Banner images / visual assets
- Hashtag research depth
- Analytics setup

### Step 2: Create Platform-Specific Enhancement Plans

For each platform that needs work, generate a concrete plan:

#### Profile Enhancements
Don't just say "improve your bio" — WRITE the improved bio.

Example format:
```
🔧 LinkedIn Headline
Current: "CTO at CloudBridge"
Proposed: "Building AI-powered dev tools that cut code review time by 60% | CTO @ CloudBridge"
Why: Your current headline is a job title. The proposed version communicates value and includes
     searchable keywords (AI, dev tools, code review). People searching for AI expertise will
     find you.
```

#### Content Enhancements
For each platform, provide:

1. **Content pillars** — 3-4 recurring themes to build authority around
   - Example: "AI in practice", "Engineering leadership", "Startup lessons", "Tool reviews"

2. **Post templates** — 2-3 ready-to-use formats the user can fill in regularly
   - Example: "The [common belief] is wrong. Here's what actually works: [insight]"
   - Example: "I spent [time] on [task]. Here's what I learned: [3 bullet takeaways]"

3. **Engagement playbook** — How to interact beyond just posting
   - Who to comment on (5-10 specific accounts in their niche)
   - How to comment (add value, don't just say "Great post!")
   - How often (15 min/day engagement > 1 hour/week posting)

4. **Quick wins** — Things they can do in the next 10 minutes
   - Update headline / bio
   - Pin their best post
   - Add a profile README on GitHub
   - Fix the one broken link on their website

### Step 3: Generate Deliverables

Don't just advise — produce the actual assets when possible:

**Things this skill should create directly:**
- Rewritten bio / headline / about section
- 3-5 post drafts using the new content pillars (hand off to `social-content` skill)
- GitHub profile README draft (hand off to `github-presence` skill if available)
- Content calendar for the next 2 weeks (use `/content-calendar` command)
- List of accounts to engage with (research using web search)

**Things to recommend the user create:**
- Professional headshot (can't generate, but can advise on style)
- Banner images (suggest dimensions, content, tools like Canva)
- Video content (suggest topics, format, equipment)

### Step 4: Build a 30-Day Improvement Plan

Structure the work into manageable weekly sprints:

```
WEEK 1: Foundation
├── Day 1-2: Profile optimization (all platforms)
├── Day 3-4: Content pillars defined, first 3 posts drafted
└── Day 5-7: Begin daily engagement routine (15 min/day)

WEEK 2: Content Engine
├── Write and publish 4-5 posts across platforms
├── Establish posting schedule
└── Set up any needed tools (scheduling, analytics)

WEEK 3: Engagement & Growth
├── Active commenting on 10 target accounts daily
├── Respond to every comment on own posts
├── Cross-promote between platforms
└── Create 1 long-form piece (blog/article/thread)

WEEK 4: Optimize & Scale
├── Review what performed best
├── Double down on top-performing content type
├── Repurpose best content across platforms
└── Plan Month 2 focus areas
```

## Output Format

Present the enhancement plan as:

1. **Executive Summary** — 3-sentence overview of current state → recommended focus → expected outcome
2. **Quick Wins** — 3-5 things they can do RIGHT NOW (under 10 minutes each)
3. **Platform Plans** — Per-platform recommendations with actual rewritten copy
4. **30-Day Roadmap** — Week-by-week action plan
5. **Metrics to Track** — What to measure to know it's working

After presenting the plan, offer to:
- Write any of the recommended posts immediately
- Create the GitHub profile README
- Build the full content calendar
- Draft the improved bios/headlines for copy-pasting

## Tone

Be direct and specific. Avoid vague advice like "post more consistently" — instead say
"Post on LinkedIn every Tuesday and Thursday at 8am, using the insight-post template.
Here are your first two posts ready to go."

The value of this skill is turning analysis into ACTION with minimal friction for the user.
