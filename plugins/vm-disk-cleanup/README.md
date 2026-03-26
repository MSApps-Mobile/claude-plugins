# VM Disk Cleanup

Prevent and recover from disk-full errors in Claude's working environment — both **Cowork** session VMs and **Claude Code** sandboxes.

## The Problem

Long Claude sessions accumulate disk-eating artifacts: npm/pip caches, `node_modules`, Python bytecode, build outputs, and temp files. When the disk fills completely, even basic Bash commands fail with `ENOSPC` errors — creating a deadlock where you can't diagnose or fix the problem.

## What It Does

A 3-phase cleanup that starts with the lightest operations (so they work even when disk is nearly full) and escalates:

| Phase | What it clears | Disk needed |
|-------|---------------|-------------|
| **1 — Emergency** | Python bytecode, temp files, apt cache | Almost zero |
| **2 — Medium** | pip cache, npm cache | Minimal |
| **3 — Heavy** | node_modules, build artifacts, global packages | Some free space |

## Installation

### Claude Code (CLI)

```bash
/plugin marketplace add MSApps-Mobile/claude-plugins
/plugin install vm-disk-cleanup@msapps-plugins
```

### Cowork (Desktop App)

Go to **Settings → Plugins**, search for **vm-disk-cleanup**, and click Install.
## Usage

Just say any of these naturally:

- "clean VM" / "clean disk"
- "disk full" / "no space left"
- "free disk space"
- "session cleanup"

The skill also activates automatically when it detects ENOSPC errors in Bash output.

### Pro tip: Pair with a scheduled task

In **Cowork**, you can set up a scheduled task that runs cleanup every 2 hours to prevent disk-full situations before they happen. Ask Claude: *"Create a scheduled task to clean the VM disk every 2 hours"*.

## Setup

No configuration needed. Works out of the box on both platforms.

## Requirements

- **Cowork**: Any session (Linux VM with Bash)
- **Claude Code**: Any environment with Bash access

## License

MIT — Free to use and modify.