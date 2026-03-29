# Error Patterns Reference

Detailed catalog of all known error variants for the stuck Cowork session bug.
Use this to match user-reported errors to the correct fix tier.

## Category 1: Orphaned Process (Most Common)

**Pattern:** The VM thinks a previous process is still running.

### Exact Error Strings

```
RPC error: process with name "SESSION_NAME" already running (id: UUID)
```

```
RPC error -1: process with name "SESSION_NAME" already running (id: UUID)
```

**Matching regex:**
```
RPC error.*process with name.*already running
```

**Fix:** Start at Tier 2 (graceful cleanup). Usually resolved by killing the orphaned process.

### Real Examples from GitHub

```
RPC error: process with name "optimistic-stoic-knuth" already running
  (id: 7e090cc5-e7be-48f8-9d10-9c2ba4c167af)
```

```
RPC error -1: process with name 'blissful-sharp-gates' already running
  (id: fe1af3ed-5734-4202-8992-8c8b7d1491d7)
```

```
RPC error -1: process with name 'clever-keen-darwin' already running
  (id: 6cd82532-196c-4a0a-80b3-757ecfa03eb9)
```

```
RPC error -1: process with name 'sleepy-blissful-hamilton' already running
```

---

## Category 2: Missing Session Directory

**Pattern:** The session user entry exists but its home directory is gone.

### Exact Error Strings

```
RPC error: ensure user: user SESSION_NAME should already exist but does not,
and recovery failed: home directory /sessions/SESSION_NAME does not exist:
stat /sessions/SESSION_NAME: no such file or directory
```

**Matching regex:**
```
ensure user.*should already exist.*does not
```

**Fix:** Start at Tier 4 (cache & state cleanup). The session directory needs to be recreated
or the stale user entry removed.

### Real Examples

```
RPC error: ensure user: user optimistic-tender-pasteur should already exist
but does not, and recovery failed: home directory /sessions/optimistic-tender-pasteur
does not exist: stat /sessions/optimistic-tender-pasteur: no such file or directory
```

```
RPC error: ensure user: user confident-fervent-rubin should already exist
but does not, and recovery failed: home directory /sessions/confident-fervent-rubin
does not exist
```

---

## Category 3: Connection Aborted (Precursor)

**Pattern:** The VM connection drops, which then leads to Category 1 on the next attempt.

### Exact Error Strings

```
failed to write stdin: Error: failed to write data: An established connection
was aborted by the software in your host machine
```

```
failed to write length: An established connection was aborted by the software
in your host machine
```

**Matching regex:**
```
connection was aborted|failed to write (stdin|length|data)
```

**Fix:** If the user sees this BEFORE the "already running" error, they can prevent the
orphaned process by immediately closing and reopening the session tab. If they've already
hit the "already running" error, proceed with Tier 2.

---

## Category 4: Daemon Disconnected

**Pattern:** The kill command fails because the daemon managing the VM is disconnected.

### Exact Error Strings

```
kill failed with error: Error: sdk-daemon not connected
```

```
Process UUID not found
```

```
Failed to run onQuitCleanup(cowork-vm-shutdown): Error: Request timed out
```

**Matching regex:**
```
sdk-daemon not connected|onQuitCleanup.*timed out
```

**Fix:** Skip directly to Tier 3 (process-level kill). The graceful path won't work because
the daemon is unreachable. OS-level process termination is required.

---

## Category 5: Generic Load Failure

**Pattern:** The session simply won't load, with a vague error.

### Exact Error Strings

```
This task didn't load properly
```

**Fix:** Start at Tier 1 (diagnostics) to determine the actual underlying cause, then
route to the appropriate fix tier.

---

## OS-Specific Notes

### Windows
- Hyper-V VM is used for sandboxing — orphaned VMs may need Stop-VM in elevated PowerShell
- Process names appear as claude.exe in Task Manager
- Some users report needing a full reboot to clear kernel-level locks
- MSIX installations may have different paths: check both %APPDATA% and %LOCALAPPDATA%

### macOS
- Lightweight VM (Apple Virtualization framework) is used
- Process names appear as claude or Claude Desktop in Activity Monitor
- State stored in ~/Library/Application Support/Claude/
- Cache in ~/Library/Caches/Claude/
- VM bundles in ~/Library/Application Support/Claude/vm_bundles/

### Linux
- Similar to macOS but paths follow XDG conventions
- State typically in ~/.config/claude/ or ~/.local/share/claude/
- Cache in ~/.cache/claude/
