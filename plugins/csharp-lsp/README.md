# csharp-lsp

Real-time C# code intelligence for Claude via OmniSharp (OmniSharp-Roslyn).

## What it does

Gives Claude Roslyn-grade diagnostics, go-to-definition, find-references, and type information for `.cs` and `.csx` files — no Visual Studio required.

## Setup

1. **Install OmniSharp**:
   ```bash
   # macOS (Homebrew)
   brew install omnisharp

   # Or .NET global tool
   dotnet tool install -g Microsoft.OmniSharp.DotNet.GlobalTool
   ```

2. **Verify** it works:
   ```bash
   omnisharp --help | grep -i lsp
   # Should show: -lsp, --languageserver
   ```

3. **Install the plugin**:
   ```
   claude plugin install csharp-lsp@msapps-plugins
   ```

## Requirements

- .NET SDK ≥ 6.0 on `PATH`
- `omnisharp` on `PATH`
- A solution root: `.sln`, `.slnx`, or `.csproj`

## Security — open only projects you trust

OmniSharp **evaluates the MSBuild project files** (`.csproj`, `Directory.Build.props/targets`) of whatever you open, and MSBuild can run tasks and inline code during evaluation. That is inherent to the server and cannot be switched off from this config.

What this plugin asks OmniSharp to turn off (via `initializationOptions`), because it would load or fetch **more** code from an untrusted repo:
- `RoslynExtensionsOptions.EnableAnalyzersSupport: false` — Roslyn analyzers are DLLs shipped in the project's NuGet packages and run inside the server.
- `MsBuild.EnablePackageAutoRestore: false` — no automatic `dotnet restore` against the opened project.

These are **best effort**, not a guarantee: OmniSharp may not apply every option passed this way in LSP mode, and a project's own `omnisharp.json` (or `~/.omnisharp/omnisharp.json`) can override them — including re-enabling analyzers or auto-restore. Do not rely on them as a sandbox. For a repo you trust, you may re-enable both in `.lsp.json` or `omnisharp.json`. Do not enable this plugin while working in a repo you did not write or review.

## SOSA Compliance

| Pillar       | Level |
|-------------|-------|
| Supervised  | L1 — read-only, no side effects |
| Orchestrated | L1 — LSP protocol, no manual routing |
| Secured     | L1 — no credentials, no writes; NOT sandboxed against the opened project (see Security) |
| Agents      | L1 — pure code analysis |

**Level 1** — safe to run autonomously on codebases you trust (see Security above).

## Supported languages

| Extension | Language |
|-----------|---------|
| `.cs`     | C# (standard) |
| `.csx`    | C# script |

## Usage

```
/csharp-lsp:setup [project path]

# Examples:
/csharp-lsp:setup
/csharp-lsp:setup ./src/MyApp
```

## Part of the LSP plugin series

Sibling plugins: `kotlin-lsp`, `swift-lsp`, `python-lsp`, `typescript-lsp`, `java-lsp`
