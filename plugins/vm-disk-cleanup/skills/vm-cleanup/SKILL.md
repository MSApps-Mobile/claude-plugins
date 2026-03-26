---
name: vm-cleanup
description: >
  Clean up disk space in the Claude working environment (Cowork session VM
  or Claude Code sandbox). Use this skill when the user says "clean VM",
  "clean disk", "free disk space", "disk full", "ENOSPC", "no space left",
  "clean session", "session cleanup", "disk cleanup", or when Bash commands
  fail with disk-full errors. Also use proactively before heavy operations
  like npm install or pip install in long sessions.
metadata:
  version: "0.1.0"
  platforms: ["claude-code", "cowork"]
---

# VM / Session Disk Cleanup

Recover from or prevent disk-full situations in Claude's working environment.

## Context

Both Cowork session VMs and Claude Code sandboxes have limited disk space.
Long sessions with package installs, builds, and cached data can fill the
disk completely. When full, ALL Bash commands fail with ENOSPC errors
because the shell can't create temp files — a deadlock where you can't
even diagnose the problem.

## Cleanup Strategy

Run cleanups in phases — smallest operations first so they succeed even
when disk is critically low.

### Phase 1: Emergency (needs almost zero free space)
Run these first when disk is completely full or nearly full:

```bash
# Remove Python bytecode (tiny files, frees inodes)
find /sessions -name __pycache__ -type d -exec rm -rf {} + 2>/dev/null
find /sessions -name "*.pyc" -delete 2>/dev/null
find . -name __pycache__ -type d -exec rm -rf {} + 2>/dev/null
```

```bash
# Clear temp files
rm -rf /tmp/*.tmp /tmp/*.log /tmp/tmp* /tmp/pip-* /tmp/npm-* 2>/dev/null
```

```bash
# Clear apt/package manager cache
rm -rf /var/cache/apt/archives/*.deb 2>/dev/null
apt-get clean 2>/dev/null
```

### Phase 2: Medium cleanup (clear package caches)

```bash
# Clear pip cache
pip cache purge 2>/dev/null
rm -rf ~/.cache/pip 2>/dev/null
```

```bash
# Clear npm cache
npm cache clean --force 2>/dev/null
rm -rf ~/.npm/_cacache 2>/dev/null
```

### Phase 3: Heavy cleanup (removes reinstallable items)

```bash
# Remove node_modules (recreate with npm install)
find /sessions -name "node_modules" -type d -exec rm -rf {} + 2>/dev/null
find . -name "node_modules" -type d -exec rm -rf {} + 2>/dev/null
```
```bash
# Remove build artifacts (recreate with build command)
find /sessions \( -name ".next" -o -name "dist" -o -name "build" \) -type d -exec rm -rf {} + 2>/dev/null
find . \( -name ".next" -o -name "dist" -o -name "build" \) -type d -exec rm -rf {} + 2>/dev/null
```

```bash
# Remove global npm packages
rm -rf ~/.npm-global/lib/node_modules/* 2>/dev/null
```

## Execution Steps

1. Check current disk usage: `df -h /`
2. Run Phase 1 commands (always)
3. Check if space was freed — if yes and enough, stop here
4. Run Phase 2 commands
5. Run Phase 3 commands if more space is still needed
6. Final disk check: `df -h /`
7. Report before/after free space to the user
8. If disk was over 80% full, recommend running this at session start

## When Disk Is Completely Full (Deadlock)

If even Phase 1 Bash commands fail with ENOSPC:

**In Cowork:** MCP-based tools (Notion, Gmail, Calendar, WhatsApp, Apollo,
Desktop Commander) still work since they don't need local disk. Suggest the
user start a new session — the VM resets automatically.

**In Claude Code:** Suggest the user exit and restart Claude Code. The
sandbox environment resets on restart.

## Prevention Tips

Share these with the user when relevant:
- Run cleanup before heavy installs (`npm install`, `pip install`, `apt install`)
- Use `pip install --no-cache-dir` to avoid caching
- Remove `node_modules` from old projects before starting new ones
- For recurring maintenance, pair with a scheduled task that runs every 2 hours