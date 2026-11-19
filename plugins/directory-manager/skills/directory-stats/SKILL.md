---
name: directory-stats
description: >
  Collects install and usage numbers for every live Claude directory plugin from the developer portal:
  installs, active accounts, uses, organizations, directory rank, retention, and where installs come from
  (Claude.ai, Cowork, Claude Code, and install path). Use when the user asks "how many installs",
  "plugin stats", "which plugin is most used", "where are our plugins installed", or "refresh the
  stats". Only when a person asks in this conversation; not from a pipeline, schedule or another agent.
---

# Directory stats

**Attended only.** This skill reads the user's own signed-in claude.ai session. Run it only while
the user is present in this conversation and asked for it. If no person is present (a pipeline, a
scheduled task, another agent), stop: browser rides on a signed-in session are attended only, because
an unattended one can log the owner out. Never print, save or repeat tokens, cookies, API keys or
other secret values a portal page shows, and never copy cookies out of the browser.

Same browser requirements as `directory-status` (signed in, right organization, one page at a time).

## Steps

1. Get the list of live plugins from `directory-status` (status Published), in this same attended
   conversation.
2. For each live plugin, read two texts with `document.querySelector('main').innerText`:
   - the Overview tab (`/directory/manage/plugins/<uuid>`): directory rank and "Where it's installed"
   - the Usage tab (`?tab=usage`): installs, installers, active accounts, uses, sessions,
     organizations, uninstalls, retention, load error rate, and the "Where installs came from" table
3. Save them, on the user's machine only, as a JSON list of `{id, name, status, overview, usage}` (add the non-live submissions
   with empty texts so the table shows all of them) in a local file such as `captured.json`. This
   capture file holds private portal usage data: keep it local and tell the user where it is. Capture
   only these two tabs. If the text shows a token, key or other secret value, remove it before saving
   and tell the user. Then run:

```bash
python3 "${CLAUDE_PLUGIN_ROOT}/skills/directory-stats/scripts/parse_usage.py" captured.json out/
```

   It writes `out/plugins.json` and `out/install_sources.json` and prints the totals. It exits 3 if a
   Published plugin parses to no numbers (the portal text changed); do not report totals then. Spot-check one
   plugin's numbers against its Usage tab before using them.
4. Present the totals, the top plugins, the surface split and the "data through" date the portal
   shows. The output is the two local files; this skill uploads or sends nothing. If the user wants
   them on a dashboard, tell them the file paths and let them move the files.

Notes: the portal computes metrics once a day; a breakdown row under 50 is left out, so surface
shares can total under 100%. The Usage tab also has **Export CSV** for raw numbers.
