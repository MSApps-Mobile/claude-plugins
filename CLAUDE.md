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
