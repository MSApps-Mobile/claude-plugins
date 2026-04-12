---
name: kotlin-lsp
description: >
  Real-time Kotlin code intelligence via kotlin-language-server. Gives Claude
  instant error detection, go-to-definition, find-references, and type info
  for .kt and .kts files. Trigger on: "kotlin lsp", "enable kotlin diagnostics",
  "kotlin code intelligence", or when working on any Kotlin/Android project
  and Claude needs better code awareness.
---

# Kotlin LSP — kotlin-language-server Integration

This plugin connects Claude to the **kotlin-language-server**, giving you real-time code intelligence for Kotlin projects.

## What You Get

After installing, Claude automatically receives:

- **Instant diagnostics** — errors and warnings appear immediately after each edit, no need to build
- **Go to definition** — jump to where any symbol is defined, even across modules
- **Find references** — locate every usage of a function, type, or variable
- **Hover info** — type signatures and documentation for any symbol

## Prerequisites

Install the **kotlin-language-server**:

### Option 1: Homebrew (macOS)
```bash
brew install kotlin-language-server
```

### Option 2: SDKMAN
```bash
sdk install kls
```

### Option 3: From GitHub Releases
Download the latest release from [fwcd/kotlin-language-server](https://github.com/fwcd/kotlin-language-server/releases), extract, and add the `bin/` directory to your PATH.

Verify it's available:
```bash
kotlin-language-server --version
```

## Supported File Types

| Extension | Language ID |
|-----------|------------|
| `.kt`    | `kotlin`   |
| `.kts`   | `kotlin`   |

## Troubleshooting

- **"Executable not found in $PATH"** — Install via Homebrew, SDKMAN, or GitHub releases, then verify `kotlin-language-server --version` works
- **No diagnostics appearing** — Ensure the project has a `build.gradle.kts` or `build.gradle` so the language server can resolve dependencies
- **Slow startup** — First launch indexes the project and downloads Gradle dependencies; subsequent sessions are faster. The `startupTimeout` is set to 30s to accommodate this.
- **Out of memory** — For large Android projects, you may need to increase JVM heap: set `JAVA_OPTS=-Xmx4g` in your environment
