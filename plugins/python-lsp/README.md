# python-lsp

Real-time Python code intelligence for Claude via Pyright language server.

## What it does

Gives Claude static type analysis, import resolution, go-to-definition, find-references, and hover type info for `.py` and `.pyi` files — no test runner required.

## Setup

1. **Install Pyright**:
   ```bash
   # npm (recommended)
   npm install -g pyright

   # Or via pip
   pip install pyright
   ```

2. **Verify** it works:
   ```bash
   pyright-langserver --version
   ```

3. **Install the plugin**:
   ```
   claude plugin install python-lsp@msapps-plugins
   ```

## Requirements

- Node.js 18+ (for npm install) OR Python 3.8+ (for pip install)
- `pyright-langserver` on `PATH`

## Configuration (optional)

Create a `pyrightconfig.json` in your repo root to control type checking strictness:

```json
{
  "typeCheckingMode": "basic",
  "pythonVersion": "3.11",
  "venvPath": ".",
  "venv": ".venv",
  "reportMissingImports": true,
  "reportMissingTypeStubs": false
}
```

Modes: `"off"` → `"basic"` → `"standard"` → `"strict"`. The plugin defaults to `"basic"` to avoid noise on partially-typed codebases.

## SOSA Compliance

| Pillar       | Level |
|-------------|-------|
| Supervised  | L1 — read-only, no side effects |
| Orchestrated | L1 — LSP protocol, no manual routing |
| Secured     | L1 — no credentials, no network, no writes |
| Agents      | L1 — pure static analysis |

**Level 1** — safe to run autonomously on any codebase.

## Supported files

| Extension | Language |
|-----------|---------|
| `.py`     | Python source |
| `.pyi`    | Python type stub |
| `.pyw`    | Python (Windows, no console) |

## Common issues

- **`reportMissingImports` fires on every import** — your `venv` isn't activated or `pyrightconfig.json` doesn't have `venvPath`/`venv` set. Point Pyright at the right interpreter.
- **Slow first analysis on large monorepos** — Pyright indexes the whole workspace on first open; subsequent runs use the incremental cache under `.pyright/`.
- **Type stubs missing for third-party library** — install `types-<package>` from PyPI or add `reportMissingTypeStubs: false` to silence it.
- **`.pyi` stubs not picked up** — ensure the stub directory is in `stubPath` in `pyrightconfig.json`.

## Part of the MSApps LSP plugin series

Sibling plugins: `kotlin-lsp`, `swift-lsp`, `typescript-lsp`, `csharp-lsp`, `java-lsp`

All share the same MCP contract so the AI Code Reviewer (LangGraph) can orchestrate them uniformly across multi-language repos.
