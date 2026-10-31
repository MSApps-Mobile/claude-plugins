# CLAUDE.md — token-efficiency-audit

Daily automated task that audits token efficiency across Michal's Claude setup — skills, scheduled tasks, coding sessions, plugins, and MCP connectors — using the SOSA O6 optimization framework and the Reshef Method™ analysis.

---

## Expert Persona — Dr. Noa Reshef

This plugin includes an embedded AI expert persona: **Dr. Noa Reshef** — a fictional Stanford PhD / ex-GAMPA (Google Advanced Model Performance & Architecture) applied scientist specializing in LLM token economics.

- **Skill file:** `skills/token-efficiency-expert/SKILL.md`
- **When activated:** During deep analysis, cost modeling, prompt optimization prescriptions
- **The Reshef Method™:** Measure → Classify → Score → Prescribe → Verify
- **Key frameworks:** Token-hour cost model, waste taxonomy (dead/redundant/stale/vanity), prompt ROI scoring, cascade inference routing
- **Invoke with:** "token expert", "Dr. Reshef", "Noa", "analyze this prompt", "why is this expensive"

---

## Task Identity

- **Task name:** `token-efficiency-audit`
- **Owner:** Michal Shatz — michal@msapps.mobi
- **Run frequency:** Daily at ~08:00 IL time
- **Run mode:** Fully autonomous — Michal is not present. Do not ask questions. Make reasonable decisions and note them in the report.
- **Output:** Report saved to workspace as `token-audit-YYYY-MM-DD.md`
- **GitHub repo:** https://github.com/MSApps-Mobile/claude-plugins/tree/main/plugins/token-efficiency-audit

---

## What This Task Does

1. Scans all installed skills, scheduled tasks, plugins, and MCP connectors
2. Reviews recent coding/interactive sessions and running tasks for token waste
3. Measures token cost patterns using the 10-pattern O6 catalog (references/optimization-patterns.md)
4. Classifies findings by severity: 🔴 High waste / 🟡 Moderate / 🟢 Efficient
5. Produces a structured audit report with prioritized recommendations
6. Archives report to Notion
7. If anything new was learned → updates this CLAUDE.md and pushes to GitHub

---

## Step-by-Step Execution

### Step 1 — Inventory Scan

Gather all token-consuming components:

1. **Skills** — Read all SKILL.md files under `.claude/skills/` and any remote-plugins
   - Measure description length (target: <100 words)
   - Measure SKILL.md body length (target: <400 lines)
   - Check for inline data tables that should be externalized
   - Check for duplicated rules across skills

2. **Scheduled Tasks** — Use `list_scheduled_tasks` MCP tool
   - Check frequency (flag anything running more than 2x/day unless justified)
   - Read each task's SKILL.md from `/Users/michalshatz/Documents/Claude/Scheduled/{taskId}/SKILL.md`
   - Measure prompt length per task (target: <2000 tokens)
   - Flag inactive/stale tasks (enabled but never run, or last run >14 days ago)
   - Flag disabled tasks that could be deleted
   - Detect duplicate/overlapping tasks (same purpose, different IDs)
   - Check for tasks that could be consolidated into fewer runs
   - Verify descriptions are meaningful (not empty or placeholder like ">")

3. **Plugins** — List installed plugins from `.claude/skills/` and `.remote-plugins/`
   - Flag duplicate plugin instances
   - Check for plugins with overlapping capabilities

4. **MCP Connectors** — Review connected MCPs
   - Flag connectors that haven't been used in the last 7 days
   - Note connectors with large tool counts inflating the system prompt

5. **Running Tasks & Active Sessions** — Use `list_sessions` MCP tool
   - Check for sessions still running (stuck or long-running tasks)
   - Note any session that has been running >30 minutes — it may be stuck
   - Flag tasks that consistently take too long (compare to previous audits)

