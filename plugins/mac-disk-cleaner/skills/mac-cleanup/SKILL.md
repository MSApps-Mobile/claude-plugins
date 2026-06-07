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

## Phase 6 — Reclaiming large items & "junk" folders safely (only if the user asks)

Phase 4 only *flags* large items. If the user asks you to actually remove them, follow these rules — they prevent irreversible mistakes that have bitten this skill in real runs.

### Move to Trash, don't `rm` — and know the Trash mechanics

- Move user files/folders to Trash (`mv "<item>" ~/.Trash/`) rather than `rm -rf`. This stays reversible (Finder → "Put Back") until the Trash is emptied.
- **Space is NOT reclaimed until the Trash is emptied.** `df` will show no gain after a `mv` to Trash — don't report freed space until after emptying.
- **`~/.Trash` is TCC-protected.** `rm -rf ~/.Trash/*` fails with `Operation not permitted` from a sandboxed shell, and the glob silently matches nothing (looks like success but isn't). Empty it through Finder instead:
  ```bash
  osascript -e 'tell application "Finder" to empty trash'
  ```
- If that returns error `-128` (a confirmation dialog or a locked item blocked it), disable the warning and retry:
  ```bash
  osascript -e 'tell application "Finder"' \
            -e 'set warns before emptying of trash to false' \
            -e 'empty trash' \
            -e 'set warns before emptying of trash to true' \
            -e 'end tell'
  ```
- Emptying the Trash is irreversible — confirm with the user first, and make sure irreplaceable personal files (videos, photos) are backed up before emptying.

### "Looks like junk" ≠ "is junk" — git-safety check before deleting a dev folder

A folder full of old project checkouts can still hold local-only work that exists **nowhere else**. Before deleting any folder containing code, check every git repo inside it:

```bash
cd "<folder>"
for d in */; do
  if [ -d "$d/.git" ]; then
    (cd "$d"; echo "$d → uncommitted=$(git status -s | wc -l | tr -d ' ') unpushed=$(git log --branches --not --remotes --oneline | wc -l | tr -d ' ')")
  fi
done
git -C "<folder>" status -s 2>/dev/null   # check the folder itself if it is a repo
```

- Repos with `uncommitted=0` and `unpushed=0` are safe — fully on the remote, re-cloneable.
- "Unpushed" commits are often **already on the remote under a different SHA** (squash-merge). Verify by commit message against `origin/<branch>` before assuming work is at risk — don't force-push to "rescue" them.
- For repos with genuine uncommitted/unpushed work, **rescue the deltas first** (usually a few KB) into a safe folder before deleting:
  ```bash
  git diff HEAD > rescue/<repo>-changes.diff                                  # tracked edits
  git ls-files --others --exclude-standard | grep -viE '\.(swp|zip)$|node_modules/' \
    | while read -r f; do mkdir -p "rescue/<repo>/$(dirname "$f")"; cp -p "$f" "rescue/<repo>/$f"; done
  git format-patch origin/<branch>..HEAD --stdout > rescue/<repo>-commits.patch  # local-only commits
  ```

Only after the rescue bundle is verified should the folder be moved to Trash and the space reclaimed.

---

⭐ *If this skill freed up space for you, [star the repo](https://github.com/MSApps-Mobile/claude-plugins) — it helps other devs find the marketplace.*
