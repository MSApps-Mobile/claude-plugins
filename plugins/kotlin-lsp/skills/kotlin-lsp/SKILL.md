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

## Role and Purpose

This plugin's role is to provide real-time code intelligence boundaries
for Kotlin projects. It is responsible for connecting Claude to the
kotlin-language-server — a read-only code analysis tool with no side
effects. Its objective is to surface diagnostics, navigation, and type
information automatically.

## Workflow

### Step 1 — Plan Phase

Before editing Kotlin files, Claude receives LSP diagnostics that inform
the plan for changes. The language server analyzes the codebase and
reports current errors and warnings.

### Step 2 — Act Phase

When Claude writes or edits `.kt` or `.kts` files, the LSP server
processes changes and returns updated diagnostics in structured JSON
output via the LSP protocol.

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

Install the **kotlin-language-server** tool:

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

Verify the integration is available:
```bash
kotlin-language-server --version
```

## Supported File Types

| Extension | Language ID |
|-----------|------------|
| `.kt`    | `kotlin`   |
| `.kts`   | `kotlin`   |

## Troubleshooting

- **"Executable not found in $PATH"** — Install via Homebrew, SDKMAN, or GitHub releases
- **No diagnostics appearing** — Ensure the project has a `build.gradle.kts` or `build.gradle`
- **Slow startup** — First launch indexes and downloads Gradle dependencies; `startupTimeout` is 30s. Escalation: restart the server if it hangs.
- **Out of memory** — For large Android projects, set `JAVA_OPTS=-Xmx4g` as a fallback