6. **Recent Coding/Interactive Sessions** — Use `list_sessions` + `read_transcript`
   - Pull the last 20 sessions (covers ~24h of activity)
   - For each completed session, read the transcript (last 20 messages)
   - Analyze for token waste patterns:

   **Coding session waste patterns to detect:**
   | Pattern | What to look for | Severity |
   |---------|-----------------|----------|
   | Excessive retries | Same tool called 3+ times with similar args (failed → retry loops) | 🔴 High |
   | Large file reads | Full file reads (>500 lines) when only a small section was needed | 🟡 Moderate |
   | Unused tool output | Tool called but output not referenced in subsequent messages | 🟡 Moderate |
   | Verbose instructions | Repeated system context across turns in same session | 🔴 High |
   | Agent sprawl | Subagent spawned for a task that could be done inline | 🟡 Moderate |
   | Web fetch waste | Same URL fetched multiple times in one session | 🔴 High |
   | Over-exploration | 5+ search/grep calls before finding the right file | 🟡 Moderate |
   | Bloated edits | Full file rewrites via Write when Edit would suffice | 🟡 Moderate |
   | Chrome loops | navigate → read_page → navigate → read_page cycles on same domain | 🔴 High |
   | Transcript length | Session transcript >100 messages — session may be doing too much | 🟡 Moderate |

   **Scheduled task run analysis:**
   - For each scheduled task that ran in the last 24h, read its session transcript
   - Measure: total messages, tool calls count, estimated token usage
   - Compare to previous runs of the same task — is it getting more expensive over time?
   - Flag tasks where >50% of messages are error handling / retries
   - Flag tasks that produce no useful output (empty reports, failed runs)

   **Coding session quality metrics:**
   - Tool calls per session (high count may indicate inefficiency)
   - Success rate (did the session accomplish its goal?)
   - Time to completion
   - Ratio of exploration (reads/searches) vs. action (writes/edits)

### Step 2 — Pattern Analysis

Load `references/optimization-patterns.md` and apply the 10 patterns (O6a-O6e):

| Category | What to check |
|----------|--------------|
| O6a | Prompt compression — bloated skill descriptions, verbose instructions |
| O6b | Context window — large CLAUDE.md files, inline tables, redundant sections |
| O6c | Batch processing — tasks that could be consolidated |
| O6d | Cache strategy — stable prompts that should be cached |
| O6e | Model routing — tasks using Opus that could use Sonnet/Haiku |

### Step 3 — Write the Report

Save to: workspace as `token-audit-YYYY-MM-DD.md`

Report sections:
1. **Summary** — components scanned (skills, tasks, plugins, connectors, sessions), total estimated token load, overall efficiency score
2. **📋 Task Inventory** — live count: total / recurring daily / recurring weekly / manual / disabled / never-run / new since last audit
3. **🔴 High Waste** — immediate action items with estimated savings
4. **🟡 Moderate** — optimization opportunities worth considering
5. **🟢 Efficient** — components that meet O6 standards
6. **🔄 Overlap Groups** — detected task groups with consolidation recommendations
7. **🏃 Running & Recent Sessions** — currently running tasks, stuck sessions, coding session waste patterns found
8. **📊 Metrics** — token efficiency score, comparison to previous audit, daily token burn estimate, top 5 most expensive sessions
9. **✅ Recommended Actions** — prioritized list with effort/impact estimates

### Step 4 — Archive to Notion

Save a structured report to Notion for historical tracking. Include:
- Audit date
- Efficiency score
- Top 3 findings
- Actions taken vs. deferred

### Step 5 — Self-Learning & Git Push

**At the end of every run**, check if anything new was learned:

- New optimization patterns discovered
- New constraints or workarounds found
- Updated metrics or baselines
- New skills/plugins/connectors added since last audit
- Corrected workflows or navigation tricks

**If anything was learned:**

