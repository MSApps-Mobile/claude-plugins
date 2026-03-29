# VM Disk Cleanup

Prevent and recover from disk-full errors in Cowork VMs and Claude Code sandboxes. Automatically or manually trigger multi-phase cleanup to free up space.

## Available Tools/Skills

- **Clean Disk**: Manually trigger cleanup process
- **Auto-Cleanup**: Automatically activates on ENOSPC (No Space Left) errors
- **Scheduled Cleanup**: Set recurring cleanup intervals (e.g., every 2 hours)

## Cleanup Phases

1. **Phase 1 (Emergency)**: Targets immediate wins
   - Python bytecode files (.pyc, __pycache__)
   - Temporary system files (/tmp, /var/tmp)
   - APT package cache

2. **Phase 2 (Medium)**: Frees development tool caches
   - pip package cache
   - npm package cache
   - Other package manager caches

3. **Phase 3 (Heavy)**: Removes large artifacts
   - node_modules directories
   - Build artifacts and compiled files
   - Global package installations

## Configuration

- Requires Bash access to the VM or sandbox
- Auto-activates when ENOSPC errors occur during operations
- Can be manually triggered at any time

## Common Workflows

- **"clean VM"** - Trigger manual cleanup
- **"clean disk"** - Same as above
- **"disk full"** - Auto-cleanup when space runs out
- **"no space left"** - Triggered automatically
- **"free disk space"** - Manual trigger
- **Schedule cleanup every 2 hours** - Set recurring cleanup

## Best Practices

- Run Phase 1 cleanup regularly to prevent emergencies
- Monitor disk usage, especially in sandboxes with large dependency installations
- Use scheduled cleanup in long-running sessions with frequent builds
- Phase 3 cleanup will require reinstalling dependencies; use cautiously in production
- Allows other operations to continue uninterrupted when auto-activated

**Role:** Safely clean up disk space in Cowork VM environments by identifying and removing cache files, build artifacts, and temporary data.
**Impact Level:** Medium (deletes files)
**Approval Gates:** Confirm with user before deleting files larger than 100MB.
