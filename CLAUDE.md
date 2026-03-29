# CLAUDE.md — claude-plugins

Developer notes for the MSApps Claude Plugins repository.

---

## Repo Structure

```
plugins/
  {plugin-name}/
    README.md
    CONNECTORS.md
    skills/{skill-name}/
      SKILL.md
      references/
    commands/
      {command}.md
```

---

## Known Issues & Fixes

### session-backup: VM Proxy Blocks Google Drive Uploads

**Problem:** The Cowork VM proxy blocks outbound connections to `script.google.com`. Running `curl` or `requests` from inside the VM to the Google Apps Script upload endpoint fails with `403 Forbidden / X-Proxy-Error: blocked-by-allowlist`.

**Fix (as of 2026-03-27):** Upload must run on the Mac side via **Desktop Commander**:
1. Copy zip files from `/tmp/cowork-backup/` to `{SESSION_MNT}/Claude/.backup-tmp/` (mounted Mac folder)
2. Write a Python upload script to the staging dir
3. Use `mcp__Desktop_Commander__start_process` to run `python3 ~/Documents/Claude/.backup-tmp/do_upload.py` on the Mac
4. Clean up staging dir after upload

See `plugins/session-backup/skills/session-backup/SKILL.md` Step 4 for full implementation.

### session-backup: Hardcoded Session Paths Break Between Runs

**Problem:** Cowork VM session names (e.g. `loving-gracious-allen`, `modest-sleepy-carson`) are randomly generated and change with every new session. Any hardcoded path like `/sessions/loving-gracious-allen/mnt/...` will fail in a different session.

**Fix (as of 2026-03-27):** Always discover the active session dynamically:
```python
import glob
candidates = glob.glob('/sessions/*/mnt/Claude/credentials/cowork-gdrive-config.json')
session_mnt = candidates[0].replace('/Claude/credentials/cowork-gdrive-config.json', '')
```

**Rule:** Never hardcode a session name in any skill or scheduled task prompt.

---

## Deployment

Plugins are published via:
- **GitHub**: `MSApps-Mobile/claude-plugins` (this repo)
- **Marketplace**: Listed in Anthropic Claude plugin marketplace
- **Gumroad**: Premium versions sold at msapps.mobi

To install from this repo in Cowork:
> Settings → Plugins → Marketplaces → Add → `MSApps-Mobile/claude-plugins`

---

## Contact

**Owner:** Michal Shatz — michal@msapps.mobi — [msapps.mobi](https://msapps.mobi)

---

## Notion Public Page Protection Rule

**CRITICAL — All sessions MUST follow these rules when writing to Notion:**

### Public Pages (shared to web)
The ONLY Notion pages that are publicly accessible are under the **"MSApps - משרות פתוחות"** job listing page (`31438b5d-fb27-80c3-b25b-e24f6cc7d4b0`) and its child MSA-### job posting pages.

### What MUST NEVER appear on public job pages
- Candidate names, emails, phone numbers, or any PII
- Salary expectations or rate information
- Interview notes, test scores, or assessment results
- Client company names (use generic descriptions like "Fintech company" instead)
- Partner/reseller names (Aman, Comm-IT, Milla, Commit, etc.)
- Internal status tracking (candidate pipeline status)
- Links to internal tools or dashboards

### Where candidate tracking data goes
All candidate tracking, interview notes, and recruitment status MUST be stored in private Notion pages only — never on any page under "משרות פתוחות".

### Before writing to ANY Notion page
1. Check if the page is a child of "MSApps - משרות פתוחות" (`31438b5d-fb27-80c3`)
2. If YES → treat as PUBLIC. Do NOT write any sensitive data. Warn the user if they ask you to.
3. If NO → treat as private workspace page (normal rules apply)

### Credential Storage
NEVER store credentials (API keys, tokens, passwords, OAuth secrets) in Notion pages. Direct users to use a password manager instead. If you encounter credentials in Notion during any task, warn the user.

### Weekly Audit
A scheduled task runs weekly to scan all public job pages for sensitive data leaks. See scheduled task: `notion-public-page-audit`.
