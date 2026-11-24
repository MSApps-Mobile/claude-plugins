---
name: directory-status
description: >
  Reads every plugin submission in the Claude directory developer portal (claude.ai/directory/manage)
  and reports each one's status, why its newest version is not live, and who acts next. Use when the
  user asks "what's the status of our plugins", "which plugins need changes", "why isn't X live",
  "what's waiting for review", or "check the directory portal". Only when a person asks in this
  conversation; not from a pipeline, schedule or another agent.
---

# Directory status (read-only)

**Attended only.** This skill reads the user's own signed-in claude.ai session. Run it only while
the user is present in this conversation and asked for it. If no person is present (a pipeline, a
scheduled task, another agent), stop: browser rides on a signed-in session are attended only, because
an unattended one can log the owner out. Never print, save or repeat tokens, cookies, API keys or
other secret values a portal page shows, and never copy cookies out of the browser.

Needs the user's Chrome signed in to claude.ai **in the organization that owns the submissions**
(the portal is per organization). Drive it with Claude in Chrome; fall back to the Playwright
extension bridge. Never copy cookies out of the user's browser.

## Steps

1. Open `https://claude.ai/directory/manage`. Wait until the heading reads
   "Everything <org> has submitted". The page first renders "0 submissions" while it loads;
   a count taken before that heading is wrong. If the heading says "Everything you have submitted",
   the user is in a personal account: stop and ask them to switch organization.
2. Collect every link matching `/directory/manage/plugins/<uuid>` (de-duplicate by uuid).
3. For each, open the page and read the main text above the "Overview" tab plus the
   "Why the newest version isn't live" block. Read one page at a time; parallel tabs on one
   browser session break the bridge.
4. Classify each submission:

| Portal status | Who acts | Report as |
|---|---|---|
| Published, no newer version | nobody | Live |
| Published + "Publish requested" / Scan passed + "publish request is waiting" | Anthropic | Waiting for reviewer |
| Published or Scan passed + a **Publish update** button and no request | us | Needs a publish request (see `publish-requests`) |
| Needs changes / "Directory policy blocks" / "couldn't fetch" | us | Blocked, with the exact reason line |
| Scanning + "Scans … have failed repeatedly" | us | Scan failing; read the version's history |
| In review / Held | Anthropic | In review, with the held category |
| Delisted | us (decide) | Delisted, offer Relist |

5. Report a table grouped by who acts next, quoting each portal reason verbatim. Run
   `listing-lint` on the plugins that are blocked; most portal reasons map to one of its rules.

Do not click anything in this skill.
