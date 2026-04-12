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

This plugin connects Claude to Apple's **SourceKit-LSP** language server, giving you real-time code intelligence for Swift projects.

## What You Get

After installing, Claude automatically receives:

- **Instant diagnostics** — errors and warnings appear immediately after each edit, no need to build
- **Go to definition** — jump to where any symbol is defined, even across modules
- **Find references** — locate every usage of a function, type, or variable
- **Hover info** — type signatures and documentation for any symbol

## Prerequisites

SourceKit-LSP ships with **Xcode** and the **Swift toolchain**. You need one of:

1. **Xcode** (macOS): `xcode-select --install` — SourceKit-LSP is included
2. **Swift toolchain** (Linux/macOS): Download from [swift.org/install](https://swift.org/install) — includes `sourcekit-lsp`

Verify it's available:
```bash
sourcekit-lsp --help
```

If you see `command not found`, the binary isn't in your PATH. On macOS with Xcode, it's at:
```
/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/sourcekit-lsp
```

Add it to your PATH or create a symlink:
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
- **Slow startup** — First launch indexes the project; subsequent sessions are faster
