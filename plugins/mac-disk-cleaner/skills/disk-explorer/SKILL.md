# Disk Explorer

Explore what's taking up space on the Mac and give the user actionable recommendations.

Use this skill when the user asks things like: "what's taking up space?", "where is my disk space going?", "show me large files", "what can I delete?", "why is my Mac full?", "explore my disk", "מה תופס מקום?", "מה אפשר למחוק?", "qu'est-ce qui prend de la place?", "¿qué ocupa espacio?", or any question about understanding disk usage without necessarily cleaning yet.

---

## How to run this skill

Run the commands below, analyze the output, and respond in the user's language with clear, prioritized recommendations.

---

## Step 1 — Overall disk usage

```bash
df -h / | tail -1
```

Report total disk size, how much is used, and how much is free.

---

## Step 2 — Top-level home folder sizes

```bash
du -sh ~/* 2>/dev/null | sort -rh | head -15
```

Identify which top-level folders in the home directory are largest.

---

## Step 3 — Known large locations

Check these locations — they are commonly large and often overlooked:

```bash
du -sh \
  ~/Desktop \
  ~/Downloads \
  ~/Documents \
  ~/Movies \
  ~/Music \
  ~/Library/Developer \
  ~/Library/Application\ Support \
  ~/Library/Caches \
  2>/dev/null | sort -rh
```

---

## Step 4 — Developer-specific large locations (only if ~/Library/Developer exists)

```bash
du -sh \
  ~/Library/Developer/Xcode/DerivedData \
  ~/Library/Developer/CoreSimulator/Devices \
  ~/Library/Developer/Xcode/iOS\ DeviceSupport \
  2>/dev/null | sort -rh
```

---

## Step 5 — Find large files (>500 MB) anywhere in home

```bash
find ~ -maxdepth 6 -size +500M -not -path "*/.*" 2>/dev/null | while read f; do du -sh "$f" 2>/dev/null; done | sort -rh | head -20
```

---

## Step 6 — Look for common storage wasters

```bash
# ZIP files next to folders with the same name (often redundant)
find ~/Desktop ~/Downloads ~/Documents -maxdepth 2 -name "*.zip" 2>/dev/null

# Old iOS backups
du -sh ~/Library/Application\ Support/MobileSync/Backup/ 2>/dev/null

# Trash
du -sh ~/.Trash/ 2>/dev/null
```

---

## Report

Present findings clearly in the user's language, organized by priority:

### 1. Quick wins (safe to clean now)
Items that are clearly redundant or cache-only — e.g. ZIP files next to extracted folders, cache folders, old iOS backups.

### 2. Review recommended (user decides)
Large folders that require user judgment — Downloads, old projects, Movies, iOS device support files.

### 3. Developer bloat (if applicable)
Xcode DerivedData, simulators, device support — large but safe to delete if not actively needed.

### 4. Already optimized
If the disk looks clean, say so clearly. Don't invent problems.

---

## Offer next steps

After the report, offer:
- "I can run a full cleanup now" → triggers the mac-cleanup skill
- "I can help you move large files to cloud storage" → guide the user to iCloud Drive or another service
- "I can set up a weekly automated cleanup" → suggest scheduling

Do not delete anything in this skill. Only analyze and recommend.
