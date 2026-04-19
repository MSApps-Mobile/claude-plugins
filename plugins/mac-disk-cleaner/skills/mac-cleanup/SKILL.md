# Mac Disk Cleanup

Clean up safe Mac cache locations, report how much space was freed, and flag any oversized folders worth reviewing manually.

Use this skill when the user says things like: "clean my Mac", "free up disk space", "clear cache", "my Mac is slow", "running out of space", "Mac cleanup", "disk cleanup", "tidy up my Mac", "ניקוי מק", "פנה מקום", "המק שלי מלא", "nettoyage Mac", "limpiar Mac", or any similar request about freeing storage on a Mac.

Also runs automatically when triggered as a scheduled task.

---

## How to run this skill

Work through each phase in order. Communicate with the user in whatever language they used.

> **Environment note:** This skill works in both Claude Code (native Bash tool) and Cowork (Desktop Commander). Use whichever shell execution method is available in your environment to run the bash commands below.

---

## Phase 1 — Measure before

Run these two commands and record the results:

```bash
df -h / | tail -1
```

```bash
du -sh \
  ~/Library/Caches/Google/ \
  ~/Library/Caches/pip/ \
  ~/Library/Caches/node-gyp/ \
  ~/Library/Caches/org.swift.swiftpm/ \
  ~/.gradle/caches/ \
  ~/Library/Caches/Homebrew/ \
  2>/dev/null
```

Note the "Avail" column from `df` as **before_avail** and record each cache size.

---

## Phase 2 — Clean

Run each command. If a command fails (permission denied, not found), note it and continue — do not abort.

```bash
# Google Chrome disk cache (passwords/history/bookmarks are in Application Support, NOT here — safe to delete)
rm -rf ~/Library/Caches/Google/ 2>/dev/null; true
```

```bash
# npm cache
npm cache clean --force 2>/dev/null; true
```

```bash
# Yarn cache
yarn cache clean 2>/dev/null; true
```

```bash
# pip cache
rm -rf ~/Library/Caches/pip/ 2>/dev/null; true
```

```bash
# Swift Package Manager cache (auto-regenerated on next build)
rm -rf ~/Library/Caches/org.swift.swiftpm/ 2>/dev/null; true
```

```bash
# Gradle caches (auto-regenerated on next build)
rm -rf ~/.gradle/caches/ 2>/dev/null; true
```

```bash
# Homebrew — prefer brew cleanup, fall back to rm
brew cleanup 2>/dev/null || rm -rf ~/Library/Caches/Homebrew/ 2>/dev/null; true
```

**Do NOT touch:**
- `~/Library/Application Support/Google/Chrome` — contains passwords, history, bookmarks
- `~/Documents`, `~/Desktop`, `~/Downloads` (contents — only scan, never delete)
- Any system-protected directory under `/System` or `/Library`
- Mail data, iCloud sync folders

---

## Phase 3 — Measure after

```bash
df -h / | tail -1
```

Capture the new "Avail" value as **after_avail**. Calculate freed = after_avail − before_avail.

---

## Phase 4 — Scan for large items

Run these to find large items the user may want to handle manually:

```bash
du -sh ~/Desktop ~/Downloads ~/Documents 2>/dev/null
```

```bash
# Top 10 largest items on Desktop
du -sh ~/Desktop/* 2>/dev/null | sort -rh | head -10
```

```bash
# Top 10 largest items in Downloads
du -sh ~/Downloads/* 2>/dev/null | sort -rh | head -10
```

If any folder or file exceeds **3 GB**, flag it as worth reviewing. Do not delete anything — only inform.

---

## Phase 5 — Report

Present a clean summary in the user's language. Include:

1. **Disk space freed** — before vs after (e.g. "181 GB → 187 GB available, ~6 GB freed")
2. **Cache breakdown table** — what was cleaned and approximate size
3. **Any errors** — caches that couldn't be cleaned and why (e.g. "node-gyp: permission denied — can be removed with sudo if needed")
4. **Large items flagged** — any Desktop/Downloads items over 3 GB, with a suggestion (e.g. iCloud Drive, external drive)

Keep the report concise. Do not overwhelm — surface the most actionable items only.

See `references/safe-cache-locations.md` for the full list of Mac cache locations and what's safe to delete.

---

⭐ *If this skill freed up space for you, [star the repo](https://github.com/MSApps-Mobile/claude-plugins) — it helps other devs find the marketplace.*