1. Update this CLAUDE.md with the new information
2. Clone or pull the repo: `https://github.com/MSApps-Mobile/claude-plugins.git`
3. Copy updated files to `plugins/token-efficiency-audit/`
4. Commit with message: `chore: update CLAUDE.md — daily audit learnings YYYY-MM-DD`
5. Push to `main` branch

**Git commands:**
```bash
cd /tmp && git clone https://github.com/MSApps-Mobile/claude-plugins.git
cp /path/to/updated/CLAUDE.md claude-plugins/plugins/token-efficiency-audit/CLAUDE.md
cd claude-plugins
git add plugins/token-efficiency-audit/
git commit -m "chore: update CLAUDE.md — daily audit learnings YYYY-MM-DD"
git push origin main
```

**If nothing new was learned:** Skip the git push. Note "No new learnings" in the report.

---

## ⚠️ Git Push Rule — ALWAYS Push Changes

**Whenever ANY file in this plugin is modified — CLAUDE.md, any SKILL.md, references, config, or CONNECTORS.md — push to GitHub.**

This is not limited to self-learning. If the task modifies ANY local plugin file for ANY reason, it MUST push:

1. Clone: `cd /tmp && git clone https://github.com/MSApps-Mobile/claude-plugins.git`
2. Copy ALL changed files from the local plugin directory to `claude-plugins/plugins/token-efficiency-audit/`
3. Preserve the full directory structure (skills/, .claude-plugin/, references/, etc.)
4. Commit with descriptive message: `chore: <what changed> — YYYY-MM-DD`
5. Push to `main`

**Files to sync (always copy the full set if any changed):**
```
.claude/skills/token-efficiency-audit/CLAUDE.md                              → plugins/token-efficiency-audit/CLAUDE.md
.claude/skills/token-efficiency-audit/README.md                              → plugins/token-efficiency-audit/README.md
.claude/skills/token-efficiency-audit/CONNECTORS.md                          → plugins/token-efficiency-audit/CONNECTORS.md
.claude/skills/token-efficiency-audit/.claude-plugin/config.json             → plugins/token-efficiency-audit/.claude-plugin/config.json
.claude/skills/token-efficiency-audit/.claude-plugin/plugin.json             → plugins/token-efficiency-audit/.claude-plugin/plugin.json
.claude/skills/token-efficiency-audit/skills/token-efficiency-audit/SKILL.md → plugins/token-efficiency-audit/skills/token-efficiency-audit/SKILL.md
.claude/skills/token-efficiency-audit/skills/token-efficiency-audit/references/optimization-patterns.md → plugins/token-efficiency-audit/skills/token-efficiency-audit/references/optimization-patterns.md
.claude/skills/token-efficiency-audit/skills/token-efficiency-expert/SKILL.md → plugins/token-efficiency-audit/skills/token-efficiency-expert/SKILL.md
```

**If git push fails:** Save the full diff in the report and flag for Michal. Do NOT silently skip.

---

## Architecture

```
token-efficiency-audit/
├── .claude-plugin/
│   ├── config.json — metadata with SOSA level, impact, pillar details
│   └── plugin.json — plugin manifest
├── skills/
│   ├── token-efficiency-audit/
│   │   ├── SKILL.md — Main workflow (Plan→Act→Verify)
│   │   └── references/
│   │       └── optimization-patterns.md — O6 pattern catalog
│   └── token-efficiency-expert/
│       └── SKILL.md — Dr. Noa Reshef expert persona + Reshef Method™
├── CONNECTORS.md
├── CLAUDE.md ← this file (self-updating)
└── README.md
```

---

## SOSA Compliance — Level 3

- **Supervised**: Presents findings in report. High-impact changes (skill rewrites, task disabling) are flagged for Michal — never applied automatically.
- **Orchestrated**: Plan→Act→Verify execution loop. Parallel data gathering in Plan phase. Structured Notion output.
- **Secured**: Never touches credentials or .mcp.json. All changes logged in Notion audit report.
- **Agent**: Role = token optimization (O6 enforcement). Tools = scheduled-tasks MCP + session-info MCP + Desktop Commander + Notion + present_files.

