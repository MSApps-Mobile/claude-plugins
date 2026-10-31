---
name: directory-stats
description: >
  Collects install and usage numbers for every live Claude directory plugin from the developer portal:
  installs, active accounts, uses, organizations, directory rank, retention, and where installs come from
  (Claude.ai, Cowork, Claude Code, and install path). Use when the user asks "how many installs",
  "plugin stats", "which plugin is most used", "where are our plugins installed", "refresh the stats
  page", or wants a usage dashboard.
---

# Directory stats

Same browser requirements as `directory-status` (signed in, right organization, one page at a time).

## Steps

1. Get the list of live plugins from `directory-status` (status Published).
2. For each live plugin, read two texts with `document.querySelector('main').innerText`:
   - the Overview tab (`/directory/manage/plugins/<uuid>`): directory rank and "Where it's installed"
   - the Usage tab (`?tab=usage`): installs, installers, active accounts, uses, sessions,
     organizations, uninstalls, retention, load error rate, and the "Where installs came from" table
3. Save them as a JSON list of `{id, name, status, overview, usage}` (add the non-live submissions
   with empty texts so the table shows all of them), then run:

```bash
python3 "${CLAUDE_PLUGIN_ROOT}/skills/directory-stats/scripts/parse_usage.py" captured.json out/
```

   It writes `out/plugins.json` and `out/install_sources.json` and prints the totals. Spot-check one
   plugin's numbers against its Usage tab before using them.
4. Present the totals, the top plugins, and the surface split. If the user keeps a stats dashboard,
   upload both files as its data and keep the "data through" date the portal shows.

Notes: the portal computes metrics once a day; a breakdown row under 50 is left out, so surface
shares can total under 100%. The Usage tab also has **Export CSV** for raw numbers.
