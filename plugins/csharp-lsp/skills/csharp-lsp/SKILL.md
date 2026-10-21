---
name: csharp-lsp
description: Real-time C# code intelligence via OmniSharp (OmniSharp-Roslyn) in LSP mode. Use whenever Claude needs semantic analysis of `.cs` / `.csx` files — Roslyn diagnostics (compile errors, nullable warnings, unused usings, analyzer rules), go-to-definition (follows `using` aliases, partial classes, metadata), find-references across the whole solution graph, hover type info, and symbol lookup. Trigger on "C# LSP", "OmniSharp", "omnisharp-roslyn", "find references for this method", "where is X defined", "show me callers", "type-check this solution", "what are the errors in", ".NET diagnostics", "csx", "dotnet script", or any C#/.NET refactor/review task that benefits from semantic (not string-match) navigation.
---

# C# LSP — OmniSharp Integration

## Overview

The C# LSP plugin delivers real-time code intelligence for C# and .NET projects by connecting Claude to `omnisharp` — the Roslyn-based language server that ships as a standalone .NET tool. It provides Roslyn-grade diagnostics, navigation, and symbol information for `.cs` and `.csx` files without modifying code or producing side effects.

## Key Features

- **Diagnostics**: Compile errors, nullable-reference warnings, unused `using` directives, analyzer rules (Roslyn, StyleCop, .NET built-in)
- **Navigation**: Go-to-definition (follows `using` aliases, partial classes, `[Generator]` source-generated members, metadata references) and find-references across the whole solution graph
- **Type Information**: Hover to see inferred types, generic instantiations, async return types, and XML doc comments
- **Solution-Aware**: Indexes from `.sln` / `.slnx` / bare `.csproj` roots — no Visual Studio required
- **Read-Only Analysis**: no file modifications, no credentials. OmniSharp still evaluates the opened project's MSBuild files, so use it on trusted projects only (the plugin asks OmniSharp to keep analyzers and package auto-restore off — best effort; a project's `omnisharp.json` can override it)

## Workflow Process

The plugin operates in three phases (same contract as `swift-lsp` / `kotlin-lsp` / `python-lsp` / `typescript-lsp`):

1. **Plan**: LSP analyzes the solution and reports current diagnostics before any edits
2. **Act**: Claude edits `.cs` / `.csx` files; the server returns updated diagnostics as the buffer changes
3. **Verify**: Claude re-reads diagnostics post-edit to confirm no regressions were introduced

## Setup Requirements

**Prerequisites:**
- .NET SDK ≥ 6.0 on `PATH` (for OmniSharp's runtime)
- `omnisharp` (OmniSharp-Roslyn) on `PATH`

**Install:**

```bash
# macOS (Homebrew)
brew install omnisharp

# Linux / Windows / macOS — GitHub releases
# Download the latest omnisharp-osx-arm64-net6.0.tar.gz (or your platform)
# from https://github.com/OmniSharp/omnisharp-roslyn/releases
# Unpack and symlink/move `omnisharp` onto PATH.

# Alternative: .NET global tool
dotnet tool install -g Microsoft.OmniSharp.DotNet.GlobalTool
```

Verify installation with:

```bash
omnisharp --help | grep -i lsp
# Should list: -lsp, --languageserver   Use Language Server Protocol.
```

## Supported Files

| Extension  | Language ID | Notes                                                        |
|------------|-------------|--------------------------------------------------------------|
| `.cs`      | csharp      | Standard C# source                                           |
| `.csx`     | csharp      | C# script files (`dotnet script` / Roslyn scripting)         |

## Project Configuration (optional but recommended)

OmniSharp picks up configuration from `omnisharp.json` in the solution root and honors `global.json` (SDK pin), `.editorconfig`, and per-project `.ruleset` files automatically.

Minimal `omnisharp.json`:

```json
{
  "RoslynExtensionsOptions": {
    "EnableAnalyzersSupport": true,
    "EnableImportCompletion": true,
    "EnableDecompilationSupport": false
  },
  "FormattingOptions": {
    "EnableEditorConfigSupport": true
  },
  "MsBuild": {
    "LoadProjectsOnDemand": false,
    "EnablePackageAutoRestore": true
  }
}
```

For **monorepos** with multiple independent solutions, launch one LSP instance per `.sln`. Single-root setups auto-detect the solution by walking up from the edited file.

## Common Issues

- **"The .NET SDK version X is not installed"** — your repo's `global.json` pins an SDK OmniSharp can't find. Either `dotnet --list-sdks` and install the pinned version, or loosen the pin with `"rollForward": "latestFeature"`.
- **First-response latency on large solutions** — OmniSharp does a full MSBuild design-time build on first open; subsequent requests are fast. Enable `"LoadProjectsOnDemand": true` in `omnisharp.json` for repos with >50 projects.
- **Missing diagnostics for source-generated code** — make sure `"EnableAnalyzersSupport": true` is in your `omnisharp.json`. Source generators run as analyzers; they're off by default in older OmniSharp builds.
- **`#nullable enable` not flagging anything** — the project needs `<Nullable>enable</Nullable>` in the `.csproj`, not just the pragma. OmniSharp respects the project setting first.
- **Razor (`.cshtml`) files** — not served by this plugin; OmniSharp does not provide Razor language services.
- **`.vb` / `.fs` files flagged as errors** — OmniSharp is C#-only. VB.NET and F# need sibling plugins.
- **Solution with 3rd-party NuGet analyzers** — they run automatically if `EnableAnalyzersSupport: true`. They can add real latency; narrow `include` rules in `omnisharp.json` if it's painful.
- **Build server running in parallel** — OmniSharp holds its own in-memory workspace; running `dotnet build` in another terminal won't interfere, but a clobbered `obj/` mid-session may force an OmniSharp restart.

## Cross-Plugin Notes

This plugin is the C# sibling of:
- `swift-lsp` — SourceKit-LSP for iOS/macOS
- `kotlin-lsp` — kotlin-language-server for Android/JVM
- `python-lsp` — pyright-langserver for Python
- `typescript-lsp` — typescript-language-server for TypeScript/JavaScript

All five expose the same LSP operations (diagnostics, go-to-definition, find-references, hover), so a multi-language repo can be navigated the same way in each language.