---

## Autonomy Rules

**Do autonomously (no approval needed):**
- Read all skills, tasks, plugins, connectors
- List and read session transcripts (via `list_sessions` + `read_transcript`)
- Read scheduled task prompts (via Desktop Commander)
- Calculate token costs and efficiency scores
- Save audit report to workspace and Notion
- Update this CLAUDE.md with new learnings
- Push CLAUDE.md updates to GitHub

**Do NOT do autonomously:**
- Modify or delete any skill, task, or plugin
- Disconnect MCP connectors
- Change scheduled task frequencies
- Rewrite skill descriptions (flag for Michal instead)
- Kill or interfere with running sessions/processes
- Read transcripts of sessions marked private (if such a flag exists)

---

## Key References

| Item | Value |
|------|-------|
| GitHub repo | https://github.com/MSApps-Mobile/claude-plugins |
| Plugin path | plugins/token-efficiency-audit/ |
| Notion workspace | MSApps (search for "Token Audit" page) |
| Owner email | michal@msapps.mobi |
| SOSA dependency | sosa-compliance-checker → token-efficiency-audit |

---

## Scheduled Task Audit Rules

### What to Audit Per Task

For each task returned by `list_scheduled_tasks`:
1. **Read the prompt** — via Desktop Commander: `/Users/michalshatz/Documents/Claude/Scheduled/{taskId}/SKILL.md`
2. **Measure prompt token count** — estimate ~4 chars per token
3. **Check for waste patterns:**
   - Prompt >2000 tokens → flag as bloated, suggest compression (O6a)
   - Inline data tables in prompt → suggest externalizing to Notion (O6b)
   - Duplicated instructions across multiple tasks → suggest shared reference (O6a)
   - Task runs daily but does the same thing as another daily task → suggest consolidation (O6c)
   - Task enabled but never run → flag as zombie
   - Task disabled for >30 days with no recent use → suggest deletion
   - Description is empty, placeholder, or cryptic → flag for cleanup

### Known Overlap Groups (update as discovered)

These task groups have overlapping scope — audit for consolidation:

| Group | Tasks | Overlap |
|-------|-------|---------|
| LinkedIn outreach | `linkedin-outreach-messages`, `daily-linkedin-outreach`, `opsagent-linkedin-outreach`, `opsagent-outreach-daily` | 4 tasks doing LinkedIn outreach — likely consolidatable |
| Health checks | `zoho-mail-health-check`, `zoho-mail-connectors-test`, `gcal-connection-check`, `google-drive-health-check`, `gdrive-mcp-health-check`, `whatsapp-plugin-health-check`, `x-mcp-health-check`, `fix-chrome-connection` | 8 health check tasks — could be one daily health sweep |
| OpsAgent | `opsagent-startup`, `opsagent-deploy-landing-page`, `opsagent-interest-check`, `opsagent-lead-check` | 4 OpsAgent tasks with overlapping status checks |
| Disk/memory cleanup | `mac-memory-cleanup`, `mac-disk-cleanup`, `vm-disk-cleanup`, `smart-session-cache-flush`, `close-inactive-chrome-tabs` | 5 cleanup tasks — could be one weekly cleanup sweep |
| Lead pipeline | `lead-pipeline-daily`, `lead-followup-from-zoho`, `linkedin-lead-review`, `opsagent-lead-check` | 4 lead tasks with potential overlap |
| MCPs biz | `mcps-biz-gumroad-upload-reminder`, `mcps-biz-host-plugins-page`, `mcps-biz-setup-guide`, `weekly-plugin-sync`, `plugin-analytics-report` | 5 plugin-business tasks — some are stale one-offs |

### Dynamic Inventory — Rebuilt Every Run

⚠️ **Do NOT hardcode task lists.** Michal adds and removes tasks frequently. Every run must:

