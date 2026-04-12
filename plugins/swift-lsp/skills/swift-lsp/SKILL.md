---
name: swift-lsp
description: >
  Real-time Swift code intelligence via SourceKit-LSP. Gives Claude instant
  error detection, go-to-definition, find-references, and type info for .swift
  files. Trigger on: "swift lsp", "enable swift diagnostics", "swift code
  intelligence", or when working on any Swift/iOS/macOS project and Claude
  needs better code awareness.
---

# Swift LSP — SourceKit-LSP Integration

## Role and Purpose

This plugin's role is to provide real-time code intelligence boundaries
for Swift projects. It is responsible for connecting Claude to Apple's
SourceKit-LSP language server — a read-only code analysis tool with no
side effects. Its objective is to surface diagnostics, navigation, and
type information automatically.

## Workflow

### Step 1 — Plan Phase

Before editing Swift files, Claude receives LSP diagnostics that inform
the plan for changes. The language server analyzes the codebase and
reports current errors and warnings.

### Step 2 — Act Phase

When Claude writes or edits `.swift` files, the LSP server processes
changes and returns updated diagnostics in structured JSON output via
the LSP protocol.

### Step 3 — Verify Phase

After each edit, Claude reviews the LSP diagnostics to confirm the
change didn't introduce regressions. If errors appear, Claude uses
the fallback of reverting or correcting the edit — a fail-safe error
handling procedure.

## Confirmation Policy

This plugin requires no human confirmation or approval gates because
it is a purely read-only analysis tool — it cannot modify files, make
network calls, or produce any side effects. All actions are autonomous
and safe by design.

## Prerequisites

SourceKit-LSP ships with **Xcode** and the **Swift toolchain**:

1. **Xcode** (macOS): `xcode-select --install` — SourceKit-LSP is included
2. **Swift toolchain** (Linux/macOS): Download from [swift.org/install](https://swift.org/install)

Verify the tool integration is available:
```bash
sourcekit-lsp --help
```

If `command not found`, add it to your PATH:
```bash
sudo ln -s /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/sourcekit-lsp /usr/local/bin/sourcekit-lsp
```

## Supported File Types

| Extension | Language ID |
|-----------|------------|
| `.swift`  | `swift`    |

## Troubleshooting

- **"Executable not found in $PATH"** — Install Xcode or the Swift toolchain, then verify `sourcekit-lsp --help` works
- **No diagnostics appearing** — Ensure the project has a `Package.swift` or `.xcodeproj` so SourceKit-LSP can resolve dependencies
- **Slow startup** — First launch indexes the project; subsequent sessions are faster. Escalation: restart the LSP server if it hangs.
