# SOSA™ Personalization — MSApps 4-Tier Architecture

Custom SOSA enforcement rules for the MSApps plugin ecosystem.

---

## Tier Architecture

| Tier | Repo | Visibility | Rule |
|------|------|-----------|------|
| 🟢 1 | `MSApps-Mobile/claude-plugins` | PUBLIC | Zero PII. Zero secrets. Env vars only. SOSA level required. |
| 🟡 2 | `MSApps-Mobile/msapps-skills-agents` | PRIVATE (team) | Company-wide only. No plugins. No agents. No personal data. |
| 🔴 3 | `MSApps-Mobile/claude-private-skills` | PRIVATE (Michal) | Personal plugins, skills, scheduled tasks. May contain PII. |
| 🟣 4 | `MSApps-Mobile/opsagent-outreach` | PRIVATE (Michal) | OpsAgent product. Separate roadmap. |

---

## Tier 1 — Public Marketplace Rules

### MUST
- Every plugin has a `SOSA.level` in plugin.json or config.json
- Every plugin has a `SKILL.md` with role spec
- Every plugin has a `README.md`
- All credentials use environment variable placeholders (`${VAR_NAME}`)
- `.mcp.json` uses `${PLACEHOLDER}` syntax, never real values

### MUST NOT
- Hardcoded API keys, OAuth secrets, refresh tokens, or passwords
- Personal phone numbers, Notion DB IDs, or folder IDs
- Personal email addresses in skill logic (OK in README author/contact section)
- References to internal MSApps business processes
- OpsAgent-specific content
- Personal outreach templates (Hebrew or English)
- Any content from Tier 2, 3, or 4

### Pre-Push Checklist
```bash
# Run before every push to claude-plugins:
./scripts/sosa-lint.sh .

# Additional manual checks:
grep -rn "054-\|054[0-9]\{7\}\|972-54" plugins/
grep -rn "client_secret.*[0-9a-f]\{20\}" plugins/
grep -rn "collection://\|notion_db\|notion.*parent.*[0-9a-f-]\{36\}" plugins/
grep -rn "refresh_token.*1000\." plugins/
```

---

## Tier 2 — MSApps Team Rules

### Contains ONLY
- Company-wide skills (utilities, health checks)
- Company-wide scheduled tasks (backups, monitoring, maintenance)
- Company scripts and docs

### MUST NOT contain
- Plugin folders (those are in Tier 1)
- .plugin bundle files (those are in Tier 1)
- Agent folders (OpsAgent → Tier 4)
- Personal skills (Michal's outreach, researcher, etc. → Tier 3)
- Personal scheduled tasks (leads, invoicing, receipts → Tier 3)
- OpsAgent scheduled tasks → Tier 4 or Tier 3

---

## Tier 3 — Michal Only Rules

### OK to contain
- Personal data (phone numbers, Notion IDs, personal templates)
- Customized plugin versions with personal config
- Personal outreach templates and workflows
- Personal scheduled tasks
- OpsAgent personal scheduled tasks (since only Michal runs them)

### MUST NOT
- Be shared with MSApps employees
- Be referenced from Tier 1 or Tier 2 repos

---

## Tier 4 — OpsAgent Rules

### Contains
- OpsAgent product code (agents framework, dashboard, CLI)
- OpsAgent outreach skills
- Client configs and templates
- Landing pages and marketing assets

### MUST NOT
- Live in msapps-skills-agents (Tier 2)
- Be in the public marketplace (Tier 1) — OpsAgent is a separate product

---

## Cross-Tier Movement Policy

| From → To | Allowed? | Condition |
|-----------|----------|-----------|
| Any → Tier 1 | ✅ | Must pass SOSA lint + secret scan + PII check |
| Tier 1 → Tier 2 | ❌ | No duplicates — team uses the public repo |
| Tier 3 → Tier 2 | ❌ | Personal content never goes to team repo |
| Tier 4 → Tier 2 | ❌ | OpsAgent is separate from MSApps |
| Tier 1 → Tier 3/4 | ❌ | Public plugins don't need private copies |
| Tier 3 ↔ Tier 4 | ⚠️ | Only personal OpsAgent tasks can live in Tier 3 |

---

## SOSA Level Requirements by Tier

| Tier | SOSA Required? | Minimum Level |
|------|---------------|--------------|
| 🟢 1 (Public) | **YES** | L1+ (declared in plugin.json) |
| 🟡 2 (Team) | Recommended | No minimum |
| 🔴 3 (Michal) | No | N/A |
| 🟣 4 (OpsAgent) | Recommended | No minimum (product-stage dependent) |

---

## Reference

- Notion tracking page: https://www.notion.so/33238b5dfb2781a3bd12e7a94f462f67
- SOSA methodology: `docs/SOSA.md`
- SOSA enforcement: `docs/SOSA-ENFORCEMENT.md`
- SOSA whitepaper: Shatz, 2026