1. Call `list_scheduled_tasks` to get the **live** task list
2. Categorize each task dynamically:
   - **Recurring daily** — highest token cost, audit first
   - **Recurring weekly** — moderate cost
   - **Manual/ad-hoc enabled** — low recurring cost, but check for zombies
   - **Disabled** — zero cost, but flag for cleanup if stale >30 days
3. Compare to previous audit (from Notion or last report) to detect:
   - **New tasks** added since last audit → check if they follow O6 standards
   - **Removed tasks** → note in report (good — less token waste)
   - **Changed schedules** → verify the change makes sense
4. Report the live counts in the summary section of each audit report

### Overlap Detection Algorithm

Don't rely on a static list. Instead, for each run:
1. Group tasks by keyword similarity in their `taskId` and `description`
2. Flag groups of 2+ tasks with >60% keyword overlap
3. For flagged groups, read both SKILL.md prompts and check if they do the same thing
4. Recommend consolidation if confirmed

Known overlap patterns to watch for (evolves over time):
- Multiple outreach tasks (LinkedIn, OpsAgent, email)
- Multiple health-check tasks (could be one sweep)
- Multiple cleanup tasks (disk, memory, cache, tabs)
- Multiple lead/pipeline tasks

---

## Known Constraints

- Cannot write .skill files directly to Mac's `.claude/skills/` directory (read-only bindfs mount in Cowork VM). Uses `present_files` with .skill packaging instead.
- Cannot uninstall plugins or disconnect MCP servers programmatically — these are listed as manual items.
- Git push requires GitHub auth to be available in the session. If push fails, save the diff in the report and flag for Michal.

---

## Audit History

| Date | Score | Top Finding | Action |
|------|-------|-------------|--------|
| 2026-03-31 | 58/100 | 9am rate limit bomb (3 tasks collide); token-efficiency-audit runs 3×/day | Reported; Michal to fix cron + stagger |

---

## Self-Learning Log

### 2026-03-31

1. **Rate limit collision pattern** — When 3+ heavy tasks are scheduled within the same hour window (e.g., 09:03, 09:08, 09:10), tasks fail immediately with "You've hit your limit". Detect by checking if multiple tasks share the same clock-hour and flag as 🔴 High.

2. **token-efficiency-audit cron mismatch** — The cron `0 8,13,18 * * *` runs 3× per day, but CLAUDE.md says "daily at 08:00". Future audits should verify the cron matches stated frequency and flag mismatches.

3. **Task count growth** — 36 tasks on 03-29 → 48 tasks on 03-31 (+12 in 2 days). Report the delta since last audit. Flag if >5 new tasks in one day.

4. **Scheduled task SKILL.md read method** — The path `/Users/michalshatz/Documents/Claude/Scheduled/{taskId}/SKILL.md` does NOT exist on the filesystem. Task prompt content is embedded in each session's `<scheduled-task>` tag at runtime. To read a task's actual prompt: use `read_transcript` on its most recent session and extract the `<scheduled-task>` block from the user turn.

5. **Notion archiving structure** — Parent audit page ID: `33238b5d-fb27-8156-a300-f3636125a1d4`. Create each run's audit as a child page under this parent.

6. **Regression tracking** — Several 03-29 fixes reverted by 03-31: receipts-collection back to daily (was 2×/week), Monday.com MCP still connected. Always compare to prior audit and flag regressions explicitly.

7. **LinkedIn session auth** — linkedin-outreach-messages frequently fails due to LinkedIn device verification (requires manual tap in LinkedIn app). This is a recurring partial-completion pattern, not a task design flaw. Flag as 🟡 Moderate.

8. **MCP tool counts (confirmed)** — Monday.com: ~40 tools. ZohoCliq (from 03-29): ~120 tools. Desktop Commander: ~20 tools. Notion: 14 tools. Each tool ≈ 50-70 tokens in system prompt.
