---
name: sosa-audit
description: >
  Run a SOSA™ compliance audit on all installed Claude plugins and skills.
  Use this skill when the user says "SOSA audit", "SOSA check", "compliance check",
  "check SOSA compliance", "run SOSA scan", "security compliance", "are my plugins SOSA compliant",
  "plugin governance check", "audit my skills", or any request to evaluate plugin/skill compliance
  against the SOSA methodology. Also trigger on "check my agents", "agent governance",
  or "supervision audit".
metadata:
  version: "0.1.0"
  author: "MSApps"
  framework: "SOSA™ — Supervised Orchestrated Secured Agents"
---

# SOSA™ Compliance Audit

Scan all installed plugins and skills against the four SOSA pillars and generate a compliance report with actionable fix suggestions.

Read the full checklist from `references/sosa-checklist.md` before starting the audit.

## Audit Workflow

### Step 1: Discover all plugins and skills

Scan these locations to find every installed plugin and skill:

```
# Installed plugins (marketplace + custom)
~/.claude/plugins/marketplaces/*/plugins/*/
~/.claude/plugins/custom/*/

# Remote plugins (Cowork sessions)
/sessions/*/mnt/.remote-plugins/plugin_*/

# Local skills
~/.claude/skills/*/
~/Documents/Claude/skills/*/

# Scheduled tasks
~/.claude/scheduled-tasks/*/
~/Documents/Claude/Scheduled/*/
```

For each discovered component, read:
- `SKILL.md` (or `CLAUDE.md`) — the main skill definition
- `.claude-plugin/plugin.json` — plugin manifest (if exists)
- `.mcp.json` — MCP server config (if exists)

Build a registry of all components found with their paths.

### Step 2: Run the four-pillar check

For EACH component, evaluate against all four SOSA pillars using the checklist in `references/sosa-checklist.md`. Score each pillar as:

- **PASS** — Fully compliant
- **PARTIAL** — Some requirements met, gaps identified
- **FAIL** — Critical requirements missing
- **N/A** — Pillar not applicable (e.g., Orchestrated for a standalone formatter)

#### Pillar 1: Supervised

Scan the SKILL.md for:
- Presence of "do not ask", "don't ask", "no confirmation", "אין לשאול", "ללא אישור" patterns → **FLAG** as missing supervision gate
- Impact classification: Does the skill send emails, messages, modify calendars, make API calls, or handle financial data? If yes, check for human-in-the-loop checkpoints
- Trust gradient: Does the skill differentiate between first-time and repeat actions?

**Score logic:**
- PASS: Low-impact skill OR has explicit confirmation/approval gates for high-impact actions
- PARTIAL: Medium-impact with some oversight but missing gates on certain actions
- FAIL: High-impact actions with explicit "no confirmation" instructions

#### Pillar 2: Orchestrated

Scan for:
- Structured outputs (JSON, structured reports) vs free-text handoffs
- Dependencies on other skills or external data declared
- Plan → Act → Verify pattern in the workflow
- Context sharing mechanism (Notion, shared files, structured registries)

**Score logic:**
- PASS: Follows Plan→Act→Verify, declares dependencies, uses structured context
- PARTIAL: Has structured outputs but no explicit verification step
- FAIL: Fire-and-forget execution with no verification or coordination

#### Pillar 3: Secured

Scan for:
- Hardcoded credentials (API keys, tokens, passwords, URLs with keys)
- Credential patterns: look for strings matching API key formats, base64 tokens, OAuth tokens
- Use of environment variables or config files for secrets
- Prompt injection scanning on external data inputs
- Package version pinning (in .mcp.json: check if uvx/npx args include version pins)
- Capability scoping (does the skill access only what it needs?)

**Score logic:**
- PASS: No hardcoded secrets, uses env vars/config files, has injection scanning, pinned versions
- PARTIAL: No hardcoded secrets but missing injection scanning or version pinning
- FAIL: Contains hardcoded credentials OR processes external data without injection scanning

#### Pillar 4: Agents

Scan for:
- Role specification: Does SKILL.md clearly define domain boundaries and what the skill should NOT do?
- Tool manifest: Does the plugin declare which tools/APIs it accesses?
- Memory model: Is persistence mechanism defined?
- Planning policy: Are steps defined with preconditions and postconditions?

**Score logic:**
- PASS: Clear R, T, M, P defined; domain boundaries explicit; tool access declared
- PARTIAL: Has role spec and workflow but missing explicit boundaries or tool declarations
- FAIL: No clear role boundaries; skill could be redirected to arbitrary domains

### Step 3: Calculate compliance level

Based on pillar scores, assign overall SOSA compliance level:

- **Level 3 (Full)** — All four pillars PASS
- **Level 2 (Standard)** — Secured PASS + at least 2 other pillars PASS, no FAIL
- **Level 1 (Basic)** — Secured PASS or PARTIAL, no more than 1 FAIL
- **Non-compliant** — Secured FAIL, or 2+ pillars FAIL

### Step 4: Generate the report

Produce a structured report with:

#### Summary Table

| Plugin/Skill | Supervised | Orchestrated | Secured | Agents | Level | Priority Fixes |
|-------------|-----------|-------------|---------|--------|-------|---------------|

Use these emoji indicators: ✅ PASS, ⚠️ PARTIAL, ❌ FAIL, ➖ N/A

#### Per-Component Details

For each component that is not fully Level 3, provide:

1. **Current state** — What was found
2. **Gap** — What SOSA requires
3. **Fix** — Specific, actionable instruction to reach compliance
4. **Priority** — Critical / High / Medium / Low
5. **Effort** — Quick fix (< 5 min) / Moderate (< 30 min) / Significant (> 30 min)

#### Fix priority matrix:
- **Critical**: Hardcoded credentials, no injection scanning on external data
- **High**: Missing supervision gates on high-impact actions, unpinned package versions
- **Medium**: Missing verification steps, no structured outputs, weak role boundaries
- **Low**: Missing metadata, informal context sharing, no trust gradient

### Step 5: Offer to fix

After presenting the report, offer to implement the fixes:

1. **Quick wins** — Fixes that can be applied immediately (metadata updates, adding SOSA blocks to plugin.json)
2. **Skill patches** — Adding prompt injection scanning blocks, supervision gates, verification steps to SKILL.md files
3. **Architecture changes** — Adding structured context registries, implementing trust gradients (requires discussion)

Ask which fixes to apply. For each approved fix, make the change and verify it.

## Important Rules

- This is a READ-ONLY audit. Never modify files without explicit user approval.
- Scan ALL components, not just a sample. Completeness matters.
- Be honest about compliance gaps — don't inflate scores.
- When in doubt about impact level, classify higher (err on the side of caution).
- Reference specific line numbers and patterns when reporting findings.
- The audit itself should follow SOSA: Plan (discover) → Act (scan) → Verify (cross-check findings).
