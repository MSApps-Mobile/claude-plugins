# typescript-lsp

Real-time TypeScript and JavaScript code intelligence for Claude via typescript-language-server (tsserver wrapper).

## What it does

Gives Claude TypeScript-accurate diagnostics, go-to-definition, find-references, and hover type info for `.ts`, `.tsx`, `.js`, and `.jsx` files — covers React, Node.js, Deno, and plain browser JS.

## Setup

1. **Install typescript-language-server**:
   ```bash
   npm install -g typescript typescript-language-server
   ```

2. **Verify** it works:
   ```bash
   typescript-language-server --version
   ```

3. **Install the plugin**:
   ```
   claude plugin install typescript-lsp@msapps-plugins
   ```

## Requirements

- Node.js 18+
- `typescript` and `typescript-language-server` on `PATH`
- A `tsconfig.json` (or `jsconfig.json` for JS-only projects) at the repo root

## Configuration (optional)

The server respects your existing `tsconfig.json`. For JS projects without type checking, a minimal `jsconfig.json` is enough:

```json
{
  "compilerOptions": {
    "checkJs": false,
    "target": "ES2022",
    "module": "ESNext",
    "moduleResolution": "bundler"
  },
  "include": ["src/**/*"]
}
```

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
| `.ts`     | TypeScript |
| `.tsx`    | TypeScript + JSX (React) |
| `.js`     | JavaScript |
| `.jsx`    | JavaScript + JSX |
| `.mts`    | TypeScript ESM |
| `.cts`    | TypeScript CommonJS |
| `.mjs`    | JavaScript ESM |
| `.cjs`    | JavaScript CommonJS |

## Common issues

- **`Cannot find module 'X'`** — run `npm install` so `node_modules` is populated; tsserver needs the actual packages to resolve types.
- **Slow first open** — tsserver loads all `include`d files on startup; narrow your `tsconfig.json` `include` if the project is large.
- **JSX not recognised** — ensure `tsconfig.json` has `"jsx": "react-jsx"` (or `"react"`) and the file uses a `.tsx`/`.jsx` extension.
- **`@types/node` not found** — run `npm install --save-dev @types/node`.

## Part of the MSApps LSP plugin series

Sibling plugins: `kotlin-lsp`, `swift-lsp`, `python-lsp`, `csharp-lsp`, `java-lsp`

All share the same MCP contract so the AI Code Reviewer (LangGraph) can orchestrate them uniformly across multi-language repos.
